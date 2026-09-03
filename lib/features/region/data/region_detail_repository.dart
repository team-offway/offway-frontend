import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final regionDetailRepositoryProvider = Provider<RegionDetailRepository>(
  (ref) => RegionDetailRepository(ref.watch(dioProvider)),
);

/// 지역 상세 (`GET /regions/{regionId}`, core #307).
///
/// 소개글·사진·혜택·매력 포인트 장소를 한 번에 준다. 예전에는 mock과 홈 카드,
/// 장소 목록 셋을 섞어 만들었는데 그렇게 만든 장소에는 사진이 없어 회색 판만
/// 남았다.
class RegionDetailRepository {
  RegionDetailRepository(this._dio);

  final Dio _dio;

  /// 없는 지역이면 서버가 404를 준다 — [ApiException]으로 올라간다.
  Future<Map<String, dynamic>> detail(String regionId) async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/regions/$regionId');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      // 출처는 data가 아니라 공통 래퍼 옆에 실려 온다(core #417) — 화면이
      // 끝에 표기해야 해서 함께 실어 나른다
      return {...data, '_sources': ApiEnvelope.sourcesOf(response)};
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }
}
