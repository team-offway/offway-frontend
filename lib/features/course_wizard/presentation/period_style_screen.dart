import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/presentation/home_screen.dart';
import '../application/course_wizard_provider.dart';

/// O-04 · 기간스타일 (B 경로, STEP 2/4, 와이어프레임)
/// 주말 포함/연차만 선택 시 바텀시트로 하위 선택을 받는다.
class PeriodStyleScreen extends ConsumerWidget {
  const PeriodStyleScreen({super.key});

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _stepText = Color(0xFF545A66);
  static const _cardBg = Color(0xFFF7F7F7);
  static const _cardIcon = Color(0xFF545A66);
  static const _cardSub = Color(0xFF6F6F6F);
  static const _leaveText = Color(0x9400132B); // rgba(0,19,43,0.58)
  static const _imagePlaceholder = Color(0xFFF2F3F6);
  static const _chipBg = Color(0xFFF2F3F6);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _ctaDisabled = Color(0xFFC5C8CE);
  static const _ctaEnabled = Color(0xFF191B1F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(courseWizardProvider);
    final leaveDays = ref.watch(homeUserProvider).value?['remainingLeaveDays'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 22,
                              color: _stepText,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            '2/4',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: _stepText,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(width: 79, height: 79, color: _imagePlaceholder),
                    const SizedBox(height: 28),
                    const Text(
                      '어떻게 떠날까요?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _labelNormal,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 19),
                      child: Column(
                        children: [
                          _StyleCard(
                            title: '당일치기 · 반차',
                            subtitle: '짧게 다녀와요',
                            selected: draft.periodStyle == PeriodStyle.dayTrip,
                            onTap: () => ref
                                .read(courseWizardProvider.notifier)
                                .selectPeriodStyle(PeriodStyle.dayTrip),
                          ),
                          const SizedBox(height: 10),
                          _StyleCard(
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
                          const SizedBox(height: 10),
                          _StyleCard(
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
                    const Spacer(),
                    Text(
                      '남은 연차일수 ${leaveDays ?? '-'}일',
                      style: const TextStyle(fontSize: 16, color: _leaveText),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: draft.isPeriodStyleComplete
                              ? () {
                                  // TODO(wizard): 이동수단(O-05) 화면 작업 시 연결
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _ctaEnabled,
                            disabledBackgroundColor: _ctaDisabled,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '다음',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 모달: 언제 하루 더 쉴까요? (금토일 / 토일월)
  void _showWeekendPatternSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  label: '금 토 일',
                  selected: selected == WeekendPattern.friSatSun,
                  onTap: () =>
                      setSheetState(() => selected = WeekendPattern.friSatSun),
                ),
                const SizedBox(width: 16),
                _PatternChip(
                  label: '토 일 월',
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

  /// 모달: 연차를 얼마나 사용할까요? (1~3일 스테퍼)
  void _showLeaveStepperSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        var days = ref.read(courseWizardProvider).leaveDaysToUse ?? 3;
        String label(int d) => d == 1 ? '$d일(당일)' : '$d일(${d - 1}박$d일)';
        return StatefulBuilder(
          builder: (context, setSheetState) => _SheetScaffold(
            title: '연차를 얼마나 사용할까요?',
            confirmEnabled: true,
            onConfirm: () {
              ref.read(courseWizardProvider.notifier).selectLeaveDays(days);
              Navigator.of(sheetContext).pop();
            },
            footer: const Row(
              children: [
                Icon(Icons.error, size: 18, color: _labelNormal),
                SizedBox(width: 8),
                Text(
                  '최대 2박3일까지 선택할 수 있어요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _stepText,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            child: Container(
              height: 58,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0x0D07194C),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: days > 1
                        ? () => setSheetState(() => days--)
                        : null,
                    icon: Icon(
                      Icons.remove,
                      size: 18,
                      color: days > 1 ? const Color(0xFF333D4B) : _ctaDisabled,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A001B37),
                            offset: Offset(0, 1),
                            blurRadius: 1.5,
                          ),
                        ],
                      ),
                      child: Text(
                        label(days),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333D4B),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: days < kMaxTripSpanDays + 1
                        ? () => setSheetState(() => days++)
                        : null,
                    icon: Icon(
                      Icons.add,
                      size: 18,
                      color: days < kMaxTripSpanDays + 1
                          ? const Color(0xFF333D4B)
                          : _ctaDisabled,
                    ),
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

/// 바텀시트 공통 레이아웃 (일러스트 자리 + 타이틀 + 내용 + 완료 버튼)
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
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              color: PeriodStyleScreen._imagePlaceholder,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: PeriodStyleScreen._labelNormal,
                letterSpacing: -0.6,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: PeriodStyleScreen._textTertiary,
                  letterSpacing: -0.6,
                ),
              ),
            ],
            const SizedBox(height: 24),
            child,
            if (footer != null) ...[const SizedBox(height: 18), footer!],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: confirmEnabled ? onConfirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: PeriodStyleScreen._ctaEnabled,
                  disabledBackgroundColor: PeriodStyleScreen._ctaDisabled,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '완료',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 95,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 19),
        decoration: BoxDecoration(
          color: PeriodStyleScreen._cardBg,
          borderRadius: BorderRadius.circular(15),
          border: selected
              ? Border.all(color: PeriodStyleScreen._ctaEnabled, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              color: PeriodStyleScreen._cardIcon,
            ),
            const SizedBox(width: 18),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: PeriodStyleScreen._labelNormal,
                    letterSpacing: -0.6,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PeriodStyleScreen._cardSub,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternChip extends StatelessWidget {
  const _PatternChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: PeriodStyleScreen._chipBg,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: PeriodStyleScreen._ctaEnabled, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: PeriodStyleScreen._labelNormal,
            letterSpacing: -0.6,
          ),
        ),
      ),
    );
  }
}
