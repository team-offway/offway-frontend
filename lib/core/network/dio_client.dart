import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

/// 이 요청에는 **우리 JWT를 싣지 말라**는 표시 (`Options.extra`).
///
/// 재발급 요청에 만료된 액세스 토큰이 실리면 서버가 그걸 먼저 보고 401을 내
/// 재발급 자체가 막힌다.
///
/// Authorization 헤더가 아예 비는 것은 아니다 — 서버가 임시 Basic 게이트
/// 뒤에 있어(#122) JWT를 뺀 자리에 Basic 자격증명이 들어간다.
const kSkipAuthKey = 'skipAuth';

bool shouldSkipAuth(RequestOptions options) =>
    options.extra[kSkipAuthKey] == true;

/// 이 요청은 **JWT는 싣되, 401을 맞아도 재발급하지 말라**는 표시 (`Options.extra`).
///
/// 로그아웃이 쓴다. 서버가 refresh 토큰을 폐기하려면 Bearer로 누구인지
/// 알아야 하는데, [kSkipAuthKey]는 헤더 자체를 빼 버려 요청이 컨트롤러에
/// 닿지 못했다(#142 — 로그아웃해도 refresh 토큰이 60일 살아 있었다).
/// 반면 만료된 토큰으로 로그아웃하면 401인데, 그걸 재발급 실패로 읽어
/// '세션이 만료됐어요'를 띄우면 스스로 나간 사람에게 틀린 안내다 —
/// 그 한 가지만 막는다.
const kSkipRefreshKey = 'skipRefresh';

bool shouldSkipRefresh(RequestOptions options) =>
    options.extra[kSkipRefreshKey] == true;

/// 만료된 액세스 토큰을 되살리는 방법.
///
/// 되살렸으면 true. 이 파일이 인증 기능(features/auth)을 직접 참조하면
/// `core → features` 방향 의존과 순환 import가 생기므로, 실제 구현은
/// 앱 시작 시 [tokenRefresherProvider]를 덮어써 넣는다.
typedef TokenRefresher = Future<bool> Function();

/// 기본값은 "되살릴 수 없다" — 인증 기능이 이 값을 갈아끼운다
final tokenRefresherProvider = Provider<TokenRefresher>(
  (ref) =>
      () async => false,
);

/// 세션이 끊겼다는 신호 — 되살리기까지 실패한 401을 만나면 true가 된다.
///
/// 인터셉터가 화면을 직접 옮기면 네트워크 계층이 라우터를 알게 된다. 상태만
/// 올리고, 앱 루트가 이 값을 보고 로그인 화면으로 보낸다.
class SessionExpiredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markExpired() => state = true;

  /// 로그인 화면으로 보낸 뒤 되돌린다 — 남아 있으면 다시 로그인해도 튕긴다
  void reset() => state = false;
}

final sessionExpiredProvider = NotifierProvider<SessionExpiredNotifier, bool>(
  SessionExpiredNotifier.new,
);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // 인터셉터가 재시도할 때 이 dio를 쓴다. provider를 다시 읽으면 자기 자신을
  // 의존하게 되어 Riverpod이 막는다
  dio.interceptors.add(AuthInterceptor(ref, dio));

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  return dio;
});

/// 저장된 액세스 토큰을 Authorization 헤더에 붙이고, 만료되면 한 번 되살린다.
///
/// JWT가 없으면 임시 Basic 계정(#122 게이트)으로 대신 통과한다 — 읽기 요청은
/// 그것만으로 되지만 쓰기는 403이다. Basic 분기는 게이트가 걷힐 때 함께 지운다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref, this._dio);

  final Ref _ref;

  /// 재시도에 쓸 클라이언트 — 이 인터셉터가 붙어 있는 그 인스턴스다
  final Dio _dio;

  /// 재발급이 진행 중이면 그 결과를 함께 기다린다.
  ///
  /// 토큰이 만료된 순간 여러 요청이 동시에 401을 맞는다. 각자 재발급하면
  /// 리프레시 토큰이 여러 번 회전하고, 뒤늦게 옛 값으로 부른 쪽이 서버에
  /// **재사용 감지**로 걸려 계정 토큰이 전부 끊긴다.
  Future<bool>? _refreshing;

  /// 매 요청마다 다시 인코딩하지 않도록 한 번만 만든다
  static final String? _basicCredential =
      AppConfig.basicAuthUser.isEmpty || AppConfig.basicAuthPass.isEmpty
      ? null
      : 'Basic ${base64Encode(utf8.encode('${AppConfig.basicAuthUser}:${AppConfig.basicAuthPass}'))}';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final storage = _ref.read(secureStorageProvider);

    // 재발급 요청에 만료된 토큰을 실으면 서버가 그걸 먼저 보고 401을 낸다
    final token = shouldSkipAuth(options) ? null : await storage.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    } else if (_basicCredential != null) {
      options.headers['Authorization'] = _basicCredential;
    }

    // 소유자는 JWT가 정한다(core #320). 예전에는 X-Guest-Id 헤더를 함께
    // 실어 서버가 그 값으로 연차·코스를 묶었는데, 인증 안 된 값이라
    // 남의 키를 실어 보내면 남의 데이터가 지워지는 구멍이었다
    handler.next(options);
  }

  /// 만료된 액세스 토큰(401 · `USER-004`)을 한 번 되살려 재시도한다.
  ///
  /// Bearer 없이 맞는 403은 여기서 손대지 않는다 — 되살릴 토큰이 없다.
  /// 재발급 자체가 실패하면 원래 오류를 그대로 올려 화면이 로그인으로 보낸다.
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    // 재발급 요청이 401이면 리프레시도 죽은 것 — 다시 재발급하면 무한 루프다.
    // 로그아웃(kSkipRefreshKey)도 여기서 빠진다 — 이미 못 쓰는 세션이다
    if (err.response?.statusCode != 401 ||
        shouldSkipAuth(options) ||
        shouldSkipRefresh(options) ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    // 동시에 401을 맞은 요청들이 하나의 재발급을 함께 기다린다
    final refreshed = await (_refreshing ??= _ref
        .read(tokenRefresherProvider)()
        .whenComplete(() => _refreshing = null));
    if (!refreshed) {
      // 재발급이 실패했다고 늘 만료는 아니다 — 지하철에서 끊기거나 서버가
      // 잠깐 죽어도 여기 온다. 그때까지 '로그인이 만료됐어요'를 띄우면
      // 멀쩡한 세션을 두고 로그인 화면으로 내보내게 된다.
      //
      // 서버가 거절했으면 재발급 쪽이 토큰을 지운다(`AuthRepository.reissue`).
      // **남아 있다면 토큰 문제가 아니다** — 오류만 올리고 세션은 지킨다
      final storage = _ref.read(secureStorageProvider);
      if (await storage.refreshToken == null) {
        // 되살릴 수 없는 401 — 다시 로그인해야 한다. 이 신호를 올리지 않으면
        // 화면이 오류만 띄운 채 멈춰, 사용자가 나갈 길을 찾지 못한다
        _ref.read(sessionExpiredProvider.notifier).markExpired();
      }
      return handler.next(err);
    }

    try {
      // 새 토큰으로 원래 요청을 한 번만 다시 보낸다
      final retried = await _dio.fetch<dynamic>(
        options..extra[_retriedKey] = true,
      );
      return handler.resolve(retried);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// 재시도한 요청임을 표시 — 두 번 이상 되풀이하지 않게 막는다
  static const _retriedKey = 'authRetried';
}
