import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/presentation/widgets/expandable_description.dart';

/// 정해진 폭에서 위젯을 띄운다 — 넘침 판정이 폭에 달려 있어 고정해야 한다
Future<void> pumpAt(WidgetTester tester, String text, double width) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: ExpandableDescription(text: text),
        ),
      ),
    ),
  );
}

void main() {
  const long =
      '청춘! 이는 듣기만 하여도 가슴이 설레는 말이다. 청춘! 너의 두 손을 가슴에 대고, 물방아 같은 심장의 '
      '고동을 들어 보라. 청춘의 피는 끓는다. 물방아 같은 심장의 고동을 들어 보라. 청춘! 이는 듣기만 '
      '하여도 가슴이 설레는 말이다. 너의 두 손을 가슴에 대고 들어 보라.';

  testWidgets('3줄을 넘기면 말줄임표와 펼침 아이콘이 보인다', (tester) async {
    await pumpAt(tester, long, 300);

    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, 3);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('짧은 글에는 펼침 아이콘을 그리지 않는다', (tester) async {
    await pumpAt(tester, '예술을 캐는 광산', 300);

    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
  });

  testWidgets('아이콘을 누르면 전문이 펼쳐지고 아이콘이 뒤집힌다', (tester) async {
    await pumpAt(tester, long, 300);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();

    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, isNull); // 줄 수 제한이 풀린다
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

    // 다시 누르면 접힌다
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pump();
    expect(tester.widget<Text>(find.text(long)).maxLines, 3);
  });
}
