import 'dart:convert';

import 'package:flutter/services.dart';

/// **테스트 픽스처** 로더 — 앱 코드는 쓰지 않는다(위젯 테스트만 읽는다).
///
/// 서버가 생기기 전 화면을 그리려고 만든 것이 테스트용으로 남았다.
/// 데이터는 지어낸 값이 아니라 TourAPI 실데이터에서 추출한 것
/// (정선·영월 실제 콘텐츠와 연관관광지 체인).
class MockDataSource {
  MockDataSource._();

  static Future<Map<String, dynamic>> _load(String name) async {
    // cache: false — 위젯 테스트에서 FakeAsync에 갇힌 pending Future가
    // 전역 캐시에 남아 다른 테스트를 오염시키는 것을 방지 (mock JSON은 작아 비용 무시 가능)
    final text = await rootBundle.loadString(
      'assets/mock/$name.json',
      cache: false,
    );
    return json.decode(text) as Map<String, dynamic>;
  }

  /// 사용자 정보: nickname, remainingLeaveDays
  static Future<Map<String, dynamic>> user() => _load('user');

  /// 지역 목록: candidates(후보지역 카드용 — 정선·영월),
  /// monthlyPicks(홈 '이번달 추천 여행지'용)
  static Future<Map<String, dynamic>> regions() => _load('regions');

  /// candidates + monthlyPicks를 합친 전체 지역 목록.
  /// 홈·목록·상세가 같은 집합을 봐야 하므로 병합은 여기서만 한다
  static Future<List<Map<String, dynamic>>> allRegions() async {
    final data = await regions();
    return [
      ...(data['candidates'] as List).cast<Map<String, dynamic>>(),
      ...(data['monthlyPicks'] as List).cast<Map<String, dynamic>>(),
    ];
  }

  /// 추천 코스: courses[] — 당일치기/2박3일, Day별 장소(이름·카테고리·이미지·좌표)
  static Future<Map<String, dynamic>> courses() => _load('courses');
}
