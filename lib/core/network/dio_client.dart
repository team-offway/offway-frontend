import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(AuthInterceptor(ref));

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  return dio;
});

/// 저장된 액세스 토큰을 Authorization 헤더에 붙인다.
/// 401 응답 시 토큰 갱신 로직은 백엔드 인증 스펙 확정 후 onError에 추가한다.
///
/// JWT가 없으면 임시 Basic 계정(#122 게이트)으로 대신 통과한다.
/// 소셜 로그인(#93)이 서버에 붙으면 Basic 분기는 서버와 함께 걷어낸다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref);

  final Ref _ref;

  /// 매 요청마다 다시 인코딩하지 않도록 한 번만 만든다
  static final String? _basicCredential =
      AppConfig.basicAuthUser.isEmpty || AppConfig.basicAuthPass.isEmpty
      ? null
      : 'Basic ${base64Encode(utf8.encode('${AppConfig.basicAuthUser}:${AppConfig.basicAuthPass}'))}';

  /// Keychain 왕복을 요청마다 하지 않도록 한 번 읽으면 잡아둔다
  String? _cachedGuestId;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final storage = _ref.read(secureStorageProvider);

    final token = await storage.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    } else if (_basicCredential != null) {
      options.headers['Authorization'] = _basicCredential;
    }

    // 비회원 식별자(#34) — 서버가 연차·저장 코스를 이 값에 묶는다.
    // 소셜 로그인(#93)이 붙기 전까지는 이 헤더가 곧 "누구인지"다.
    options.headers['X-Guest-Id'] = _cachedGuestId ??=
        await _loadOrCreateGuestId(storage);

    handler.next(options);
  }

  Future<String> _loadOrCreateGuestId(TokenStorage storage) async {
    final existing = await storage.guestId;
    if (existing != null) return existing;
    final created = _randomId();
    await storage.saveGuestId(created);
    return created;
  }

  /// 128비트 난수 hex — 충돌 걱정 없는 익명 식별자면 충분해 uuid 패키지를 들이지 않는다
  static String _randomId() {
    final rng = Random.secure();
    return List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
