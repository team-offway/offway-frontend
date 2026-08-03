import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/trip_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../home/presentation/home_screen.dart';
import '../application/course_wizard_provider.dart';

/// O-04 · 기간스타일 (B 경로, STEP 2/4)
/// 주말 포함/연차만 선택 시 바텀시트로 하위 선택을 받는다.
class PeriodStyleScreen extends ConsumerWidget {
  const PeriodStyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(courseWizardProvider);
    final leaveDays = ref.watch(homeUserProvider).value?['remainingLeaveDays'];

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        // 액션 영역은 스크롤 밖에 두어 화면이 작아도 항상 닿는다.
        // 안에 넣으면 콘텐츠에 밀려 화면 밖으로 나가버린다.
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: 68),
                    SvgPicture.asset(
                      'assets/icons/ic_plane.svg',
                      width: 48,
                      height: 48,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '어떻게 떠날까요?',
                      textAlign: TextAlign.center,
                      style: AppTypography.title3Bold.copyWith(
                        color: AppColors.labelNormal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '여행 스타일에 맞는 코스를\n찾아드려요.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body1NormalMedium.copyWith(
                        color: AppColors.labelAlternative,
                      ),
                    ),
                    const SizedBox(height: 37),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _StyleCard(
                            iconAsset: 'assets/icons/ic_timer_bold.svg',
                            title: '당일치기 · 반차',
                            subtitle: '짧게 다녀와요',
                            selected: draft.periodStyle == PeriodStyle.dayTrip,
                            onTap: () => ref
                                .read(courseWizardProvider.notifier)
                                .selectPeriodStyle(PeriodStyle.dayTrip),
                          ),
                          const SizedBox(height: 12),
                          _StyleCard(
                            iconAsset: 'assets/icons/ic_clock.svg',
                            title: '주말 포함 여행',
                            subtitle: '주말을 이어 떠나요',
                            selected:
                                draft.periodStyle == PeriodStyle.weekendCombo,
                            onTap: () {
                              ref
                                  .read(courseWizardProvider.notifier)
                                  .selectPeriodStyle(PeriodStyle.weekendCombo);
                              _showWeekendPatternSheet(context, ref);
                            },
                          ),
                          const SizedBox(height: 12),
                          _StyleCard(
                            iconAsset: 'assets/icons/ic_coffee.svg',
                            title: '연차만 (주말 미포함)',
                            subtitle: '평일에 여유를 즐겨요',
                            selected:
                                draft.periodStyle == PeriodStyle.leaveOnly,
                            onTap: () {
                              ref
                                  .read(courseWizardProvider.notifier)
                                  .selectPeriodStyle(PeriodStyle.leaveOnly);
                              _showLeaveStepperSheet(context, ref);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Text(
                    '남은 연차일수 ${leaveDays ?? '-'}일',
                    style: AppTypography.label1ReadingMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: draft.isPeriodStyleComplete
                          ? () => context.push(AppRoutes.wizardTransport)
                          : null,
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
                      child: Text('다음', style: AppTypography.body1NormalBold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 뒤로가기 + 단계 표시. 단계는 오른쪽에 옅게 둔다.
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: AppColors.labelNormal,
            ),
          ),
          const Spacer(),
          Text(
            '2/4',
            style: AppTypography.body1NormalBold.copyWith(
              color: AppColors.labelAssistive,
            ),
          ),
        ],
      ),
    );
  }

  /// 모달: 언제 하루 더 쉴까요? (금요일 / 월요일 하루를 붙인다)
  void _showWeekendPatternSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      barrierColor: AppColors.materialDimmer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        WeekendPattern? selected = ref
            .read(courseWizardProvider)
            .weekendPattern;
        return StatefulBuilder(
          builder: (context, setSheetState) => _SheetScaffold(
            title: '언제 하루 더 쉴까요?',
            subtitle: '주말은 자동으로 포함돼요.',
            confirmEnabled: selected != null,
            onConfirm: () {
              ref
                  .read(courseWizardProvider.notifier)
                  .selectWeekendPattern(selected!);
              Navigator.of(sheetContext).pop();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PatternChip(
                  // 고르는 건 '어느 하루를 더 쉬는지'라 요일을 크게 보이고
                  // 그 결과 생기는 연휴를 아래에 덧붙인다
                  label: '금요일',
                  caption: '금·토·일 연휴',
                  selected: selected == WeekendPattern.friSatSun,
                  onTap: () =>
                      setSheetState(() => selected = WeekendPattern.friSatSun),
                ),
                const SizedBox(width: 16),
                _PatternChip(
                  label: '월요일',
                  caption: '토·일·월 연휴',
                  selected: selected == WeekendPattern.satSunMon,
                  onTap: () =>
                      setSheetState(() => selected = WeekendPattern.satSunMon),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 모달: 평일 연차, 며칠 쓸까요? (2~3일 스테퍼)
  void _showLeaveStepperSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      barrierColor: AppColors.materialDimmer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        // 정책: 연차만은 최소 2일 ~ 최대 3일 (연차소모 = 총 여행일수)
        // 상한은 잔여 연차일수를 넘지 않는다
        const minDays = 2;
        final remaining =
            ref.read(homeUserProvider).value?['remainingLeaveDays'] as int? ??
            kMaxTripSpanDays + 1;
        final maxDays = remaining.clamp(minDays, kMaxTripSpanDays + 1);
        var days = (ref.read(courseWizardProvider).leaveDaysToUse ?? maxDays)
            .clamp(minDays, maxDays);
        String label(int d) => '$d일(${d - 1}박$d일)';
        return StatefulBuilder(
          builder: (context, setSheetState) => _SheetScaffold(
            title: '평일 연차, 며칠 쓸까요?',
            confirmEnabled: true,
            onConfirm: () {
              ref.read(courseWizardProvider.notifier).selectLeaveDays(days);
              Navigator.of(sheetContext).pop();
            },
            // 상한에 닿았을 때만 왜 더 못 늘리는지 알린다(늘 띄우면 잔소리가 된다).
            // 자리는 항상 차지해 문구가 오갈 때 시트 높이가 출렁이지 않게 한다.
            footer: SizedBox(
              height: 44,
              child: days >= maxDays
                  ? Row(
                      children: [
                        // 아이콘 원본이 이미 label/assistive와 같은 색이라 그대로 쓴다
                        SvgPicture.asset(
                          'assets/icons/ic_circle_exclamation.svg',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '최대 $kMaxTripSpanDays박${kMaxTripSpanDays + 1}일까지 선택할 수 있어요',
                          style: AppTypography.label2Medium.copyWith(
                            color: AppColors.labelAssistive,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: AppColors.fillNormal,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StepperButton(
                    icon: Icons.remove,
                    enabled: days > minDays,
                    onTap: () => setSheetState(() => days--),
                  ),
                  // 숫자 칸은 폭을 고정한다 — 자릿수가 바뀌어도 ±버튼이 움직이지 않는다
                  Container(
                    width: 107,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundNormal,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          offset: Offset(0, 1),
                          blurRadius: 1.5,
                        ),
                      ],
                    ),
                    child: Text(
                      label(days),
                      style: AppTypography.headline2Bold.copyWith(
                        color: AppColors.labelNeutral,
                      ),
                    ),
                  ),
                  _StepperButton(
                    icon: Icons.add,
                    enabled: days < maxDays,
                    onTap: () => setSheetState(() => days++),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 스테퍼의 증감 버튼 — 한계에 닿으면 흐려진다
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.labelNeutral : AppColors.labelDisable,
        ),
      ),
    );
  }
}

/// 바텀시트 공통 레이아웃 (타이틀 + 내용 + 완료 버튼)
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.child,
    required this.confirmEnabled,
    required this.onConfirm,
    this.subtitle,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final bool confirmEnabled;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 31, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.heading2Bold.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.body2ReadingMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
            ],
            const SizedBox(height: 20),
            child,
            // 경고 영역(높이 44)이 있으면 그 자체가 여백이 되므로 덧대지 않는다
            footer ?? const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: confirmEnabled ? onConfirm : null,
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
                child: Text('완료', style: AppTypography.body1NormalBold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 기간 스타일 선택지 카드.
///
/// 고르면 배경 대신 Primary 테두리를 두르고 글자·아이콘까지 Primary로 바뀐다.
class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.primaryNormal
        : AppColors.labelNormal;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 78,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          // 선택되면 채움을 걷어내고 테두리로만 표시한다
          color: selected ? null : AppColors.fillNormal,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: AppColors.primaryNormal)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundNormal,
                borderRadius: BorderRadius.circular(15.556),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                iconAsset,
                width: 24,
                height: 24,
                // 아이콘마다 원본 색이 달라(타이머는 선택 상태로 뽑혀 있다) 여기서 통일한다.
                // 미선택 색은 반투명 토큰이 아니라 불투명한 같은 색조를 쓴다 —
                // 시계·커피는 SVG 안에 이미 61% 레이어가 있어 반투명끼리 곱해지면
                // 형체가 흐려진다.
                colorFilter: ColorFilter.mode(
                  selected
                      ? AppColors.primaryNormal
                      : AppPalette.coolNeutral25,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.headline2Bold.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.caption1Medium.copyWith(
                      color: selected
                          ? AppColors.primaryNormal
                          : AppColors.labelAlternative,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 요일 선택 칩 — 고른 요일과 그때 생기는 연휴를 함께 보여준다
class _PatternChip extends StatelessWidget {
  const _PatternChip({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.primaryNormal
        : AppColors.labelNormal;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          // 카드와 같은 규칙: 고르면 채움 대신 테두리
          color: selected ? null : AppColors.fillNormal,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: AppColors.primaryNormal)
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTypography.headline2Bold.copyWith(color: foreground),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: AppTypography.caption1Medium.copyWith(
                color: selected
                    ? AppColors.primaryNormal
                    : AppColors.labelAlternative,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
