import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LeaveRepository(ref.watch(dioProvider)),
);

/// 연차 API (`/api/v1/leaves`). 게스트 식별은 인터셉터의 X-Guest-Id가 맡는다.
class LeaveRepository {
  LeaveRepository(this._dio);

  final Dio _dio;

  /// 총 연차를 서버에 저장하고 남은 연차를 돌려받는다 (온보딩 입력).
  Future<double> updateTotalDays(double totalDays) async {
    try {
      final response = await _dio.patch<dynamic>(
        '/api/v1/leaves/me',
        data: {'totalDays': totalDays},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return (data['remainingDays'] as num).toDouble();
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }
}
