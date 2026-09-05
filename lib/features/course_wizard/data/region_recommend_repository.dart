import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/origin_locator.dart';
import '../../../core/network/api_envelope.dart';
import '../../region/domain/region_visit_metrics.dart';
import '../../../core/network/dio_client.dart';

final regionRecommendRepositoryProvider = Provider<RegionRecommendRepository>(
  (ref) => RegionRecommendRepository(ref.watch(dioProvider)),
);

/// 후보지역 추천 API (`POST /api/v1/regions/recommendations`).
class RegionRecommendRepository {
  RegionRecommendRepository(this._dio);

  final Dio _dio;

  /// [transport]는 서버 enum 문자열(CAR·TRANSIT).
  /// [maxReachMinutes]는 가용시간 계산이 준 도달 한계 — 일정이 짧을수록 줄어든다.
  Future<({List<Map<String, dynamic>> regions, List<DataSource> sources})>
  recommend({
    required Origin origin,
    required String transport,
    required int maxReachMinutes,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/regions/recommendations',
        data: {
          'originLat': origin.lat,
          'originLng': origin.lng,
          'transport': transport,
          'maxReachMinutes': maxReachMinutes,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final regions = (data['regions'] as List).cast<Map<String, dynamic>>();
      // 출처는 래퍼 옆에 온다(core #417). 카드마다 붙일 값이 아니라 응답
      // 하나에 하나라, 항목마다 복사하지 않고 카드와 같은 목록에 실어 화면이
      // 끝에 한 줄로 표기한다
      final sources = ApiEnvelope.sourcesOf(response);
      return (
        regions: regions.map((r) => _toCandidateMap(r, transport)).toList(),
        sources: sources,
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 서버 추천 항목 → 후보지역 카드가 읽는 형태.
  Map<String, dynamic> _toCandidateMap(
    Map<String, dynamic> item,
    String transport,
  ) {
    final nameParts = (item['name'] as String).split(' · ');
    final benefits = (item['benefits'] as List?) ?? const [];
    return {
      'id': (item['regionId'] as num).toString(),
      'name': nameParts.first,
      'sido': nameParts.length > 1 ? nameParts[1] : '',
      'imageUrl': item['imageUrl'],
      // 캡션 자리에는 고른 이동수단 기준 도달시간을 보여준다
      'description': _reachText(item['reachMinutes'] as int, transport),
      'reachMinutes': item['reachMinutes'],
      'contentCount': item['contentCount'],
      // 한줄소개 — 랜덤 지역 결과 모달이 쓴다. 재료가 없으면 서버가 안 준다
      'intro': item['intro'],
      // 지도 칩 자리(core #405). 없으면 앱 표로 물러난다
      'lat': item['lat'],
      'lng': item['lng'],
      // 혜택 뱃지 — 홈 카드와 같은 첫 번째 혜택. 누르면 정책 상세가 열린다.
      // 한산/인기(crowdLevel) 뱃지는 시안이 혜택 칩으로 바꿔 더 안 그린다.
      // 서버가 셋을 한 모양(`BenefitResponse`)으로 맞췄으므로(core #418)
      // 필드를 흩지 않고 통째로 넘긴다 — 화면이 `RegionBenefit`으로 읽는다
      if (benefits.isNotEmpty) 'benefit': benefits.first,
      // 인기 추세 (core #438) — 카드의 '최근 인기 상승' 칩이 이 값을 쓴다.
      // 재료가 모자라면 서버가 비우고, 그때는 칩이 안 붙는다
      'visitMetrics': RegionVisitMetrics.parse(item['visitMetrics']),
    };
  }

  String _reachText(int minutes, String transport) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final time = h == 0 ? '$m분' : (m == 0 ? '$h시간' : '$h시간 $m분');
    // 시안 문구: '자차 약 1시간 소요' — 수단을 먼저, 소요로 닫는다
    return transport == 'TRANSIT' ? '대중교통 약 $time 소요' : '자차 약 $time 소요';
  }
}
