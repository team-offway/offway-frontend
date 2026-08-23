import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/origin_locator.dart';
import '../../../core/network/api_envelope.dart';
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
  Future<List<Map<String, dynamic>>> recommend({
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
      return regions.map((r) => _toCandidateMap(r, transport)).toList();
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
      // 한산도 뱃지 — 인구감소지역 서비스라 '한산'이 곧 장점이다
      'badge': switch (item['crowdLevel'] as String?) {
        'LOW' => '한산',
        'MID' => '보통',
        'HIGH' => '인기',
        _ => null,
      },
      // 캡션 자리에는 고른 이동수단 기준 도달시간을 보여준다
      'description': _reachText(item['reachMinutes'] as int, transport),
      'reachMinutes': item['reachMinutes'],
      'contentCount': item['contentCount'],
      if (benefits.isNotEmpty)
        'benefitBadge': (benefits.first as Map<String, dynamic>)['text'],
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
