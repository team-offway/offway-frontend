import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../leave/domain/leave_usage.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/date_format.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LeaveRepository(ref.watch(dioProvider)),
);

/// 가용시간 계산 결과 — 확정된 여행 기간과 그에 따른 연차 소모·도달 한계.
typedef AvailableTime = ({
  DateTime startDate,
  DateTime endDate,
  int travelDays,
  double consumedLeaveDays,
  int maxReachMinutes,
});

/// 연차 API (`/api/v1/leaves`). 사용자 식별은 인터셉터가 싣는 JWT가 맡는다.
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

  /// 내 연차 — 잔여 일수와 사용 내역을 함께 받는다 (`GET /leaves/me`).
  Future<MyLeave> fetchMyLeave() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/leaves/me');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return MyLeave.fromJson(data);
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 사용 내역 삭제 (`DELETE /leaves/me/usages/{id}`) — core#268.
  ///
  /// 예전에는 음수를 새로 등록해 상쇄했는데, 같은 요청이 두 번 들어가면
  /// 그만큼 더 상쇄돼 **없던 연차가 생겼다.** 이제 한 행을 지운다.
  ///
  /// 응답에 갱신된 연차 전체가 실려 오므로 목록을 다시 부르지 않아도 된다.
  /// 코스 확정으로 생긴 내역은 409로 막힌다 — 코스 화면에서 되돌려야 한다.
  Future<MyLeave> deleteUsage(int usageId) async {
    try {
      final response = await _dio.delete<dynamic>(
        '/api/v1/leaves/me/usages/$usageId',
      );
      return MyLeave.fromJson(
        ApiEnvelope.unwrap(response) as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 연차 사용 내역 추가 (`POST /leaves/me/usages`).
  ///
  /// [days]는 0.25 단위이고, 사용이면 양수·취소면 음수다.
  /// [courseId]는 코스에서 차감할 때만 넣는다.
  Future<void> addUsage({
    required DateTime usedOn,
    required double days,
    String? reason,
    int? courseId,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/leaves/me/usages',
        data: {
          'usedOn': _isoDate(usedOn),
          'days': days,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          'courseId': ?courseId,
        },
      );
      // HTTP 200이어도 실패 래퍼일 수 있다 — 여기서 걸러야 등록 실패가 성공으로 보이지 않는다
      ApiEnvelope.unwrap(response);
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 가용시간 계산 (`POST /leaves/available-time`).
  ///
  /// 두 모드 중 하나로 부른다 — 날짜 모드([startDate]+[endDate])는 고른 기간의
  /// 연차 소모(평일−공휴일)를, 스타일 모드([periodStyle]+[baseDate])는 스타일에서
  /// 가장 가까운 기간 자체를 서버가 확정해 준다. 도달 한계(maxReachMinutes)도
  /// 여기서 나와 지역 추천의 입력이 된다.
  ///
  /// [periodStyle]은 DAY_TRIP·WEEKEND·CONNECTED, [weekendBridge]는
  /// FRIDAY·MONDAY (서버 enum 문자열).
  Future<AvailableTime> availableTime({
    required String transport,
    DateTime? startDate,
    DateTime? endDate,
    String? periodStyle,
    DateTime? baseDate,
    String? weekendBridge,
    int? leaveDays,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/leaves/available-time',
        data: {
          'transport': transport,
          'startDate': ?_isoDate(startDate),
          'endDate': ?_isoDate(endDate),
          'periodStyle': ?periodStyle,
          'baseDate': ?_isoDate(baseDate),
          'weekendBridge': ?weekendBridge,
          'leaveDays': ?leaveDays,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return (
        startDate: DateTime.parse(data['startDate'] as String),
        endDate: DateTime.parse(data['endDate'] as String),
        travelDays: data['travelDays'] as int,
        consumedLeaveDays: (data['consumedLeaveDays'] as num).toDouble(),
        maxReachMinutes: data['maxReachMinutes'] as int,
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  static String? _isoDate(DateTime? d) => d == null ? null : isoDate(d);
}
