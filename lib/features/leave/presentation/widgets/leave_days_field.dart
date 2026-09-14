import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 연차 일수를 받는 입력 칸 — 총 연차 수정과 사용 등록이 함께 쓴다.
///
/// **숫자 폭만큼만 [TextField]를 두고 단위(`일`)는 그 옆에 붙인다.** 그래서
/// 빈 자리를 눌러도 입력에 닿지 않으므로, 칸 전체를 탭 영역으로 잡아
/// 어디를 눌러도 수정으로 들어가게 한다 — 이 칸의 핵심이다.
///
/// 예전에는 두 화면이 이 골격을 각자 들고 있었다(137줄·128줄). 주석이
/// 서로를 가리키며 "같은 방식이다"라고 적혀 있었는데, 한쪽 탭 영역이나
/// 오류 표시를 고치고 다른 쪽을 빠뜨리면 사용자가 바로 겪는 자리였다.
///
/// 화면마다 갈리는 것은 인자로 뺀다 — 위젯이 두 화면의 사정을 다 알지
/// 않게 한다. 특히 [message]는 호출부가 만들어 넘긴다.
class LeaveDaysField extends StatelessWidget {
  const LeaveDaysField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.trailing,
    required this.onChanged,
    this.title,
    this.hint,
    this.message,
    this.messageIsError = false,
    this.unitWhenEmpty = false,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// 테두리를 오류 색으로 세울지 — 문구는 [message]가 따로 맡는다
  final bool hasError;

  /// 칸 오른쪽 아이콘. 두 화면이 **다른 물건**을 쓴다 —
  /// 총 연차는 유효성(`_ValidityIcon`), 사용 등록은 편집 상태
  /// (`_EditStateIcon`)다. 합칠 수 없어 주입받는다
  final Widget trailing;

  final ValueChanged<String> onChanged;

  /// 칸 위 제목. null이면 바깥에서 그린다(사용 등록이 그렇다)
  final String? title;

  /// 빈 값 위에 옅게 깔 글자 — 지금 값이 무엇인지 알려 준다
  final String? hint;

  /// 칸 아래 한 줄. 오류든 안내든 **호출부가 정해 넘긴다**
  final String? message;

  /// [message]를 오류 색으로 그릴지
  final bool messageIsError;

  /// 빈 칸에도 단위(`일`)를 띄울지.
  ///
  /// 총 연차는 띄우지 않는다 — 빈 칸에 '일'만 있으면 무엇을 넣으라는
  /// 것인지 흐려진다. 사용 등록은 자동 계산값이 먼저 차 있어 늘 띄운다
  final bool unitWhenEmpty;

  /// 숫자와 소수점만 받을지 — 단위를 적어 넣는 사람이 있다
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    final empty = controller.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title case final title?) ...[
          Text(
            title,
            style: AppTypography.label1NormalMedium.copyWith(
              color: AppColors.labelNeutral,
            ),
          ),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: focusNode.requestFocus,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundNormal,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? AppColors.statusNegative
                    : focused
                    ? AppColors.primaryNormal
                    : AppColors.lineNormalNeutral,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 숫자만 편집한다 — 단위까지 지워지지 않도록
                        Flexible(
                          child: IntrinsicWidth(
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: onChanged,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: digitsOnly
                                  ? [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      ),
                                    ]
                                  : null,
                              style: AppTypography.body1NormalRegular.copyWith(
                                color: AppColors.labelNormal,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                // **빈 칸일 때만 넘긴다.** IntrinsicWidth가
                                // 고유 폭을 잴 때 힌트까지 재는 탓에, 값이
                                // 있어도 힌트를 걸어 두면 칸이 '23일' 폭으로
                                // 남아 숫자와 '일' 사이가 벌어진다
                                hintText: empty ? hint : null,
                                hintStyle: AppTypography.body1NormalRegular
                                    .copyWith(color: AppColors.labelAssistive),
                              ),
                            ),
                          ),
                        ),
                        // 단위는 화면에만 붙는다 (값에는 들어가지 않는다)
                        if (!empty || unitWhenEmpty)
                          Text(
                            '일',
                            style: AppTypography.body1NormalRegular.copyWith(
                              color: AppColors.labelNormal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
        if (message case final message?) ...[
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.caption1Regular.copyWith(
              color: messageIsError
                  ? AppColors.statusNegative
                  : AppColors.labelAlternative,
            ),
          ),
        ],
      ],
    );
  }
}
