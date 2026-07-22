import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 위저드 공통 선택 스텝 레이아웃 (STEP0/이동수단/일정밀도가 공유하는 패턴)
/// 상단 뒤로가기+스텝, 일러스트 자리, 질문, 선택 버튼들, 하단 다음 CTA.
// TODO(디자인시스템): 공통 컴포넌트 확정 시 이 위젯을 대체/이관
class WizardChoiceStep extends StatelessWidget {
  const WizardChoiceStep({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
    required this.onNext,
    this.subtitle,
  });

  final String stepLabel;
  final String title;
  final String? subtitle;
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  /// null이면 다음 버튼 비활성
  final VoidCallback? onNext;

  static const _labelNormal = Color(0xFF171719);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _stepText = Color(0xFF545A66);
  static const _optionFill = Color(0x0D07194C);
  static const _optionText = Color(0xB3031228);
  static const _imagePlaceholder = Color(0xFFF2F3F6);
  static const _ctaDisabled = Color(0xFFC5C8CE);
  static const _ctaEnabled = Color(0xFF191B1F);

  @override
  Widget build(BuildContext context) {
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
                          Text(
                            stepLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: _stepText,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(width: 79, height: 79, color: _imagePlaceholder),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _labelNormal,
                        letterSpacing: -0.6,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: _textTertiary,
                          letterSpacing: -0.6,
                          height: 26 / 18,
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(height: 15),
                      GestureDetector(
                        onTap: () => onSelect(i),
                        child: Container(
                          width: 307,
                          constraints: const BoxConstraints(minHeight: 56),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _optionFill,
                            borderRadius: BorderRadius.circular(16),
                            border: selectedIndex == i
                                ? Border.all(color: _ctaEnabled, width: 1.5)
                                : null,
                          ),
                          child: Text(
                            options[i],
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _optionText,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: onNext,
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
}
