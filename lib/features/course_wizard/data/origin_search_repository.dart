import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../domain/origin_hub.dart';

final originSearchRepositoryProvider = Provider<OriginSearchRepository>(
  (ref) => OriginSearchRepository(ref.watch(dioProvider)),
);

/// 출발지 자동완성 (`GET /api/v1/origins?query=`).
///
/// 역·터미널을 먼저 내리고 모자란 자리를 주소·장소로 채운 목록이 온다
/// (core #591). 앱은 좌표를 다루지 않고 [OriginHub.code] 만 들고 다닌다.
class OriginSearchRepository {
  OriginSearchRepository(this._dio);

  final Dio _dio;

  /// 서버가 두 글자 미만은 외부 검색을 부르지 않는다 — 부르기 전에 끊어
  /// 빈 목록이 오는 왕복을 아낀다
  static const minQueryLength = 2;

  Future<List<OriginHub>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < minQueryLength) return const [];
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/origins',
        queryParameters: {'query': trimmed},
        cancelToken: cancelToken,
      );
      final data = ApiEnvelope.unwrap(response) as List;
      return data
          .cast<Map<String, dynamic>>()
          .map(OriginHub.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      // 글자마다 이전 요청을 끊으므로 취소는 오류가 아니다
      if (CancelToken.isCancel(e)) return const [];
      throw ApiEnvelope.toApiException(e);
    }
  }
}
