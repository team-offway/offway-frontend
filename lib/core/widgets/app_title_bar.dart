import 'package:flutter/material.dart';

import '../theme/tokens/tokens.dart';
import 'app_back_button.dart';

/// 화면 상단바 — 가운데 제목과 왼쪽 뒤로가기. 높이 44.
///
/// 여러 화면이 `SizedBox(44)` + `Stack` + `Center(Text)` + `Positioned
/// (AppBackButton)` 를 각자 조립하던 것을 모았다(#369). 시트용은
/// `AppSheetTitleBar` 다.
///
/// 오른쪽 버튼은 [trailing]에 `Positioned` 로 넣는다 — 화면마다 자리와
/// 크기가 달라 여기서 정하지 않는다.
class AppTitleBar extends StatelessWidget {
  const AppTitleBar({
    super.key,
    required this.title,
    required this.onBack,
    this.backLeft = 6,
    this.trailing = const [],
  });

  final String title;
  final VoidCallback onBack;

  /// 뒤로가기 버튼의 왼쪽 자리. 버튼이 아이콘보다 넓어 6만큼만 띄운다 —
  /// 목록 여백 안쪽에 놓이는 화면은 음수로 당긴다
  final double backLeft;

  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        // 없으면 Stack이 제목 크기로 줄어 Positioned가 화면 기준이 아니게 된다
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              title,
              style: AppTypography.headline2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
          ),
          Positioned(
            left: backLeft,
            child: AppBackButton(onTap: onBack),
          ),
          ...trailing,
        ],
      ),
    );
  }
}
