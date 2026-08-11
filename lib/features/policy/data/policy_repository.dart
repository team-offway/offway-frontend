import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final policyRepositoryProvider = Provider<PolicyRepository>(
  (ref) => PolicyRepository(ref.watch(dioProvider)),
);

/// 정책(혜택) 상세 — 지역 카드의 혜택 뱃지에서 들어온다
class PolicyRepository {
  PolicyRepository(this._dio);

  final Dio _dio;

  /// 정책 상세와 이 혜택이 되는 여행지 목록 (`GET /policies/{id}`)
  Future<Map<String, dynamic>> detail(int policyId) async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/policies/$policyId');
      return ApiEnvelope.unwrap(response) as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }
}

/// 정책 상세 — 뱃지를 누른 정책 하나
final policyDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>(
      (ref, policyId) => ref.watch(policyRepositoryProvider).detail(policyId),
    );
