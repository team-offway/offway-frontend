import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 하단 플로팅 탭이 가리키는 최상위 목적지
enum AppTab {
  home('홈', 'assets/icons/tab_home.svg'),
  myCourse('내 코스', 'assets/icons/tab_course.svg'),
  my('마이', 'assets/icons/tab_my.svg');

  const AppTab(this.label, this.iconAsset);

  final String label;
  final String iconAsset;
}

/// 홈·지역 상세 등에서 공유하는 하단 플로팅 탭.
/// [current]가 null이면 어느 탭도 활성으로 보이지 않는다(하위 화면).
// TODO(디자인시스템): 공통 컴포넌트 확정 시 이 위젯을 대체/이관
class AppTabPills extends StatelessWidget {
  const AppTabPills({super.key, this.current = AppTab.home, this.onTap});

  final AppTab? current;
  final ValueChanged<AppTab>? onTap;

  static const _inactive = Color(0xFF6F767E);
  static const _active = Color(0xFF2D3037);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xCCFFFFFF),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tab in AppTab.values) ...[
                    if (tab != AppTab.values.first) const SizedBox(width: 8),
                    _Pill(
                      tab: tab,
                      active: tab == current,
                      onTap: onTap == null ? null : () => onTap!(tab),
                    ),
                  ],
                ],
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
    final color = active ? AppTabPills._active : AppTabPills._inactive;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        height: double.infinity,
        decoration: BoxDecoration(
          color: active ? const Color(0x14000000) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              tab.iconAsset,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
