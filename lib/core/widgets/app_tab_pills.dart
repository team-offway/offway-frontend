import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 하단 플로팅 탭이 가리키는 최상위 목적지
enum AppTab {
  home('홈', 'assets/icons/tab_home_v2.svg'),
  myCourse('내 코스', 'assets/icons/tab_course_v2.svg'),
  my('마이', 'assets/icons/tab_my_v2.svg');

  const AppTab(this.label, this.iconAsset);

  final String label;
  final String iconAsset;
}

/// 홈·지역 상세 등에서 공유하는 하단 플로팅 탭.
/// [current]가 null이면 어느 탭도 활성으로 보이지 않는다(하위 화면).
class AppTabPills extends StatelessWidget {
  const AppTabPills({super.key, this.current = AppTab.home, this.onTap});

  final AppTab? current;
  final ValueChanged<AppTab>? onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 리퀴드 글래스 — 팀 웹(18th-team3-client `liquid-glass`)과 값을 맞춘다.
            //
            // 유리로 보이게 하는 것은 블러가 아니라 **테두리 안쪽 광택**이다.
            // 그것 없이 블러만 세게 주면 뒤가 뭉개진 반투명 판이 될 뿐이다.
            // 그래서 블러는 오히려 옅게(3) 두어 뒤가 비치게 한다.
            //
            // 바깥 그림자는 클립 밖에 둔다 — 안에 두면 함께 잘려 사라진다
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x29000000), // 16%
                    offset: Offset(0, 6),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.staticWhite.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        // 좌상단 하이라이트 · 우하단 반사 (web의 inset 2겹)
                        BoxShadow(
                          color: AppColors.staticWhite.withValues(alpha: 0.6),
                          offset: const Offset(2, 2),
                          blurRadius: 1,
                          blurStyle: BlurStyle.inner,
                        ),
                        BoxShadow(
                          color: AppColors.staticWhite.withValues(alpha: 0.4),
                          offset: const Offset(-1, -1),
                          blurRadius: 1,
                          spreadRadius: 1,
                          blurStyle: BlurStyle.inner,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final tab in AppTab.values) ...[
                          if (tab != AppTab.values.first)
                            const SizedBox(width: 6),
                          _Pill(
                            tab: tab,
                            active: tab == current,
                            onTap: onTap == null ? null : () => onTap!(tab),
                          ),
                        ],
                      ],
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
}

class _Pill extends StatelessWidget {
  const _Pill({required this.tab, required this.active, this.onTap});

  final AppTab tab;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.labelStrong : AppColors.labelAlternative;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        height: double.infinity,
        decoration: BoxDecoration(
          // 팀 웹과 같은 검정 8%. 회색(Cool Neutral) 8%는 흰 틴트 위에서
          // 명도차가 11밖에 안 나 활성 탭이 눈에 띄지 않았다 — 검정은 20이다
          color: active
              ? AppColors.staticBlack.withValues(alpha: AppOpacity.o8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              tab.iconAsset,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: AppTypography.caption2Medium.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
