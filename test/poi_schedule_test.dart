import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/data/course_repository.dart';

/// 2026-08-15 배포 서버(GET /api/v1/pois/{id})가 실제로 내려준 응답 그대로.
///
/// 서버는 운영 정보를 **타입별 블록**에 담고 최상위는 비워 둔다. 최상위만 읽던
/// 시절에는 식당·관광지 모두 영업시간이 빈 줄로 보였다.
Map<String, dynamic> _body(Map<String, dynamic> data) => {
  'status': 200,
  'data': data,
  'detail': '요청이 정상 처리되었습니다.',
  'code': 'OK',
  'pageResponse': null,
};

/// 지리산식당 — 식당은 `food.openTime`에 실려 온다
const _food = {
  'contentId': '1349270',
  'typeLabel': '음식점',
  'title': '지리산식당',
  'useTime': null,
  'restDate': null,
  'food': {
    'openTime': '07:30~21:00',
    'restDate': '연중무휴',
    'signatureMenu': '싸리버섯전골',
  },
  'sight': null,
  'stay': null,
};

/// 가회동성당 — 관광지는 `sight.useTime`
const _sight = {
  'contentId': '2733967',
  'typeLabel': '관광지',
  'title': '가회동성당',
  'useTime': null,
  'restDate': null,
  'sight': {'useTime': '09:00~18:00<br>※ 홈페이지 참조', 'restDate': '매주 월요일'},
  'food': null,
  'stay': null,
};

/// 숙소는 영업시간 대신 체크인/아웃을 보여준다
const _stay = {
  'contentId': '142785',
  'typeLabel': '숙박',
  'title': '지리산햇살',
  'useTime': null,
  'restDate': null,
  'stay': {'checkIn': '15:00', 'checkOut': '11:00', 'roomCount': '12'},
  'sight': null,
  'food': null,
};

void main() {
  CourseRepository repositoryFor(Map<String, dynamic> data) => CourseRepository(
    Dio(BaseOptions())..httpClientAdapter = _FixedResponseAdapter(_body(data)),
  );

  test('식당은 food.openTime을 운영시간으로 읽는다', () async {
    final schedule = await repositoryFor(_food).poiSchedule('1349270');

    expect(schedule.useTime, '07:30~21:00');
    expect(schedule.restDate, '연중무휴');
  });

  test('관광지는 sight 블록에서 읽고 HTML도 걷어낸다', () async {
    final schedule = await repositoryFor(_sight).poiSchedule('2733967');

    // <br>이 그대로 나가면 화면에 태그가 글자로 보인다
    expect(schedule.useTime, isNot(contains('<br>')));
    expect(schedule.useTime, contains('09:00~18:00'));
    expect(schedule.restDate, '매주 월요일');
  });

  test('숙소는 체크인·체크아웃으로 대신 보여준다', () async {
    final schedule = await repositoryFor(_stay).poiSchedule('142785');

    expect(schedule.useTime, '체크인 15:00 · 체크아웃 11:00');
    // 숙소에는 휴무일 개념이 없다 — 없는 값을 지어내지 않는다
    expect(schedule.restDate, isNull);
  });
}

class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
