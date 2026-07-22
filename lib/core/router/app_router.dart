import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/course_wizard/presentation/calendar_screen.dart';
import '../../features/course_wizard/presentation/date_gate_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/leave_input_screen.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const onboardingLeave = '/onboarding/leave';
  static const home = '/';
  static const wizardDateGate = '/wizard/date-gate';
  static const wizardCalendar = '/wizard/calendar';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // TODO(auth): 로그인 상태 저장 후 redirect로 분기 (지금은 항상 로그인부터)
    // 개발용: --dart-define=INITIAL_ROUTE=/onboarding/leave 로 시작 화면 지정 가능
    initialLocation: const String.fromEnvironment(
      'INITIAL_ROUTE',
      defaultValue: AppRoutes.login,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingLeave,
        name: 'onboardingLeave',
        builder: (context, state) => const LeaveInputScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.wizardDateGate,
        name: 'wizardDateGate',
        builder: (context, state) => const DateGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.wizardCalendar,
        name: 'wizardCalendar',
        builder: (context, state) => const CalendarScreen(),
      ),
    ],
  );
});
