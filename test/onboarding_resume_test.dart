import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/course/application/pending_trip_provider.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';

/// 연차를 등록하지 않은 사람은 홈에 머물지 못한다.
///
/// 로그인 직후의 `isNewUser` 분기만으로는 부족하다 — 그 값은 '이번에 계정을
/// 만들었나'라서, 온보딩에서 앱을 껐다 켠 사람에게는 다시 false다. 그러면
/// 잔여 연차가 빈 채로 홈에 갇힌다.
void main() {
  /// 홈에서 시작하는 라우터. 온보딩으로 갔는지 [visited]에 적힌다
  Future<List<String>> pumpHome(
    WidgetTester tester, {
    required Map<String, dynamic> user,
  }) async {
    final visited = <String>[];
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: AppRoutes.onboardingLeave,
          builder: (_, _) {
            visited.add(AppRoutes.onboardingLeave);
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSnapshotProvider.overrideWith(
            (ref) async => HomeSnapshot(user: user, regions: const []),
          ),
          // 홈이 이름을 이 프로바이더로 읽는다 — 안 덮으면 /users/me를 탄다
          currentUserProvider.overrideWith((ref) async => user),
          // 홈이 함께 부르는 것들 — 서버를 타면 타이머가 남는다
          pendingTripProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return visited;
  }

  testWidgets('잔여 연차가 없으면 온보딩으로 돌려보낸다', (tester) async {
    final visited = await pumpHome(
      tester,
      user: {'nickname': '영찬', 'remainingLeaveDays': null},
    );

    expect(visited, [AppRoutes.onboardingLeave]);
  });

  testWidgets('잔여 연차가 있으면 홈에 머문다', (tester) async {
    final visited = await pumpHome(
      tester,
      user: {'nickname': '영찬', 'remainingLeaveDays': 12.0},
    );

    expect(visited, isEmpty);
  });

  testWidgets('연차가 0이어도 등록한 것이라 홈에 머문다', (tester) async {
    // 다 써서 0인 사람과 아직 안 넣은 사람은 다르다
    final visited = await pumpHome(
      tester,
      user: {'nickname': '영찬', 'remainingLeaveDays': 0.0},
    );

    expect(visited, isEmpty);
  });
}
