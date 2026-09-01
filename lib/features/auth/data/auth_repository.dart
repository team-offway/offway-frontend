import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';

/// 소셜 로그인 제공자
enum SocialProvider {
  kakao('카카오'),
  apple('Apple'),
  google('구글');

  const SocialProvider(this.label);

  /// 사용자 대면 문구용 이름
  final String label;

  String get path => name;
}

/// 최초 로그인 시에만 제공되는 소셜 프로필.
/// Apple은 이름·이메일을 첫 승인 때 한 번만 내려주므로 그 시점에 서버로 넘겨야 한다.
class SocialProfile {
  const SocialProfile({this.email, this.fullName, this.providerUserId});

  final String? email;
  final String? fullName;
  final String? providerUserId;

  bool get isEmpty =>
      email == null && fullName == null && providerUserId == null;

  Map<String, dynamic> toJson() => {
    if (email != null) 'email': email,
    if (fullName != null) 'name': fullName,
    if (providerUserId != null) 'providerUserId': providerUserId,
  };
}

/// 서버가 발급한 우리 서비스 토큰
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.isNewUser = false,
  });

  final String accessToken;
  final String? refreshToken;

  /// 이번 로그인에서 계정이 만들어졌는지 — 온보딩(잔여 연차 입력)과 홈을 가른다.
  ///
  /// 서버가 사용자를 만든 그 자리에서 판정해 준다. 재발급 응답에서는 늘 false다
  /// (재발급은 가입일 수 없다).
  final bool isNewUser;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      isNewUser: json['isNewUser'] as bool? ?? false,
    );
  }
}

