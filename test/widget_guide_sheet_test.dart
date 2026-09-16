import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/my/presentation/my_screen.dart';

/// 위젯은 사용자가 직접 붙여야 한다 — 마이에서 어디서 넣는지 알려준다(#297).
void main() {
  Widget wrap() => ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) async => {'nickname': '영찬'}),
    ],
    child: const MaterialApp(home: MyScreen()),
  );

  testWidgets('마이 메뉴에서 위젯 넣는 법을 연다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('여행 D-day 위젯'));
    await tester.pumpAndSettle();

    // 잠금화면·홈 두 자리를 다 알려준다
    expect(find.text('잠금화면에 넣기'), findsOneWidget);
    expect(find.text('홈 화면에 넣기'), findsOneWidget);
    expect(find.textContaining('Offway를 골라요'), findsOneWidget);
  });
}
