import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/trip_constants.dart';
import '../../../core/network/api_envelope.dart';
import '../../onboarding/data/leave_repository.dart';

/// 고른 기간이 연차를 며칠 깎는지 — 서버가 평일−공휴일로 계산한다.
///
/// 코스 위저드 달력과 연차 사용일 고르기 화면이 함께 쓴다. 위저드는 이
/// 시점에 이동수단을 아직 안 골랐지만 연차 소모는 이동수단과 무관하므로
/// CAR로 임시 지정해 묻는다. 서버가 안 되면 공휴일 목록(core #322)을 끼운
/// 로컬 계산으로 폴백한다 — 그 목록마저 없으면 주말만 뺀 근사값이 된다.
final tripConsumedLeaveProvider = FutureProvider.autoDispose
    .family<double, ({DateTime start, DateTime end})>((ref, range) async {
      try {
        final result = await ref
            .read(leaveRepositoryProvider)
            .availableTime(
              transport: 'CAR',
              startDate: range.start,
              endDate: range.end,
            );
        return result.consumedLeaveDays;
      } on ApiException {
        final holidays = await holidaysBetween(ref, range.start, range.end);
        return leaveDaysBetween(
          range.start,
          range.end,
          holidays: holidays,
        ).toDouble();
      }
    });
