import 'package:dio/dio.dart';
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
  /// 실패하면 저장된 토큰을 지우고 null을 돌려준다 — 못 쓰는 토큰을 들고
  /// 있으면 요청마다 401을 맞으며 재발급을 되풀이한다.
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
    } on DioException {
      await _storage.clear();
      return null;
    }
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
    try {
      await _dio.post<dynamic>('/api/v1/auth/logout');
    } on DioException {
      // 무시 — 아래에서 로컬을 비우는 것이 사용자가 기대하는 결과다
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
