import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../../home/data/home_repository.dart' show toRegionCardMap;

/// 지역 목록 한 페이지 — 카드와 '다음이 더 있는지'를 함께 준다.
class RegionPage {
  const RegionPage({
    required this.regions,
    required this.hasMore,
    this.sources = const [],
  });

  /// RegionCard가 읽는 형태 (홈 카드와 같다)
  final List<Map<String, dynamic>> regions;

  /// 마지막 페이지면 false — 무한 스크롤을 여기서 멈춘다
  final bool hasMore;

  /// 이 응답이 빌려 쓴 공공데이터 (core #417) — 목록 끝에 표기한다
  final List<DataSource> sources;
}

/// 지역 목록 API (`GET /regions`) — core#272.
///
/// 예전에는 홈 응답(상위 6곳)을 재사용해 인구감소지역 89곳 중 6곳만 보였다.
/// 이 API는 페이징과 카테고리 필터를 함께 준다.
class RegionListRepository {
  RegionListRepository(this._dio);

  final Dio _dio;

  /// [category]는 서버 칩 키(`SIGHT`·`STAY`…). 'ALL'이나 null이면 전체.
  Future<RegionPage> fetch({
    String? category,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/regions',
        queryParameters: {
          if (category != null && category != 'ALL') 'category': category,
          'page': page,
          'size': size,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final regions = ((data['regions'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

      // 페이지 정보는 data가 아니라 공통 래퍼 옆에 실려 온다
      final body = response.data;
      final paging = body is Map<String, dynamic>
          ? body['pageResponse'] as Map<String, dynamic>?
          : null;
      final totalPages = (paging?['totalPages'] as num?)?.toInt();
      final hasMore = totalPages == null
          ? regions.isNotEmpty
          : page + 1 < totalPages;

      return RegionPage(
        regions: regions.map(toRegionCardMap).toList(),
        hasMore: hasMore,
        sources: ApiEnvelope.sourcesOf(response),
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }
}

final regionListRepositoryProvider = Provider<RegionListRepository>(
  (ref) => RegionListRepository(ref.watch(dioProvider)),
);
