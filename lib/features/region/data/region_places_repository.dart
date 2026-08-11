import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final regionPlacesRepositoryProvider = Provider<RegionPlacesRepository>(
  (ref) => RegionPlacesRepository(ref.watch(dioProvider)),
);

/// 지역의 장소 목록 — 인허가 데이터라 외부 관광 API 한도와 무관하게 늘 나온다.
/// 사진·소개는 없고 이름·주소·전화·좌표만 있다.
class RegionPlacesRepository {
  RegionPlacesRepository(this._dio);

  final Dio _dio;

  /// `GET /regions/{regionId}/places` — [kind]는 SIGHT·FOOD·CAFE·STAY
  Future<List<Map<String, dynamic>>> places({
    required String regionId,
    required String kind,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/regions/$regionId/places',
        queryParameters: {'kind': kind, 'size': size},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final places = ((data['places'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      // 인허가 데이터에는 같은 상호가 여러 건 올라와 있다(지점·재등록 등).
      // 목록에 같은 이름이 잇달아 보이지 않게 이름 기준으로 한 번만 남긴다
      final seen = <String>{};
      return [
        for (final p in places)
          if (seen.add((p['name'] as String?) ?? '')) p,
      ];
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }
}

/// 지역 상세에 보여줄 관광명소 — 소개글이 없는 지역이라도 이건 채울 수 있다
final regionSightsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, regionId) => ref
          .watch(regionPlacesRepositoryProvider)
          .places(regionId: regionId, kind: 'SIGHT', size: 6),
    );
