import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'wizard_option_button.dart';

/// 상단바(44) 아래 아이콘까지의 여백 — 위저드 다섯 화면이 같은 자리에 선다.
///
/// 시안 좌표로 날짜갈림길 165 · 출발지 166 인데, 그 1 은 시안 제작상의
/// 오차다. 단계를 넘길 때 아이콘이 들썩이지 않게 한 값으로 맞춘다
const double kWizardTopGap = 67;

/// 위저드 공통 선택 스텝 레이아웃 (STEP0/이동수단/일정밀도가 공유하는 패턴)
/// 상단 뒤로가기+스텝, 아이콘, 질문, 선택 버튼들, 하단 다음 CTA.
class WizardChoiceStep extends StatelessWidget {
  const WizardChoiceStep({
    super.key,
    required this.stepLabel,
    required this.iconAsset,
    required this.title,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
    required this.onNext,
    this.subtitle,
  });

  final String stepLabel;

  /// 질문 위에 놓일 48×48 아이콘 (스텝마다 다르다)
  final String iconAsset;

  final String title;
  final String? subtitle;
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  /// null이면 다음 버튼 비활성
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        // 액션 영역은 스크롤 밖에 두어 화면이 작아도 항상 닿는다
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: kWizardTopGap),
                    SvgPicture.asset(iconAsset, width: 48, height: 48),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.title3Bold.copyWith(
                        color: AppColors.labelNormal,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: AppTypography.body1NormalMedium.copyWith(
                          color: AppColors.labelAlternative,
                        ),
                      ),
                    ],
                    const SizedBox(height: 55),
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      WizardOptionButton(
                        label: options[i],
                        selected: selectedIndex == i,
                        onTap: () => onSelect(i),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onNext,
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

  /// 뒤로가기 + 단계 표시. 단계는 오른쪽에 옅게 둔다.
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      // 버튼이 아이콘보다 넓으므로 좌측 여백을 줄여 아이콘 위치를 맞춘다
      padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
      child: Row(
        children: [
          AppBackButton(onTap: () => context.pop()),
          const Spacer(),
          Text(
            stepLabel,
            style: AppTypography.body1NormalBold.copyWith(
              color: AppColors.labelAssistive,
            ),
          ),
        ],
      ),
    );
  }
}
