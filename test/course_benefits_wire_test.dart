import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/location/origin_locator.dart';
import 'package:offway/features/course/data/course_repository.dart';
import 'package:offway/features/policy/domain/region_benefit.dart';

/// 서버가 실제로 주는 코스 응답을 그대로 태워, 화면이 읽는 자리까지
/// 혜택이 살아 오는지 본다.
///
/// **코스의 혜택은 홈·지역 상세와 필드 이름이 다르다.** 서버
/// `CourseResponse.Benefit`은 `policyId·type·text`뿐이라 `policyType`도
/// `applyUrl`도 없다(core #418이 세 화면만 통합했다). 카드는 `policyId`로
/// 정책 상세를 따로 불러 이름과 설명을 채우므로 그래도 그려진다.
void main() {
  /// 서버 응답을 흉내 낸다 — 예산군 코스에 충남 페스타가 걸린 모양
  String body({required List<Map<String, Object>> benefits}) => jsonEncode({
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
              'regionName': '예산군',
            },
          ],
        },
      ],
      'benefits': benefits,
    },
    'detail': null,
    'code': 'OK',
  });

  Future<Map<String, dynamic>> generate(
    List<Map<String, Object>> benefits,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
      ..httpClientAdapter = _StubAdapter(body(benefits: benefits));
    return CourseRepository(dio).generate(
      regionId: '4',
      travelDays: 1,
      density: 'RELAXED',
      transport: 'CAR',
      origin: const Origin(lat: 37.5, lng: 127.0, isFallback: false),
      travelDate: DateTime(2026, 9, 20),
    );
  }

  test('서버 응답의 혜택이 파싱된 목록으로 화면에 닿는다', () async {
    final course = await generate([
      {'policyId': 6, 'type': 'CHUNGNAM_TRAVEL_FESTA', 'text': '숙박 추가할인'},
      {'policyId': 3, 'type': 'DIGITAL_TOURIST_CARD', 'text': '디지털관광주민증'},
    ]);

    // 화면은 이 자리를 그대로 꺼내 쓴다 — 한 번 더 파싱하면 전부 버려진다
    final benefits = course['benefits'];
    expect(benefits, isA<List<RegionBenefit>>());
    expect((benefits! as List).length, 2);

    final first = (benefits as List<RegionBenefit>).first;
    expect(first.text, '숙박 추가할인');
    expect(first.policyId, 6);
    // 코스 응답에는 없는 값들 — 카드는 policyId 로 정책 상세를 불러 채운다
    expect(first.policyType, isNull);
    expect(first.applyUrl, isNull);
  });

  test('이미 파싱된 목록을 또 파싱하면 전부 사라진다 — 화면이 그러면 안 된다', () async {
    final course = await generate([
      {'policyId': 6, 'type': 'CHUNGNAM_TRAVEL_FESTA', 'text': '숙박 추가할인'},
    ]);

    // 실수를 못 박아 둔다: 이 자리에 parseList 를 또 부르면 빈 목록이 된다
    expect(RegionBenefit.parseList(course['benefits']), isEmpty);
  });

  test('혜택이 없는 지역은 benefits 키가 아예 없다', () async {
    final course = await generate([]);
    expect(course.containsKey('benefits'), isFalse);
    expect(course['benefit'], isNull);
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
