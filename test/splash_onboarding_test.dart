import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

    testWidgets('로고가 네이티브 런치스크린과 같은 자리·크기다', (tester) async {
      await tester.pumpWidget(appWith(initial: AppRoutes.splash));
      await tester.pump();

      // 네이티브(LaunchScreen.storyboard): 125x38pt 로고의 **중심**이 화면
      // 높이의 43.11% 지점. 어긋나면 엔진이 뜨는 순간 로고가 튄다 (#131).
      // Alignment는 (화면-로고) 안에서 비율을 잡아 2.6pt 위로 어긋났었다
      final logo = tester.getRect(find.byType(SvgPicture));
      final screen = tester.getSize(find.byType(Scaffold));
      expect(logo.width, 125);
      expect(logo.height, 38);
      expect(logo.center.dy, moreOrLessEquals(screen.height * 0.4311));
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

    testWidgets('둘째 장에서 시스템 뒤로가기는 첫 장으로 되돌린다', (tester) async {
      await tester.pumpWidget(appWith(initial: AppRoutes.onboardingIntro));
      await tester.pumpAndSettle();

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('코스 추천과 정부 혜택까지!'), findsOneWidget);

      // 스와이프 백이 온보딩을 통째로 빠져나가면 안 된다 — 한 장만 되돌린다
      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(popped, isTrue);
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
