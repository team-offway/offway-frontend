import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/leave/presentation/total_leave_screen.dart';

/// 총 연차 입력의 상한은 **이미 쓴 만큼 줄어든다**.
///
/// 화면은 잔여 연차를 받지만 서버가 받는 것은 총 연차(잔여 + 사용분)다.
/// 그 합이 서버 상한(99)을 넘으면 저장이 거절되는데, 입력값만 재면
/// 눌러 본 뒤에야 '수정하지 못했어요'를 만난다.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double used,
    required String input,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: 50,
              usedDays: used,
              remainingDays: 50 - used,
              usages: const [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TotalLeaveScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('총 연차일수 수정하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, input);
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed !=
      null;

  testWidgets('쓴 만큼 상한이 줄고, 이유를 말한다', (tester) async {
    // 사용 35일 + 입력 65 = 100 > 99 라 서버가 거절하던 자리
    await pump(tester, used: 35, input: '65');

    expect(find.text('이미 35일을 써서 64일까지 넣을 수 있어요.'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('경계값은 통과한다', (tester) async {
    // 35 + 64 = 99 — 상한과 같은 값은 서버도 받는다
    await pump(tester, used: 35, input: '64');

    expect(find.textContaining('넣을 수 있어요'), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('쓴 적이 없으면 99일까지 그대로다', (tester) async {
    await pump(tester, used: 0, input: '99');

    expect(find.textContaining('넣을 수 있어요'), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('쓴 적이 없을 때 100은 막고, 쓴 일수를 들먹이지 않는다', (tester) async {
    await pump(tester, used: 0, input: '100');

    expect(find.text('99일까지 넣을 수 있어요.'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });
}
