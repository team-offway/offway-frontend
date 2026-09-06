import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/course/data/course_repository.dart';

/// 저장 코스의 수단 변경이 **서버 계약대로** 나가는지 고정한다 (core #458).
///
/// `PATCH /courses/{id}/transit-mode` 에 `{"transitMode": "..."}` 하나다.
/// 상세 화면의 '기차로 보기' 버튼이 이 길로 가고, 서버가 카드와 도착·출발
/// 칸을 함께 바꾼 코스를 저장한다.
void main() {
  late List<RequestOptions> sent;
  late CourseRepository repository;
  late int status;
  late String body;

  setUp(() {
    sent = [];
    status = 200;
    body = '{"code":"OK","status":200,"data":{}}';
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = _RecordingAdapter(
      sent,
      status: () => status,
      body: () => body,
    );
    repository = CourseRepository(dio);
  });

  test('PATCH /courses/{id}/transit-mode 로 수단 하나만 보낸다', () async {
    await repository.changeTransitMode(courseId: '12', transitMode: 'TRAIN');

    expect(sent, hasLength(1));
    expect(sent.single.method, 'PATCH');
    expect(sent.single.path, '/api/v1/courses/12/transit-mode');
    expect(sent.single.data, {'transitMode': 'TRAIN'});
  });

  test('자차 코스의 400은 ApiException으로 올라온다', () async {
    // 서버가 ITINERARY-010 으로 거절한다 — 화면은 detail을 토스트로 보여준다
    status = 400;
    body =
        '{"code":"ITINERARY-010","status":400,'
        '"detail":"자차 코스는 대중교통 수단을 바꿀 수 없어요."}';

    await expectLater(
      repository.changeTransitMode(courseId: '12', transitMode: 'TRAIN'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'ITINERARY-010'),
      ),
    );
  });
}

/// 보낸 요청을 기억하고 정해 둔 응답을 돌려주는 대역
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.sent, {required this.status, required this.body});

  final List<RequestOptions> sent;
  final int Function() status;
  final String Function() body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    return ResponseBody.fromString(
      body(),
      status(),
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
