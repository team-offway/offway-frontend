import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/app_toast.dart';

/// 여행 기록 토스트가 시안대로 두 줄 + 액션을 그리는지 고정한다.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppToast(
                context,
                '정선 여행을 기록했어요.',
                detail: detail,
                actionLabel: actionLabel,
                onAction: onAction,
                kind: AppToastKind.success,
              ),
              child: const Text('띄우기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('띄우기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('둘째 줄과 액션을 함께 보여준다', (tester) async {
    await pump(
      tester,
      detail: '연차 3일을 사용해 10일 남았어요.',
      actionLabel: '보러가기',
      onAction: () {},
    );

    expect(find.text('정선 여행을 기록했어요.'), findsOneWidget);
    expect(find.text('연차 3일을 사용해 10일 남았어요.'), findsOneWidget);
    expect(find.text('보러가기'), findsOneWidget);
  });

  testWidgets('액션을 누르면 콜백이 온다', (tester) async {
    var tapped = false;
    await pump(
      tester,
      detail: '연차 3일을 사용해 10일 남았어요.',
      actionLabel: '보러가기',
      onAction: () => tapped = true,
    );

    await tester.tap(find.text('보러가기'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('액션을 누르면 토스트가 먼저 닫힌다', (tester) async {
    // 눌러서 다른 화면으로 가는데 토스트가 따라다니면 안 된다
    await pump(
      tester,
      detail: '연차 3일을 사용해 10일 남았어요.',
      actionLabel: '보러가기',
      onAction: () {},
    );

    await tester.tap(find.text('보러가기'));
    await tester.pumpAndSettle();

    expect(find.text('정선 여행을 기록했어요.'), findsNothing);
  });

  testWidgets('둘째 줄이 없으면 한 줄로 남는다', (tester) async {
    // 기존 호출부(한 줄 토스트)가 그대로 동작해야 한다
    await pump(tester);

    expect(find.text('정선 여행을 기록했어요.'), findsOneWidget);
    expect(find.text('보러가기'), findsNothing);
  });

  testWidgets('라벨만 주고 콜백이 없으면 버튼을 그리지 않는다', (tester) async {
    // 눌러도 아무 일 없는 버튼은 없느니만 못하다
    await pump(tester, detail: '연차 3일을 사용했어요.', actionLabel: '보러가기');

    expect(find.text('보러가기'), findsNothing);
  });
}
