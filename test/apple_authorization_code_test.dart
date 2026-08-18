import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/storage/secure_storage.dart';
import 'package:offway/features/auth/data/auth_repository.dart';

/// Apple 로그인의 `authorizationCode`가 **실제로 서버 요청에 실리는지** 고정한다.
///
/// 이 값이 없으면 서버가 Apple과 토큰을 교환하지 못해, 탈퇴할 때 Apple 연결을
/// 해제할 수 없다 — 앱 심사 항목(5.1.1(v))이다. 1회용이고 5분이면 만료되므로
/// 로그인하는 그 순간 함께 보내야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> sentBodies;
  late AuthRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    sentBodies = [];

    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = _RecordingAdapter(sentBodies);
    repository = AuthRepository(
      dio,
      TokenStorage(const FlutterSecureStorage()),
    );
  });

  test('Apple은 authorizationCode를 함께 보낸다', () async {
    await repository.loginWithSocial(
      SocialProvider.apple,
      'apple-identity-token',
      authorizationCode: 'one-time-code',
    );

    expect(sentBodies.single['accessToken'], 'apple-identity-token');
    expect(sentBodies.single['authorizationCode'], 'one-time-code');
  });

  test('카카오·구글은 그 필드를 아예 넣지 않는다', () async {
    // 서버는 apple에서만 이 값을 기대한다 — null을 실어 보내면
    // 있어야 할 값이 비어 온 것처럼 보인다
    await repository.loginWithSocial(SocialProvider.kakao, 'kakao-token');
    await repository.loginWithSocial(SocialProvider.google, 'google-token');

    for (final body in sentBodies) {
      expect(body.containsKey('authorizationCode'), isFalse);
    }
  });

  test('프로필과 함께 보내도 둘 다 실린다', () async {
    // Apple은 이름·이메일도 최초 1회만 주므로 같은 요청에 함께 나간다
    await repository.loginWithSocial(
      SocialProvider.apple,
      'apple-identity-token',
      authorizationCode: 'one-time-code',
      profile: const SocialProfile(email: 'a@b.com', fullName: '조영찬'),
    );

    final body = sentBodies.single;
    expect(body['authorizationCode'], 'one-time-code');
    expect(body['email'], 'a@b.com');
    // toJson이 fullName을 'name'으로 내보낸다 — 서버 계약과 같다
    expect(body['name'], '조영찬');
  });
}

/// 요청 본문만 받아 적고 성공 응답을 돌려주는 어댑터
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.bodies);

  final List<Map<String, dynamic>> bodies;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bodies.add(Map<String, dynamic>.from(options.data as Map));
    return ResponseBody.fromString(
      '{"data":{"accessToken":"jwt","refreshToken":"refresh"}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
