import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/trip_activity/data/live_activity_repository.dart';

/// 잠금화면 카드의 갱신 토큰 등록(core #577) — 요청 본문과 실패 처리를 고정한다.
///
/// 서버가 이 등록으로 매일 자정에 카드를 갱신한다. 경로·본문이 어긋나면
/// 앱은 성공으로 알고 넘어가는데 자정 갱신은 영영 안 온다.
void main() {
  late List<({String path, String method, Object? body})> sent;

  LiveActivityRepository repositoryWith({int status = 200}) {
    sent = [];
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = _RecordingAdapter(sent, status);
    return LiveActivityRepository(dio);
  }

  test('코스 id 는 숫자로, 토큰은 그대로 보낸다', () async {
    // 앱은 코스 id 를 문자열로 들지만 서버 계약은 Long 이다 — 문자열로
    // 보내면 400 이다
    await repositoryWith().register(courseId: '122', token: '80a1b2c3');

    final request = sent.single;
    expect(request.path, '/api/v1/live-activities');
    expect(request.method, 'POST');

    final body = request.body! as Map;
    expect(body['courseId'], 122);
    expect(body['courseId'], isA<int>());
    expect(body['pushToken'], '80a1b2c3');
  });

  test('숫자가 아닌 코스 id 는 보내지 않고 거절한다', () async {
    // 서버에 닿기 전에 걸러야 400 을 등록 실패로 오해하지 않는다
    await expectLater(
      repositoryWith().register(courseId: 'preview', token: 'x'),
      throwsA(isA<ArgumentError>()),
    );
    expect(sent, isEmpty);
  });

  test('해제는 경로에 코스 id 를 싣고 본문은 없다', () async {
    await repositoryWith().unregister('122');

    final request = sent.single;
    expect(request.path, '/api/v1/live-activities/122');
    expect(request.method, 'DELETE');
    expect(request.body, isNull);
  });

  test('숫자가 아닌 코스 id 의 해제는 조용히 넘어간다', () async {
    // 등록된 적이 없는 값이라 지울 것도 없다
    await repositoryWith().unregister('preview');
    expect(sent, isEmpty);
  });

  test('등록이 실패하면 ApiException 으로 올라온다', () async {
    // 부르는 쪽이 삼킬지 알릴지 정한다
    await expectLater(
      repositoryWith(status: 500).register(courseId: '122', token: 'x'),
      throwsA(isA<ApiException>()),
    );
  });

  test('남의 코스면 404 가 그대로 올라온다', () async {
    // 서버가 "없다" 와 "남의 것" 을 가르지 않는다 — 앱도 가를 수 없다
    await expectLater(
      repositoryWith(status: 404).register(courseId: '999', token: 'x'),
      throwsA(isA<ApiException>()),
    );
  });
}

/// 요청을 받아 적고 지정한 상태로 답하는 어댑터
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.sent, this.status);

  final List<({String path, String method, Object? body})> sent;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add((path: options.path, method: options.method, body: options.data));
    if (status >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: {'status': status, 'detail': '실패', 'code': 'ERR'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      '{"status":200,"data":null,"detail":"ok","code":"OK"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
