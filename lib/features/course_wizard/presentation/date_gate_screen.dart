import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../application/course_wizard_provider.dart';

/// O-04-0 · 날짜 갈림길 (STEP 0, 와이어프레임)
/// "가고싶은 날짜가 있어요" → 캘린더 / "아직 안 정했어요" → 기간스타일
class DateGateScreen extends ConsumerWidget {
  const DateGateScreen({super.key});

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _stepText = Color(0xFF545A66);
  static const _optionFill = Color(0x0D07194C); // rgba(7,25,76,0.05)
  static const _optionText = Color(0xB3031228); // rgba(3,18,40,0.7)
  static const _imagePlaceholder = Color(0xFFF2F3F6);
  static const _ctaDisabled = Color(0xFFC5C8CE);
  static const _ctaEnabled = Color(0xFF191B1F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(
      courseWizardProvider.select((draft) => draft.datePath),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            const SizedBox(height: 22),
            Container(width: 79, height: 79, color: _imagePlaceholder),
            const SizedBox(height: 24),
            const Text(
              '여행 날짜가 있나요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _labelNormal,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '날짜를 직접 선택하거나,\n추천부터 받아볼 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _textTertiary,
                letterSpacing: -0.6,
                height: 26 / 18,
              ),
            ),
            const SizedBox(height: 40),
            _OptionButton(
              label: '가고싶은 날짜가 있어요',
              selected: choice == DatePathChoice.haveDates,
              onTap: () => ref
                  .read(courseWizardProvider.notifier)
                  .selectDatePath(DatePathChoice.haveDates),
            ),
            const SizedBox(height: 15),
            _OptionButton(
              label: '아직 안 정했어요',
              selected: choice == DatePathChoice.undecided,
              onTap: () => ref
                  .read(courseWizardProvider.notifier)
                  .selectDatePath(DatePathChoice.undecided),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: choice == null
                      ? null
                      : () {
                          if (choice == DatePathChoice.haveDates) {
                            context.push(AppRoutes.wizardCalendar);
                          } else {
                            context.push(AppRoutes.wizardPeriodStyle);
                          }
                        },
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
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            '1/4',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _stepText,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
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
        width: 307,
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DateGateScreen._optionFill,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: DateGateScreen._ctaEnabled, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: DateGateScreen._optionText,
          ),
        ),
      ),
    );
  }
}
