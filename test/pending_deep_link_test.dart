import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/router/pending_deep_link.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/splash/presentation/splash_screen.dart';

/// 앱이 꺼진 채 위젯·공유 링크로 열렸을 때 — 스플래시가 끝난 **뒤에** 그 화면으로.
///
/// 스플래시 위에 먼저 올리면 1.2초 뒤 스플래시가 go(next) 로 스택을 갈아 치우며
/// 지운다 — 위젯을 눌렀는데 홈에 떨어진다.
void main() {
  GoRouter router() => GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(next: AppRoutes.home),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('홈')),
      ),
      GoRoute(
        path: AppRoutes.savedCourse,
        builder: (_, s) =>
            Scaffold(body: Text('코스 ${s.pathParameters['savedId']}')),
      ),
    ],
  );

  Widget app(GoRouter r, ProviderContainer container) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: r),
      );

  testWidgets('맡겨 둔 목적지가 있으면 스플래시가 끝난 뒤 거기로 간다', (tester) async {
    final r = router();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // 링크는 스플래시가 떠 있는 동안 도착한다 — 리스너가 여기 맡겨 둔다
    container
        .read(pendingDeepLinkProvider.notifier)
        .set(AppRoutes.savedCoursePath('122'), replace: true);

    await tester.pumpWidget(app(r, container));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text('코스 122'), findsOneWidget);
    expect(find.text('홈'), findsNothing);
    expect(r.routerDelegate.currentConfiguration.uri.path, '/my-courses/122');
    // 한 번 쓰고 비운다 — 다음 스플래시가 또 가지 않게
    expect(container.read(pendingDeepLinkProvider), isNull);
  });

  testWidgets('맡겨 둔 것이 없으면 그냥 다음 화면이다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(app(router(), container));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
  });
}
