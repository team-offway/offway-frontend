import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/onboarding/presentation/onboarding_intro_screen.dart';
import 'package:offway/features/splash/presentation/splash_screen.dart';

void main() {
  /// 스플래시 → [next] → 온보딩 소개를 잇는 최소 라우터.
  ///
  /// 앱 전체를 띄우지 않는다 — 여기서 보려는 건 두 화면의 동작뿐이고,
  /// 앱을 띄우면 Firebase·네이버 SDK까지 끌려온다.
  Widget appWith({required String initial}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) =>
              const SplashScreen(next: AppRoutes.onboardingIntro),
        ),
        GoRoute(
          path: AppRoutes.onboardingIntro,
          builder: (context, state) => const OnboardingIntroScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('로그인화면'))),
        ),
      ],
    );
    addTearDown(router.dispose);
    // 타이포 토큰은 fontFamily를 비워두고 테마에서 지정하므로 테마가 필요하다
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
  }

  group('스플래시', () {
    testWidgets('워드마크를 보여주고 다음 화면으로 넘어간다', (tester) async {
      await tester.pumpWidget(appWith(initial: AppRoutes.splash));
      await tester.pump();

      // 아직 머무는 중 — 소개 화면은 안 보인다
      expect(find.text('오프웨이에선'), findsNothing);

      // 머무는 시간이 지나면 스스로 넘어간다
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(find.text('오프웨이에선'), findsOneWidget);
    });

    testWidgets('머물기 전에 화면을 벗어나도 터지지 않는다', (tester) async {
      await tester.pumpWidget(appWith(initial: AppRoutes.splash));
      await tester.pump();

      // 타이머가 남은 채로 위젯을 버린다 — dispose가 타이머를 거두지 않으면
      // 사라진 화면에서 context.go가 불려 던진다
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1300));
      expect(tester.takeException(), isNull);
    });
  });

  group('온보딩 소개', () {
    testWidgets('첫 장에는 이전이 없다', (tester) async {
      await tester.pumpWidget(appWith(initial: AppRoutes.onboardingIntro));
      await tester.pumpAndSettle();

      expect(find.text('짧은 연차도 특별한 여행이 돼요'), findsOneWidget);
      expect(find.text('다음'), findsOneWidget);
      expect(find.text('이전'), findsNothing);
    });

    testWidgets('다음을 누르면 둘째 장으로, 이전으로 되돌아온다', (tester) async {
      await tester.pumpWidget(appWith(initial: AppRoutes.onboardingIntro));
      await tester.pumpAndSettle();

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('코스 추천과 정부 혜택까지!'), findsOneWidget);
      // 둘째 장에는 이전이 함께 있다
      expect(find.text('이전'), findsOneWidget);

      await tester.tap(find.text('이전'));
      await tester.pumpAndSettle();
      expect(find.text('짧은 연차도 특별한 여행이 돼요'), findsOneWidget);
    });

    testWidgets('마지막 장에서 다음을 누르면 로그인으로 간다', (tester) async {
      await tester.pumpWidget(appWith(initial: AppRoutes.onboardingIntro));
      await tester.pumpAndSettle();

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('로그인화면'), findsOneWidget);
    });
  });
}
