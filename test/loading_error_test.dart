import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/widgets/app_circular_loading.dart';
import 'package:offway/core/widgets/app_error_view.dart';

void main() {
  testWidgets('짧은 로딩은 DS 규격(28px) 원형 스피너다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppCircularLoadingView())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getSize(find.byType(AppCircularLoading)), const Size(28, 28));
  });

  testWidgets('에러 화면은 다시 시도와 홈으로 가기를 함께 준다', (tester) async {
    var retried = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(body: AppErrorView(onRetry: () => retried = true)),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('오류가 발생했어요'), findsOneWidget);
    expect(find.text('잠시 후 다시 시도해 주세요'), findsOneWidget);
    expect(find.text('홈으로 가기'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
  });

  testWidgets('재시도할 길이 없으면 다시 시도 버튼을 숨긴다', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: AppErrorView()),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('다시 시도'), findsNothing);
    expect(find.text('홈으로 가기'), findsOneWidget);
  });
}
