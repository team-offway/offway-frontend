import 'package:flutter_riverpod/flutter_riverpod.dart';

/// STEP0 갈림길 선택지
enum DatePathChoice {
  /// 가고싶은 날짜가 있어요 → 캘린더 직접 선택(A 경로)
  haveDates,

  /// 아직 안 정했어요 → 기간 스타일 선택(B 경로)
  undecided,
}

/// 코스 추천 위저드(O-04-0 ~ O-08)가 단계별로 채워가는 조건.
/// 이후 스텝(기간스타일·날짜·이동수단·일정밀도) 필드를 여기에 추가한다.
class CourseWizardDraft {
  const CourseWizardDraft({this.datePath});

  final DatePathChoice? datePath;

  CourseWizardDraft copyWith({DatePathChoice? datePath}) {
    return CourseWizardDraft(datePath: datePath ?? this.datePath);
  }
}

class CourseWizardNotifier extends Notifier<CourseWizardDraft> {
  @override
  CourseWizardDraft build() => const CourseWizardDraft();

  void selectDatePath(DatePathChoice choice) {
    state = state.copyWith(datePath: choice);
  }

  void reset() => state = const CourseWizardDraft();
}

final courseWizardProvider =
    NotifierProvider<CourseWizardNotifier, CourseWizardDraft>(
      CourseWizardNotifier.new,
    );
