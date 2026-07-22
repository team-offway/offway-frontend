import 'package:flutter_riverpod/flutter_riverpod.dart';

/// STEP0 갈림길 선택지
enum DatePathChoice {
  /// 가고싶은 날짜가 있어요 → 캘린더 직접 선택(A 경로)
  haveDates,

  /// 아직 안 정했어요 → 기간 스타일 선택(B 경로)
  undecided,
}

/// 코스 추천 위저드(O-04-0 ~ O-08)가 단계별로 채워가는 조건.
/// 이후 스텝(기간스타일·이동수단·일정밀도) 필드를 여기에 추가한다.
class CourseWizardDraft {
  const CourseWizardDraft({this.datePath, this.startDate, this.endDate});

  final DatePathChoice? datePath;

  /// A 경로(캘린더)에서 선택한 가는날/오는날. 당일치기는 두 값이 같다.
  final DateTime? startDate;
  final DateTime? endDate;

  bool get hasDateRange => startDate != null && endDate != null;
}

/// 핵심 정책: 모든 코스는 최대 2박3일 → 가는날~오는날 간격 최대 2일
const int kMaxTripSpanDays = 2;

class CourseWizardNotifier extends Notifier<CourseWizardDraft> {
  @override
  CourseWizardDraft build() => const CourseWizardDraft();

  void selectDatePath(DatePathChoice choice) {
    state = CourseWizardDraft(
      datePath: choice,
      startDate: state.startDate,
      endDate: state.endDate,
    );
  }

  /// 캘린더 날짜 탭 처리.
  /// 시작일 없음 → 시작일 지정 / 시작일만 있음 → 범위 확정(2박3일 이내) 또는 재시작
  void selectDate(DateTime day) {
    final start = state.startDate;
    final end = state.endDate;

    if (start == null || end != null) {
      // 새 선택 시작 (기존 범위가 있으면 리셋)
      state = CourseWizardDraft(datePath: state.datePath, startDate: day);
      return;
    }
    final diff = day.difference(start).inDays;
    if (diff < 0 || diff > kMaxTripSpanDays) {
      // 시작일 이전이거나 2박3일 초과 → 해당 날짜로 다시 시작
      state = CourseWizardDraft(datePath: state.datePath, startDate: day);
    } else {
      // 범위 확정 (같은 날 = 당일치기)
      state = CourseWizardDraft(
        datePath: state.datePath,
        startDate: start,
        endDate: day,
      );
    }
  }

  void reset() => state = const CourseWizardDraft();
}

final courseWizardProvider =
    NotifierProvider<CourseWizardNotifier, CourseWizardDraft>(
      CourseWizardNotifier.new,
    );
