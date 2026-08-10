import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/trip_date_range_picker.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../course_wizard/presentation/calendar_screen.dart'
    show tripConsumedLeaveProvider;
import 'saved_course_screen.dart' show savedCourseDetailProvider;

/// 저장한 코스의 여행 날짜 수정 (미확정 코스의 날짜 지정도 겸한다).
///
/// 코스 길이는 이미 정해져 있으므로 시작일만 고르면 범위가 그 길이로 움직인다.
/// 날짜가 있는 코스는 기존 범위를 미리 칠해두고, 다른 날을 골라야 수정하기가
/// 살아난다.
class CourseScheduleScreen extends ConsumerStatefulWidget {
  const CourseScheduleScreen({super.key, required this.savedId});

  final String savedId;

  @override
  ConsumerState<CourseScheduleScreen> createState() =>
      _CourseScheduleScreenState();
}

class _CourseScheduleScreenState extends ConsumerState<CourseScheduleScreen> {
  DateTime? _picked;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(savedCourseDetailProvider(widget.savedId));

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              e is ApiException ? e.detail : '코스를 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: AppTypography.label1NormalMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ),
          data: (data) => data == null
              ? const Center(child: Text('저장한 코스를 찾을 수 없어요'))
              : _buildBody(data.saved, data.course),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> saved, Map<String, dynamic> course) {
    final today = DateUtils.dateOnly(DateTime.now());
    final travelDays = course['durationDays'] as int;
    final original = DateTime.tryParse(saved['startDate'] as String? ?? '');
    // 지나간 날짜는 어차피 고를 수 없으니 미리 칠하지 않는다
    final presetStart = original != null && !original.isBefore(today)
        ? original
        : null;
    final start = _picked ?? presetStart;
    final end = start == null
        ? null
        : DateTime(start.year, start.month, start.day + travelDays - 1);
    final consumed = start != null && end != null
        ? ref.watch(tripConsumedLeaveProvider((start: start, end: end))).value
        : null;
    final hasOriginal = original != null;
    // 날짜 수정은 다른 날을 골라야 의미가 있다 — 그대로면 버튼을 재운다
    final canSubmit = _picked != null && (_picked != original);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // 버튼이 아이콘보다 넓으므로 좌측 여백을 줄여 아이콘 위치를 맞춘다
          padding: const EdgeInsets.fromLTRB(6, 0, 20, 0),
          child: AppBackButton(onTap: () => context.pop()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasOriginal ? '여행 날짜 수정' : '여행 날짜 선택',
                style: AppTypography.title3Bold.copyWith(
                  color: AppColors.labelNormal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '일정에 따른 날씨예보, 휴무일 정보를 알려드려요.',
                style: AppTypography.body1NormalMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const TripDateLimitBanner(),
        Expanded(
          child: TripDateRangePicker(
            today: today,
            startDate: start,
            endDate: end,
            // 길이가 정해진 코스라 시작일만 고르면 범위가 통째로 옮겨진다
            onSelect: (day) => setState(() => _picked = day),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            children: [
              // 자리를 늘 차지해 날짜를 고를 때 버튼이 움직이지 않게 한다
              SizedBox(
                height: 22,
                child: consumed == null
                    ? null
                    : Text(
                        '차감 연차 일수 ${formatLeaveDays(consumed)}일',
                        style: AppTypography.body2NormalMedium.copyWith(
                          color: AppColors.labelAlternative,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryNormal,
                    disabledBackgroundColor: AppColors.interactionDisable,
                    foregroundColor: AppColors.staticWhite,
                    disabledForegroundColor: AppColors.labelAssistive,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    hasOriginal ? '수정하기' : '선택 완료',
                    style: AppTypography.body1NormalBold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _submit() {
    // TODO(server): 저장 코스 날짜 수정 API가 없다 (PATCH/PUT 405 확인,
    // 재저장 우회도 상세 응답에 transport가 없어 불가). API가 생기면 여기서
    // 저장하고 '날짜가 변경됐어요.' 토스트와 함께 상세로 돌아간다.
    showAppToast(context, '날짜 수정은 서버 준비 중이에요');
  }
}
