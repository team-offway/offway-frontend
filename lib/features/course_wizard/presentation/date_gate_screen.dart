import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';
import '../application/course_wizard_provider.dart';

/// O-04-0 · 날짜 갈림길 (STEP 0)
/// "가고싶은 날짜가 있어요" → 캘린더 / "아직 안 정했어요" → 기간스타일
class DateGateScreen extends ConsumerWidget {
  const DateGateScreen({super.key});

  // 시안이 DS 토큰 대신 지정한 보조 텍스트 색 (구 체계 값)
  // TODO(디자인시스템): 디자이너가 토큰으로 정리하면 교체
  static const _subtitleColor = Color(0xFFADB1BB);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(
      courseWizardProvider.select((draft) => draft.datePath),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            const SizedBox(height: 60),
            SvgPicture.asset(
              'assets/icons/ic_calendar_blue.svg',
              width: 48,
              height: 48,
            ),
            const SizedBox(height: 28),
            Text(
              '여행 날짜가 있나요?',
              textAlign: TextAlign.center,
              style: AppTypography.title3Bold.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '날짜를 직접 선택하거나,\n추천부터 받아볼 수 있어요.',
              textAlign: TextAlign.center,
              style: AppTypography.body1NormalMedium.copyWith(
                color: _subtitleColor,
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
            const SizedBox(height: 16),
            _OptionButton(
              label: '아직 안 정했어요',
              selected: choice == DatePathChoice.undecided,
              onTap: () => ref
                  .read(courseWizardProvider.notifier)
                  .selectDatePath(DatePathChoice.undecided),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          AppBackButton(onTap: () => context.pop()),
          const Spacer(),
          Text(
            '1/4',
            style: AppTypography.label1NormalMedium.copyWith(
              color: const Color(0xFF545A66),
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
        width: 213,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.fillNormal,
          borderRadius: BorderRadius.circular(12),
          // 시안에 선택 상태 표기가 없어 홈 카테고리 칩과 같은 규칙을 쓴다
          border: selected
              ? Border.all(color: AppColors.primaryNormal, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.body1NormalMedium.copyWith(
            color: AppColors.labelNeutral,
          ),
        ),
      ),
    );
  }
}
