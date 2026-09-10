import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/app_back_button.dart';
import 'package:offway/features/course_wizard/presentation/date_gate_screen.dart';
import 'package:offway/features/course_wizard/presentation/density_screen.dart';
import 'package:offway/features/course_wizard/presentation/transport_screen.dart';

/// 코스 위저드의 뒤로가기 — 시안은 상단바 콘텐츠를 왼쪽에서 16에 세운다.
/// 아이콘(12)을 누르는 범위(44) 가운데 두면 그만큼 안으로 밀린다.
void main() {
  Future<void> expectAt16(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.pumpAndSettle();

    final icon = tester.getRect(find.byType(SvgPicture).first);
    expect(icon.left, closeTo(16, 0.5));
    expect(icon.width, 12);
  }

  testWidgets('날짜 갈림길', (tester) async {
    await expectAt16(tester, const DateGateScreen());
  });

  testWidgets('이동수단 — 같은 흐름이라 자리가 같아야 한다', (tester) async {
    await expectAt16(tester, const TransportScreen());
  });

  testWidgets('일정밀도 — 같은 흐름이라 자리가 같아야 한다', (tester) async {
    await expectAt16(tester, const DensityScreen());
  });

  testWidgets('누르는 범위는 44 그대로다 — 손가락이 빗나가지 않게', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: AppBackButton(onTap: () {}, alignLeft: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(AppBackButton)), const Size(44, 44));
  });
}
