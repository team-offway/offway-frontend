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
  Future<AuthTokens> loginWithSocial(
    SocialProvider provider,
    String socialAccessToken,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/callback/${provider.path}',
      data: {'accessToken': socialAccessToken},
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
