import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/course_wizard/presentation/widgets/wizard_option_button.dart';

/// 위저드 선택 버튼 — 날짜 갈림길·이동수단·일정밀도가 함께 쓴다.
///
/// **세 화면의 시안이 같다**(1438:48908 · DS 17686:52746 · DS 17742:62938).
/// 예전에는 화면마다 private 위젯을 따로 두어 값이 갈렸다 — 한쪽만 고치면
/// 다른 쪽이 조용히 어긋났다.
void main() {
  Future<void> pump(WidgetTester tester, {required bool selected}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        // 실제 화면처럼 Column 에 담는다 — Center 에 그냥 두면 Container 의
        // alignment 가 부모 높이를 다 먹어(600) 시안 높이를 잴 수 없다
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WizardOptionButton(
                label: '가고싶은 날짜가 있어요',
                selected: selected,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Container box(WidgetTester tester) => tester.widget<Container>(
    find
        .ancestor(
          of: find.text('가고싶은 날짜가 있어요'),
          matching: find.byType(Container),
        )
        .first,
  );

  testWidgets('시안 크기 — 폭 200, 높이 48', (tester) async {
    await pump(tester, selected: false);

    // 바깥 GestureDetector 는 부모 높이를 다 먹는다 — 상자를 잰다
    final rect = tester.getRect(
      find.descendant(
        of: find.byType(WizardOptionButton),
        matching: find.byType(Container),
      ),
    );
    expect(rect.width, 200);
    // 글자 한 줄 + 세로 12씩이면 46이라, minHeight 가 없으면 시안보다 납작하다
    expect(rect.height, 48);
  });

  testWidgets('미선택 — 채움 배경에 Label/Neutral 글자', (tester) async {
    await pump(tester, selected: false);

    final d = box(tester).decoration! as BoxDecoration;
    expect(d.color, AppColors.fillNormal);
    expect(d.border, isNull, reason: '미선택에는 테두리가 없다');

    final text = tester.widget<Text>(find.text('가고싶은 날짜가 있어요'));
    // labelNormal(불투명)로 두면 시안보다 진하다
    expect(text.style?.color, AppColors.labelNeutral);
    expect(text.style?.fontWeight, AppTypography.body1NormalMedium.fontWeight);
  });

  testWidgets('선택 — 배경을 비우고 Primary 테두리 1.0', (tester) async {
    await pump(tester, selected: true);

    final d = box(tester).decoration! as BoxDecoration;
    expect(d.color, isNull, reason: '고른 것은 배경을 비운다');
    final side = (d.border! as Border).top;
    expect(side.color, AppColors.primaryNormal);
    // 1.5 로 두면 날짜 갈림길만 테두리가 두꺼웠다
    expect(side.width, 1.0);

    final text = tester.widget<Text>(find.text('가고싶은 날짜가 있어요'));
    expect(text.style?.color, AppColors.primaryNormal);
    expect(text.style?.fontWeight, AppTypography.body1NormalBold.fontWeight);
  });
}
