import 'dart:convert';

import 'package:flutter/services.dart';

/// 서버(Spring) 구축 전까지 화면 개발에 사용하는 mock 데이터 로더.
///
/// 데이터는 지어낸 값이 아니라 TourAPI 실데이터에서 추출한 것
/// (정선·영월 실제 콘텐츠와 연관관광지 체인, docs/tourapi-분류체계-조사.md 참고).
/// 화면별 모델(freezed)이 확정되면 repository 인터페이스 뒤로 옮기고,
/// 서버 연동 시 이 클래스만 실 API 구현으로 교체한다.
class MockDataSource {
  MockDataSource._();

  static Future<Map<String, dynamic>> _load(String name) async {
    final text = await rootBundle.loadString('assets/mock/$name.json');
    return json.decode(text) as Map<String, dynamic>;
  }

  /// 사용자 정보: nickname, remainingLeaveDays
  static Future<Map<String, dynamic>> user() => _load('user');

  /// 지역 목록: candidates(후보지역 카드용 — 정선·영월),
  /// monthlyPicks(홈 '이번달 추천 여행지'용)
  static Future<Map<String, dynamic>> regions() => _load('regions');

  /// 추천 코스: courses[] — 당일치기/2박3일, Day별 장소(이름·카테고리·이미지·좌표)
  static Future<Map<String, dynamic>> courses() => _load('courses');
}