/// 소셜 로그인 → 서버 토큰 교환.
///
/// 백엔드 계약: 앱이 소셜 액세스 토큰을 보내면 서버가 검증 후 우리 JWT를 발급한다.
/// 응답은 공통 래퍼 `{status, data, detail, code}` 형태이므로 `data`를 꺼내 쓴다.
class AuthRepository {
  const AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  /// [socialAccessToken]: 카카오 액세스 토큰 / Apple identityToken 등
  ///
  /// [profile]: Apple처럼 **최초 로그인 1회만** 제공되는 이름·이메일.
  /// 이때 서버가 저장하지 않으면 이후에는 복구할 수 없으므로 함께 전달한다.
  /// [authorizationCode]는 **Apple만** 채워 보낸다 — 서버가 이 값으로 Apple과
  /// 토큰을 교환해 refresh 토큰을 갖고 있어야 탈퇴할 때 Apple 연결을 해제할
  /// 수 있다(심사 항목 5.1.1(v)).
  ///
  /// 서버에서 선택 필드라 배포 순서를 맞추지 않아도 된다 — 앱이 먼저 나가도
  /// 서버가 무시하고, 서버가 먼저 나가도 옛 앱은 그대로 동작한다.
  Future<AuthTokens> loginWithSocial(
    SocialProvider provider,
    String socialAccessToken, {
    SocialProfile? profile,
    String? authorizationCode,
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/callback/${provider.path}',
        data: {
          'accessToken': socialAccessToken,
          'authorizationCode': ?authorizationCode,
          if (profile != null) ...profile.toJson(),
        },
        // 아직 우리 토큰이 없다 — 만료된 옛 토큰이 실리면 서버가 그걸 먼저 본다
        options: Options(
          headers: {'X-Client-Type': 'app'},
          extra: {kSkipAuthKey: true},
        ),
      );
    } on DioException catch (e) {
      // 서버가 준 문구를 살려 화면이 원인을 보여줄 수 있게 한다
      throw ApiEnvelope.toApiException(e);
    }
    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('로그인 응답에 data가 없습니다: ${response.data}');
    }
    final tokens = AuthTokens.fromJson(data);
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return tokens;
  }

  /// 액세스 토큰 재발급 (`POST /auth/reissue`).
  ///
  /// 리프레시 토큰은 쓰면 회전한다(서버가 새 값을 준다) — 받은 쌍을 반드시
  /// 저장해야 다음 재발급이 된다. 옛 값을 다시 쓰면 서버가 재사용으로 보고
  /// 그 계정의 토큰을 전부 끊는다.
  ///
  /// **서버가 거절했을 때만** 저장된 토큰을 지운다. 못 쓰는 토큰을 들고
  /// 있으면 요청마다 401을 맞으며 재발급을 되풀이하기 때문이다.
  ///
  /// 반대로 **네트워크가 끊기거나 서버가 죽었을 때는 지우지 않는다.** 지하철에서
  /// 잠깐 끊긴 것뿐인데 60일짜리 리프레시 토큰까지 버리면, 멀쩡한 세션을 두고
  /// 로그인 화면으로 튕긴다 — 원인을 가리지 않고 지우던 때의 문제다.
  Future<AuthTokens?> reissue() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null) return null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/reissue',
        data: {'refreshToken': refresh},
        // 이 요청에까지 만료된 토큰을 실으면 서버가 그걸 먼저 보고 401을 낸다
        options: Options(extra: {kSkipAuthKey: true}),
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final tokens = AuthTokens.fromJson(data);
      await _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return tokens;
    } on DioException catch (e) {
      // 서버가 "이 토큰은 못 쓴다"고 답한 경우만 버린다 — 만료·폐기·재사용
      // 감지가 여기 온다. 그 밖(끊김·타임아웃·5xx)은 토큰 문제가 아니므로
      // 남겨 두고 다음 요청에서 다시 시도한다
      if (_isRejectedByServer(e)) await _storage.clear();
      return null;
    }
  }

  /// 서버가 이 리프레시 토큰을 거절했는가.
  ///
  /// 401·403만 그렇다. 5xx는 서버 사정이고, 응답이 아예 없으면(끊김·타임아웃)
  /// 토큰이 성한지조차 물어보지 못한 것이다.
  static bool _isRejectedByServer(DioException e) {
    final status = e.response?.statusCode;
    return status == 401 || status == 403;
  }

  /// 로그아웃 (`POST /auth/logout`).
  ///
  /// 서버는 리프레시 토큰을 폐기한다. 액세스 토큰은 무상태 JWT라 만료(1시간)까지
  /// 유효하지만, 우리가 지워 더 쓰지 않는다.
  ///
  /// **서버 호출 실패는 삼키고 Keychain 삭제 실패는 던진다.** 서버가 답을 못
  /// 줘도 로컬 토큰을 비우면 이 기기에서는 로그아웃된 것이다. 반대로 Keychain에
  /// 토큰이 남았는데 로그인 화면으로 보내면 로그아웃된 줄 알고 넘어간다.
  Future<void> logout() async {
    // 이 기기의 refresh를 함께 보낸다(core #389) — 서버가 **그 세션만** 끊게.
    // 지금 서버는 Bearer만 보고 그 사용자의 refresh를 전부 폐기해서, 시뮬레이터나
    // 백오피스에서 로그아웃하면 최대 1시간 뒤 폰까지 풀렸다. 서버가 반영되기
    // 전에는 이 값을 무시할 뿐이라 먼저 보내도 해가 없다
    final refresh = await _storage.refreshToken;
    try {
      await _dio.post<dynamic>(
        '/api/v1/auth/logout',
        data: {'refreshToken': ?refresh},
        // Bearer는 실어야 한다 — 서버가 그 사용자의 refresh 토큰을 폐기하려면
        // 누구인지 알아야 한다. 예전에 kSkipAuthKey로 헤더째 뺐더니 요청이
        // 컨트롤러에 닿지 못해 로그아웃 뒤에도 refresh가 60일 살아 있었다(#142).
        // 다만 만료된 토큰이면 401인데, 그걸 재발급 실패로 읽어 '세션이
        // 만료됐어요'를 띄우면 스스로 나간 사람에게 틀린 안내다 — 재발급만 끈다
        options: Options(extra: {kSkipRefreshKey: true}),
      );
    } on DioException catch (e) {
      // 로컬은 아래에서 어차피 비운다 — 그게 사용자가 기대하는 결과다.
      // 다만 서버 폐기가 실패한 사실은 남긴다. 성공과 같은 모양으로 삼키면
      // refresh 토큰이 살아 있어도 아무 데도 드러나지 않는다
      debugPrint(
        '로그아웃: 서버 refresh 폐기 실패 '
        '(${e.response?.statusCode ?? e.type}) — 로컬만 비운다',
      );
    }
    await _storage.clear();
  }

  /// 로그인한 사용자 정보 (`GET /users/me`).
  ///
  /// 닉네임을 로그인 응답에만 기대지 않기 위해 있다 — 기기를 바꾸거나 앱을
  /// 다시 깔면 세션은 재발급으로 살아나는데 표시할 이름이 없다.
  ///
  /// `email`·`provider`는 null일 수 있다(카카오 미동의, 개발 로그인).
  /// `profileImageUrl`도 null일 수 있다(core #316) — Apple은 사진을 주지
  /// 않고, 카카오도 동의를 껐으면 비어 온다.
  Future<Map<String, dynamic>> me() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/users/me');
      return ApiEnvelope.unwrap(response) as Map<String, dynamic>;
    } on DioException catch (e) {
      // 탈퇴한 계정이면 USER-006(401)이 온다 — access 토큰이 만료 전이라
      // 서명은 통과하지만 계정이 없는 창이다
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 회원 탈퇴 (`DELETE /users/me`).
  ///
  /// 서버가 계정·저장 코스·연차 내역·여행 후기를 지우고, Apple 로그인이면
  /// 저장해 둔 refresh 토큰으로 Apple 연결까지 끊는다.
  ///
  /// **로그아웃과 달리 실패를 삼키지 않는다.** 서버가 못 지웠는데 앱만
  /// 로그인 화면으로 보내면, 사용자는 탈퇴된 줄 알지만 데이터는 그대로다.
  ///
  /// 성공하면 토큰을 비운다. 데이터는 서버가 사용자 단위로 지운다(core #320).
  Future<void> withdraw() async {
    try {
      await _dio.delete<dynamic>('/api/v1/users/me');
    } on DioException catch (e) {
      // 서버가 준 문구를 살려 화면이 원인을 보여줄 수 있게 한다.
      // 이미 탈퇴한 계정이면 USER-006(401)이 온다 — 토큰이 만료 전이라
      // 서명 검증은 통과하지만 계정이 없는 창이다
      throw ApiEnvelope.toApiException(e);
    }
    await _storage.clear();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});

/// 네트워크 계층이 401을 만났을 때 부를 재발급 훅.
///
/// `core`가 이 기능을 직접 참조하면 순환 import가 되므로, 앱 시작 시
/// [tokenRefresherProvider]를 이 값으로 덮어써 연결한다(`main.dart`).
final authTokenRefresherProvider = Provider<TokenRefresher>((ref) {
  return () async => await ref.read(authRepositoryProvider).reissue() != null;
});
