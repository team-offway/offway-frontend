import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/storage/secure_storage.dart';
import 'package:offway/features/auth/data/auth_repository.dart';

/// 회원 탈퇴 — 서버가 계정을 지운 뒤 앱이 무엇을 비우는지 고정한다.
///
/// App Store 심사 항목(5.1.1(v))이라 실패를 삼키면 안 된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = TokenStorage(const FlutterSecureStorage());
  });

  AuthRepository repositoryThatReturns(int status) {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = _StubAdapter(status);
    return AuthRepository(dio, storage);
  }

  /// 로그인해 둔 상태를 만든다
  Future<void> signIn() =>
      storage.saveTokens(accessToken: 'jwt', refreshToken: 'refresh');

  test('탈퇴에 성공하면 토큰을 비운다', () async {
    await signIn();

    await repositoryThatReturns(200).withdraw();

    expect(await storage.accessToken, isNull);
    expect(await storage.refreshToken, isNull);
  });

  test('탈퇴에 실패하면 아무것도 지우지 않는다', () async {
    // 서버가 못 지웠는데 로컬만 비우면 사용자는 탈퇴된 줄 알지만
    // 데이터는 그대로 남는다
    await signIn();

    await expectLater(
      repositoryThatReturns(500).withdraw(),
      throwsA(isA<ApiException>()),
    );

    expect(await storage.accessToken, 'jwt');
    expect(await storage.refreshToken, 'refresh');
  });

  test('이미 탈퇴한 계정이면 401이 그대로 올라온다', () async {
    // access 토큰은 만료 전까지 서명 검증을 통과한다 — 그 창에 다시
    // 부르면 서버가 USER-006으로 끊는다
    await signIn();

    await expectLater(
      repositoryThatReturns(401).withdraw(),
      throwsA(isA<ApiException>()),
    );
  });

  test('로그아웃도 토큰을 비운다', () async {
    await signIn();

    await repositoryThatReturns(200).logout();

    expect(await storage.accessToken, isNull);
  });
}

/// 지정한 상태 코드로만 답하는 어댑터
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (status >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: {'status': status, 'code': 'USER-006', 'detail': '탈퇴한 계정이에요'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      '{"status":200,"code":"OK","detail":"탈퇴 처리되었습니다.","data":null}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
