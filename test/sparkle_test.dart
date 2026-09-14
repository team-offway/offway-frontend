import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/leave/presentation/widgets/sparkle.dart';

/// 타이머 둘레의 반짝임 — 내 연차·총 연차 화면이 함께 쓴다.
///
/// 예전에는 두 화면이 같은 위젯을 각자 들고 있었고, 생성자 형태마저 달랐다
/// (positional / named). 한쪽만 고치면 다른 쪽이 조용히 어긋나던 자리다.
void main() {
  Future<void> pump(WidgetTester tester, {Color? tone}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(child: Sparkle(size: 9, tone: tone)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tone 이 없으면 에셋 원본색을 그대로 쓴다', (tester) async {
    await pump(tester);

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, 9);
    expect(svg.height, 9);
    // 원본이 Light Blue 60 이라 덮을 이유가 없다
    expect(svg.colorFilter, isNull);
  });

  testWidgets('tone 을 주면 그 색으로 덮는다 — 하나만 한 단 옅게 쓴다', (tester) async {
    await pump(tester, tone: AppPalette.lightBlue70);

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      svg.colorFilter,
      const ColorFilter.mode(AppPalette.lightBlue70, BlendMode.srcIn),
    );
  });

  testWidgets('장식이라 스크린리더가 읽지 않는다', (tester) async {
    await pump(tester);

    // 화면 전체로 재면 Scaffold·MaterialApp 껍데기가 걸린다 — 이 위젯이
    // 스스로 시맨틱스를 만들지 않는지만 본다
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.semanticsLabel, isNull, reason: '반짝임에는 읽을 것이 없다');
    expect(
      find.descendant(
        of: find.byType(Sparkle),
        matching: find.byType(Semantics),
      ),
      findsNothing,
      reason: 'excludeFromSemantics 가 빠지면 이 자리에 Semantics 가 생긴다',
    );
  });
}
