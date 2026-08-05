import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/course_wizard/presentation/calendar_screen.dart';
import '../../features/course_wizard/presentation/date_gate_screen.dart';
import '../../features/course/presentation/course_screen.dart';
import '../../features/course/presentation/course_save_date_screen.dart';
import '../../features/course/presentation/course_schedule_screen.dart';
import '../../features/course/presentation/my_courses_screen.dart';
import '../../features/course/presentation/saved_course_screen.dart';
import '../../features/course_wizard/presentation/candidates_screen.dart';
import '../../features/course_wizard/presentation/density_screen.dart';
import '../../features/course_wizard/presentation/loading_screen.dart';
import '../../features/course_wizard/presentation/period_style_screen.dart';
import '../../features/course_wizard/presentation/transport_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/my/presentation/my_screen.dart';
import '../../features/onboarding/presentation/leave_input_screen.dart';
import '../../features/region/presentation/region_detail_screen.dart';
import '../../features/region/presentation/region_list_screen.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const onboardingLeave = '/onboarding/leave';
  static const home = '/';
  static const wizardDateGate = '/wizard/date-gate';
  static const wizardCalendar = '/wizard/calendar';
  static const wizardPeriodStyle = '/wizard/period-style';
  static const wizardTransport = '/wizard/transport';
  static const wizardDensity = '/wizard/density';
  static const wizardLoading = '/wizard/loading';
  static const wizardCandidates = '/wizard/candidates';

  static const myCourses = '/my-courses';

  /// 저장한 코스 상세. `:savedId` 경로 파라미터 사용
  static const savedCourse = '/my-courses/:savedId';

  static String savedCoursePath(String savedId) => '/my-courses/$savedId';

  /// 저장한 코스의 여행 일정 지정 (캘린더)
  static const courseSchedule = '/my-courses/:savedId/schedule';

  static String courseSchedulePath(String savedId) =>
      '/my-courses/$savedId/schedule';

  static const my = '/my';

  static const regionList = '/regions';

  /// 지역 상세. `:regionId` 경로 파라미터 사용
  static const regionDetail = '/region/:regionId';

  static String regionDetailPath(String regionId) =>
      '/region/${Uri.encodeComponent(regionId)}';

  /// 코스확정. `:regionId` 경로 파라미터 + `days` 쿼리 파라미터 사용
  static const course = '/course/:regionId';

  /// 한글 지역 ID의 플랫폼별 URL 인코딩 불일치를 피하기 위해 명시적으로 인코딩한다
  static String coursePath(String regionId, {required int desiredDays}) =>
      '/course/${Uri.encodeComponent(regionId)}?days=$desiredDays';

  /// 담기 직전 여행 날짜 지정 (프리셋 경로 전용). 시작일을 pop 결과로 돌려준다
  static const courseSaveDate = '/course-save-date';

  static String courseSaveDatePath({required int travelDays}) =>
      '$courseSaveDate?days=$travelDays';
}

/// 하단 탭 목적지용 페이지. 탭끼리는 형제 화면이라 좌우 슬라이드 없이 바로 전환된다.
/// [NoTransitionPage] 대신 전환 시간이 0인 [CustomTransitionPage]를 쓰는 이유는,
/// 위에 다른 화면을 push했을 때 아래 화면이 정상적으로 offstage 처리되도록 하기 위함이다.
CustomTransitionPage<void> _noTransitionPage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
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
        pageBuilder: (context, state) => _noTransitionPage(const HomeScreen()),
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
      GoRoute(
        path: AppRoutes.wizardPeriodStyle,
        name: 'wizardPeriodStyle',
        builder: (context, state) => const PeriodStyleScreen(),
      ),
      GoRoute(
        path: AppRoutes.wizardTransport,
        name: 'wizardTransport',
        builder: (context, state) => const TransportScreen(),
      ),
      GoRoute(
        path: AppRoutes.wizardDensity,
        name: 'wizardDensity',
        builder: (context, state) => const DensityScreen(),
      ),
      GoRoute(
        path: AppRoutes.wizardLoading,
        name: 'wizardLoading',
        builder: (context, state) => const WizardLoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.wizardCandidates,
        name: 'wizardCandidates',
        builder: (context, state) => const CandidatesScreen(),
      ),
      GoRoute(
        path: AppRoutes.myCourses,
        name: 'myCourses',
        pageBuilder: (context, state) =>
            _noTransitionPage(const MyCoursesScreen()),
      ),
      // 더 구체적인 /schedule 경로를 :savedId 보다 먼저 등록한다
      GoRoute(
        path: AppRoutes.courseSchedule,
        name: 'courseSchedule',
        builder: (context, state) =>
            CourseScheduleScreen(savedId: state.pathParameters['savedId']!),
      ),
      GoRoute(
        path: AppRoutes.savedCourse,
        name: 'savedCourse',
        builder: (context, state) =>
            SavedCourseScreen(savedId: state.pathParameters['savedId']!),
      ),
      GoRoute(
        path: AppRoutes.my,
        name: 'my',
        pageBuilder: (context, state) => _noTransitionPage(const MyScreen()),
      ),
      GoRoute(
        path: AppRoutes.regionList,
        name: 'regionList',
        builder: (context, state) => const RegionListScreen(),
      ),
      GoRoute(
        path: AppRoutes.regionDetail,
        name: 'regionDetail',
        builder: (context, state) {
          final raw = state.pathParameters['regionId']!;
          return RegionDetailScreen(
            regionId: raw.contains('%') ? Uri.decodeComponent(raw) : raw,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.course,
        name: 'course',
        builder: (context, state) {
          // 플랫폼에 따라 경로 파라미터가 인코딩된 채 올 수 있어 필요한 경우에만 디코딩
          final raw = state.pathParameters['regionId']!;
          final regionId = raw.contains('%') ? Uri.decodeComponent(raw) : raw;
          return CourseScreen(
            regionId: regionId,
            desiredDays:
                int.tryParse(state.uri.queryParameters['days'] ?? '') ?? 1,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.courseSaveDate,
        name: 'courseSaveDate',
        builder: (context, state) => CourseSaveDateScreen(
          travelDays:
              int.tryParse(state.uri.queryParameters['days'] ?? '') ?? 1,
        ),
      ),
    ],
  );
});
