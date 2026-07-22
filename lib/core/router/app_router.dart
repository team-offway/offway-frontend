import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // TODO(auth): 로그인 상태 저장 후 redirect로 분기 (지금은 항상 로그인부터)
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});
