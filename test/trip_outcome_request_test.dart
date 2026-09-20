import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/data/course_repository.dart';

/// 여행 결과를 보낼 때 **무엇을 싣는지** 고정한다.
///
/// 한 줄 평가는 선택이라(core #593) 보내는 조건이 셋이다 — 다녀왔을 때만,
/// 비어 있지 않을 때만, 앞뒤 공백을 걷어낸 뒤. 하나라도 어긋나면 서버가
/// 거절하거나(`ITINERARY-012`) 빈 의견이 집계에 섞인다.
void main() {
  /// 요청을 가로채 본문만 들고 있는 대역
  late Map<String, dynamic>? sent;

  CourseRepository repository() {
    final dio = Dio()
      ..httpClientAdapter = _CapturingAdapter((body) => sent = body);
    return CourseRepository(dio);
  }

  setUp(() => sent = null);

  test('다녀왔고 한 줄을 남겼으면 싣는다', () async {
    await repository().answerTripOutcome(
      1,
      visited: true,
      comment: '버스 배차가 아쉬웠어요',
    );

    expect(sent, {'outcome': 'VISITED', 'comment': '버스 배차가 아쉬웠어요'});
  });

  test('앞뒤 공백은 걷어낸다', () async {
    await repository().answerTripOutcome(1, visited: true, comment: '  좋았어요  ');

    expect(sent?['comment'], '좋았어요');
  });

  test('공백뿐이면 싣지 않는다 — 빈 의견이 집계에 섞이면 안 된다', () async {
    await repository().answerTripOutcome(1, visited: true, comment: '   ');

    expect(sent, {'outcome': 'VISITED'});
  });

  test('비어 있으면 싣지 않는다', () async {
    await repository().answerTripOutcome(1, visited: true, comment: '');

    expect(sent, {'outcome': 'VISITED'});
  });

  test('아예 없으면 싣지 않는다', () async {
    await repository().answerTripOutcome(1, visited: true);

    expect(sent, {'outcome': 'VISITED'});
  });

  test('안 갔다면 한 줄이 있어도 싣지 않는다', () async {
    // 가지 않은 여행의 평가는 성립하지 않아 서버가 거절한다(ITINERARY-012).
    // 쓰다가 '안갔어요' 를 눌러도 400 이 되면 안 된다
    await repository().answerTripOutcome(1, visited: false, comment: '쓰다 말았다');

    expect(sent, {'outcome': 'NOT_VISITED'});
  });
}

/// 보낸 본문을 넘겨주고 빈 성공 응답을 돌려준다
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.onSend);

  final void Function(Map<String, dynamic>?) onSend;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onSend((options.data as Map?)?.cast<String, dynamic>());
    return ResponseBody.fromString(
      jsonEncode({'status': 200, 'code': 'OK', 'data': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
