import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  const AuthTokens({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
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
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/callback/${provider.path}',
      data: {
        'accessToken': socialAccessToken,
        'authorizationCode': ?authorizationCode,
        if (profile != null) ...profile.toJson(),
      },
      options: Options(headers: {'X-Client-Type': 'app'}),
    );
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

  Future<void> logout() => _storage.clear();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});
