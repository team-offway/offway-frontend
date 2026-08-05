import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(dioProvider)),
);

/// 홈 API(`GET /api/v1/home`) 한 번으로 받는 화면 데이터.
class HomeSnapshot {
  const HomeSnapshot({
    required this.user,
    required this.regions,
    this.filters = const [],
  });

  /// `{nickname, remainingLeaveDays(double?)}`
  final Map<String, dynamic> user;

  /// RegionCard가 읽는 형태 (name·sido·benefitBadge·categoryCounts…)
  final List<Map<String, dynamic>> regions;

  /// 카테고리 칩 `[{key, label}]` — 구성·순서를 서버가 정한다
  final List<Map<String, dynamic>> filters;
}

/// 홈 API. 게스트 식별은 인터셉터의 X-Guest-Id가 맡는다.
class HomeRepository {
  HomeRepository(this._dio);

  final Dio _dio;

  Future<HomeSnapshot> fetch() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/home');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final regions = (data['recommendedRegions'] as List)
          .cast<Map<String, dynamic>>();
      return HomeSnapshot(
        user: {
          'nickname': user['name'],
          'remainingLeaveDays': user['remainingLeaveDays'],
        },
        regions: regions.map(_toRegionCardMap).toList(),
        filters: ((data['filters'] as List?) ?? const [])
            .cast<Map<String, dynamic>>(),
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 서버 카드 → 화면(RegionCard)이 읽는 형태.
  ///
  /// 서버는 지역명을 "동구 · 부산광역시"로 합쳐 주므로 화면이 다시 조립하지
  /// 않도록 쪼개 넣는다. 카테고리는 화면 필터가 한글 라벨('체험' 등)로
  /// 거르므로 라벨을 키로 편다.
  Map<String, dynamic> _toRegionCardMap(Map<String, dynamic> card) {
    final nameParts = (card['name'] as String).split(' · ');
    final benefit = card['benefit'] as Map<String, dynamic>?;
    final categories = (card['categories'] as List)
        .cast<Map<String, dynamic>>();
    return {
      'id': (card['regionId'] as num).toString(),
      'name': nameParts.first,
      'sido': nameParts.length > 1 ? nameParts[1] : '',
      'imageUrl': card['imageUrl'],
      if (benefit != null) 'benefitBadge': benefit['text'],
      if (benefit != null) 'benefitPolicyId': benefit['policyId'],
      'categoryCounts': {for (final c in categories) c['label'] as String: 1},
    };
  }
}
