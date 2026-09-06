import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_icon_button.dart';

/// 업데이트 모달의 답
enum UpdatePromptAnswer { update, later }

/// 업데이트 알림 시트 (시안 18932:73769) — 닫기 · 아이콘 · 제목 · 문구 · 버튼 둘.
///
/// 닫기(X)나 바깥을 누르면 null — '나중에'와 같이 다룬다.
Future<UpdatePromptAnswer?> showUpdatePromptSheet(BuildContext context) {
  return showAppBottomSheet<UpdatePromptAnswer>(
    context,
    // 기본 시트 상한(화면의 9/16)에 걸리면 '나중에'가 아래로 밀려 잘린다 —
    // 내용 높이만큼 열리게 상한을 넉넉히 준다
    maxHeightRatio: 0.9,
    builder: (sheetContext) => _UpdatePromptSheet(
      onAnswer: (answer) => Navigator.of(sheetContext).pop(answer),
    ),
  );
}

class _UpdatePromptSheet extends StatelessWidget {
  const _UpdatePromptSheet({required this.onAnswer});

  final void Function(UpdatePromptAnswer?) onAnswer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 위쪽 안전영역은 안 더한다 — 시트는 아래에 붙어 있는데 상태바 높이가
      // 위 여백에 얹히면 시안(24)보다 훌쩍 커진다
      top: false,
      // 시안 실측: 위 24 · 닫기 줄 22 · 그림 61(반짝임이 닫기 줄 바로 아래서
      // 시작하고 아이콘은 그 19 아래) · 16 · 제목 · 8 · 문구 · 8 ·
      // 액션 영역(위 20 · 버튼 48 · 8 · 나중에 44) · 홈 인디케이터 34 = 359
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 22,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: AppIconButton.close(
                    size: 22,
                    onTap: () => onAnswer(null),
                  ),
                ),
              ),
            ),
            const Center(child: _Illustration()),
            const SizedBox(height: 16),
            Text(
              '업데이트 알림',
              textAlign: TextAlign.center,
              style: AppTypography.headline1Bold.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '새로 추가된 기능을\n앱 업데이트를 통해 바로 만나보세요.',
              textAlign: TextAlign.center,
              style: AppTypography.label1NormalMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => onAnswer(UpdatePromptAnswer.update),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryNormal,
                      foregroundColor: AppColors.staticWhite,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('업데이트', style: AppTypography.body1NormalBold),
                  ),
                  const SizedBox(height: 8),
                  // DS Button/Text — 낮은 위계. 시안 실측 위아래 8 + 4
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: () => onAnswer(UpdatePromptAnswer.later),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '나중에',
                          textAlign: TextAlign.center,
                          style: AppTypography.label1NormalBold.copyWith(
                            color: AppColors.labelAlternative,
                          ),
                        ),
                      ),
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

/// 말풍선 아이콘(vuesax bulk message-notif, 42)과 반짝임 셋.
///
/// 시안 좌표(모달 기준 아이콘 180,65 · 반짝임 236,74 / 172,46 / 157,97)를
/// 100×61 상자로 옮겼다 — 상자 위가 닫기 줄 바로 아래(46)라 아이콘은 19 아래,
/// 반짝임은 오른쪽 12 · 왼쪽 위 8 · 왼쪽 아래 6
class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 61,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 29,
            top: 19,
            child: SvgPicture.asset(
              'assets/icons/ic_message_notif_bulk.svg',
              width: 42,
              height: 42,
              excludeFromSemantics: true,
            ),
          ),
          const _Sparkle(left: 85.4, top: 27.8, size: 12.2),
          const _Sparkle(left: 21.1, top: 0, size: 7.9),
          const _Sparkle(left: 5.5, top: 51.1, size: 6.4),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.left, required this.top, required this.size});

  final double left;
  final double top;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: SvgPicture.asset(
        'assets/icons/ic_star_four.svg',
        width: size,
        height: size,
        excludeFromSemantics: true,
        colorFilter: const ColorFilter.mode(
          AppColors.primaryNormal,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
