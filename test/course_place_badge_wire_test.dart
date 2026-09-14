import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/location/origin_locator.dart';
import 'package:offway/features/course/data/course_repository.dart';

/// 서버가 주는 코스 응답을 그대로 태워, 장소 성격 뱃지의 재료가 화면이
/// 읽는 자리까지 살아 오는지 본다 (core #567·#568).
///
/// **키가 없으면 안 실려야 한다.** 서버가 "모른다"와 "아니다"를 갈라
/// 두었으므로, 앱이 false·빈 문자열로 메우면 그 구분이 사라진다.
void main() {
  String body({Map<String, Object>? pet, Map<String, Object>? crowd}) =>
      jsonEncode({
        'status': 200,
        'data': {
          'courseId': 1,
          'regionId': 4,
          'travelDays': 1,
          'travelDate': '2026-09-20',
          'days': [
            {
              'day': 1,
              'date': '2026-09-20',
              'dayOfWeek': '일',
              'items': [
                {
                  'title': '예산시장',
                  'categoryLabel': '관광',
                  'kind': 'SIGHT',
                  'poiContentId': '1',
                  'catchphrase': '예산 지역을 대표하는 재래시장',
                  'petAccompany': ?pet,
                  'crowd': ?crowd,
                },
              ],
            },
          ],
        },
        'detail': null,
        'code': 'OK',
      });

  Future<Map<String, dynamic>> firstPlace({
    Map<String, Object>? pet,
    Map<String, Object>? crowd,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
      ..httpClientAdapter = _StubAdapter(body(pet: pet, crowd: crowd));
    final course = await CourseRepository(dio).generate(
      regionId: '4',
      travelDays: 1,
      density: 'RELAXED',
      transport: 'CAR',
      origin: const Origin(lat: 37.5, lng: 127.0, isFallback: false),
      travelDate: DateTime(2026, 9, 20),
    );
    final days = (course['days'] as List).cast<Map<String, dynamic>>();
    return (days.first['places'] as List).cast<Map<String, dynamic>>().first;
  }

  test('반려동반·혼잡이 시트가 읽는 자리까지 닿는다', () async {
    final place = await firstPlace(
      pet: {'wholeArea': true, 'area': '전구역 동반가능', 'pet': '전 견종 동반 가능'},
      crowd: {
        'level': 'BUSY',
        'basis': 'ATTRACTION_FORECAST',
        'label': '이날 붐빔',
      },
    );

    expect((place['petAccompany']! as Map)['wholeArea'], isTrue);
    expect((place['crowd']! as Map)['label'], '이날 붐빔');
  });

  test('일부 구역도 그대로 넘어온다 — 앱이 전 구역으로 바꾸지 않는다', () async {
    final place = await firstPlace(
      pet: {'wholeArea': false, 'area': '일부구역 동반가능'},
    );

    expect((place['petAccompany']! as Map)['wholeArea'], isFalse);
  });

  test('서버가 안 주면 키를 만들지 않는다 — 없음과 불가는 다르다', () async {
    final place = await firstPlace();

    expect(place.containsKey('petAccompany'), isFalse);
    expect(place.containsKey('crowd'), isFalse);
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
