import 'package:flutter/material.dart';

import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

/// 여행 D-day 위젯을 붙이는 법 — 마이 메뉴에서 연다(#297).
///
/// **위젯은 앱이 대신 붙여 줄 수 없다.** iOS 에 그런 API 가 없어 사용자가
/// 직접 넣어야 하고, 어디서 넣는지 모르면 기능이 있는 줄도 모른다.
/// 그래서 자리 둘(잠금화면·홈)의 순서를 그대로 적어 둔다.
///
/// 시안이 없어 텍스트로 먼저 둔다 — 디자인이 나오면 여기만 갈아 끼운다.
Future<void> showWidgetGuideSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    // 안내가 길다 — 작은 화면에서는 시트 안에서 스크롤한다
    maxHeightRatio: 0.9,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // 제목 바가 시트 전체 폭을 차지해야 닫기 버튼이 오른쪽 끝에 붙는다 —
        // 다른 시트와 같은 배치
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetTitleBar(title: '여행 D-day 위젯'),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: _GuideBody(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GuideBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '다음 여행까지 남은 날을 잠금화면과 홈 화면에서 바로 볼 수 있어요. '
          '앱을 열지 않아도 날짜가 매일 바뀌어요.',
          style: AppTypography.label1NormalMedium.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
        const SizedBox(height: 24),
        const _Steps(
          title: '잠금화면에 넣기',
          steps: [
            '잠금화면을 길게 눌러요',
            '‘사용자화’ → ‘잠금 화면’을 눌러요',
            '시계 아래 칸을 누르고 Offway를 골라요',
          ],
        ),
        const SizedBox(height: 20),
        const _Steps(
          title: '홈 화면에 넣기',
          steps: [
            '홈 화면의 빈 곳을 길게 눌러요',
            '왼쪽 위 ‘+’(편집)를 눌러요',
            'Offway를 찾아 ‘여행 D-day’를 추가해요',
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'iOS 16 이상에서 쓸 수 있어요.',
          style: AppTypography.caption1Medium.copyWith(
            color: AppColors.labelAssistive,
          ),
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.headline2Bold.copyWith(
            color: AppColors.labelNormal,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}.',
                    style: AppTypography.label1NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    steps[i],
                    style: AppTypography.label1NormalMedium.copyWith(
                      color: AppColors.labelNeutral,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
