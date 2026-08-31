import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/trip_constants.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/course_wizard/presentation/calendar_screen.dart';
import '../../features/course_wizard/presentation/date_gate_screen.dart';
import '../../features/course/presentation/course_screen.dart';
import '../../features/course/presentation/course_save_date_screen.dart';
import '../../features/course/presentation/course_schedule_screen.dart';
import '../../features/course/presentation/poi_detail_screen.dart';
import '../../features/course/presentation/my_courses_screen.dart';
import '../../features/course/presentation/saved_course_screen.dart';
import '../../features/course_wizard/presentation/candidates_screen.dart';
import '../../features/course_wizard/presentation/density_screen.dart';
import '../../features/course_wizard/presentation/period_style_screen.dart';
import '../../features/course_wizard/presentation/transport_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/my/presentation/my_screen.dart';
import '../../features/my/presentation/withdraw_screen.dart';
import '../../features/leave/presentation/leave_register_screen.dart';
import '../../features/leave/presentation/leave_usages_screen.dart';
import '../../features/leave/presentation/my_leave_screen.dart';
import '../../features/leave/presentation/total_leave_screen.dart';
import '../../features/course/presentation/shared_course_screen.dart';
import '../../features/notification/presentation/notification_screen.dart';
import '../../features/onboarding/presentation/leave_input_screen.dart';
import '../../features/region/presentation/region_detail_screen.dart';
import '../../features/region/presentation/region_list_screen.dart';
import '../../features/onboarding/presentation/onboarding_intro_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../widgets/app_tab_pills.dart';

abstract final class AppRoutes {
  static const splash = '/splash';

  /// 앱 소개 두 장 — 로그인 전에 보여준다
  static const onboardingIntro = '/onboarding/intro';
  static const login = '/login';
  static const onboardingLeave = '/onboarding/leave';
  static const myLeave = '/leave';

  /// "다녀오셨나요?" 알림을 눌렀을 때 — 도착하면 모달이 뜬다
  static const myLeaveFromNotification = '/leave?from=notification';
  static const leaveRegister = '/leave/register';
  static const leaveUsages = '/leave/usages';

  /// 마이 > 내 연차 관리 — 총 연차일수를 고치는 자리
  static const totalLeave = '/leave/total';

  /// 내 연차에서 들어가는 총 연차 수정 — 저장하면 닫고 돌아온다
  static const totalLeaveFromMyLeave = '/leave/total?from=leave';
  static const home = '/';
  static const notifications = '/notifications';

  /// 공유 링크로 받은 코스 — 카카오톡 '앱으로 보기'가 여기로 온다
  static const sharedCourse = '/shared/:shareToken';

  /// 공유받은 코스. [kind]가 'saved'면 내 코스 형태(날짜·연차)로, 아니면
  /// 추천코스 형태로 보여준다 — 웹 공유 페이지와 같은 분기다.
  static String sharedCoursePath(String shareToken, {String? kind}) =>
      '/shared/$shareToken${kind == null ? '' : '?kind=$kind'}';
  static const wizardDateGate = '/wizard/date-gate';
  static const wizardCalendar = '/wizard/calendar';
  static const wizardPeriodStyle = '/wizard/period-style';
  static const wizardTransport = '/wizard/transport';
  static const wizardDensity = '/wizard/density';
  static const wizardCandidates = '/wizard/candidates';

  static const myCourses = '/my-courses';

  /// 저장한 코스 상세. `:savedId` 경로 파라미터 사용
  static const savedCourse = '/my-courses/:savedId';

  static String savedCoursePath(String savedId) => '/my-courses/$savedId';

  /// 저장한 코스의 여행 일정 지정 (캘린더)
  static const courseSchedule = '/my-courses/:savedId/schedule';

  static String courseSchedulePath(String savedId) =>
      '/my-courses/$savedId/schedule';

  /// 장소(POI) 상세. `:contentId` 경로 파라미터 + `name` 쿼리(헤더 제목)
  static const poiDetail = '/pois/:contentId';

  /// [regionName]을 주면 상단바에 그 지역명이 뜬다 — 지역에서 들어온 경로다.
  /// 코스에서 들어올 때는 어느 지역인지 이미 알고 있어 비워 둔다
  static String poiDetailPath(
    String contentId, {
    required String name,
    String? regionName,
  }) =>
      '/pois/${Uri.encodeComponent(contentId)}'
      '?name=${Uri.encodeComponent(name)}'
      '${regionName == null ? '' : '&region=${Uri.encodeComponent(regionName)}'}';

  static const my = '/my';
  static const withdraw = '/my/withdraw';

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
      '$courseSaveDate?days=${clampTripDays(travelDays)}';

  /// 코스 길이를 정책 범위(1일~2박3일)로 강제한다 — 딥링크 등 비정상 값 방어
  static int clampTripDays(int days) => days.clamp(1, kMaxTripSpanDays + 1);
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

/// 앱을 켰을 때 처음 열 화면.
///
/// 스플래시가 끝나면 갈 곳.
///
/// 토큰이 남아 있으면 홈으로 바로 들어간다 — 앱을 켤 때마다 로그인 버튼을
/// 다시 누르게 하면 안 된다. 이 값은 앱 시작 시 [main]이 Keychain을 읽어
/// 덮어쓴다. 스플래시가 머무는 동안이 아니라 **그 전에** 읽는 이유는, 라우터가
/// 만들어질 때 목적지가 정해져 있어야 스플래시가 끝나고 곧장 넘길 수 있기
/// 때문이다.
///
/// 로그인 전이면 소개 두 장([AppRoutes.onboardingIntro])부터 보여준다.
///
/// 개발용: `--dart-define=INITIAL_ROUTE=/onboarding/leave` 가 늘 우선한다
final postSplashRouteProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'INITIAL_ROUTE',
    defaultValue: AppRoutes.onboardingIntro,
  );
});

/// 앱이 처음 그리는 경로.
///
/// 늘 스플래시다. 단 개발용 `INITIAL_ROUTE`를 준 경우에는 그 화면을 바로 띄운다
/// — 특정 화면만 보려고 실행할 때 스플래시를 기다릴 이유가 없다.
final initialRouteProvider = Provider<String>((ref) {
  const override = String.fromEnvironment('INITIAL_ROUTE');
  return override.isEmpty ? AppRoutes.splash : override;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: ref.watch(initialRouteProvider),
    routes: [
      // 홈·내 코스·마이는 탭바를 함께 쓴다.
      //
      // **탭바를 라우트 밖에 한 번만 둔다.** 화면마다 만들면 탭을 옮길 때
      // 위젯이 파괴되고 새로 생겨, 알약이 애니메이션할 이전 위치를 잃는다 —
      // 이동 연출이 통째로 사라진다.
      ShellRoute(
        // 셸도 전환 없이 얹는다 — 기본 MaterialPage 를 쓰면 셸이 들어올 때
        // 한 번 밀려들어와 '탭 전환에 슬라이드가 없다'는 약속이 깨진다
        pageBuilder: (context, state, child) => _noTransitionPage(
          _TabScaffold(location: state.uri.path, child: child),
        ),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) =>
                _noTransitionPage(const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.myCourses,
            name: 'myCourses',
            pageBuilder: (context, state) =>
                _noTransitionPage(const MyCoursesScreen()),
          ),
          GoRoute(
            path: AppRoutes.my,
            name: 'my',
            pageBuilder: (context, state) =>
                _noTransitionPage(const MyScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        // 다음 목적지는 main이 정해 둔 초기 경로다. 스플래시가 그 값을
        // 그대로 들고 가서, 머문 뒤 거기로 보낸다
        builder: (context, state) =>
            SplashScreen(next: ref.read(postSplashRouteProvider)),
      ),
      GoRoute(
        path: AppRoutes.onboardingIntro,
        name: 'onboardingIntro',
        builder: (context, state) => const OnboardingIntroScreen(),
      ),
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
        path: AppRoutes.myLeave,
        name: 'myLeave',
        // ?from=notification 이면 "다녀오셨나요?" 모달을 띄운다 — 그 알림을
        // 눌러 들어온 경우다
        builder: (context, state) => MyLeaveScreen(
          fromNotification: state.uri.queryParameters['from'] == 'notification',
        ),
      ),
      GoRoute(
        path: AppRoutes.leaveRegister,
        name: 'leaveRegister',
        builder: (context, state) => const LeaveRegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.leaveUsages,
        name: 'leaveUsages',
        builder: (context, state) => const LeaveUsagesScreen(),
      ),
      GoRoute(
        path: AppRoutes.totalLeave,
        name: 'totalLeave',
        // ?from=leave 면 저장하고 닫는다 — 내 연차에서 들어온 경우다.
        // 바뀐 잔여 일수가 그 화면에 크게 떠 있어 돌아가야 결과가 보인다
        builder: (context, state) => TotalLeaveScreen(
          popOnSaved: state.uri.queryParameters['from'] == 'leave',
        ),
      ),
      GoRoute(
        path: AppRoutes.sharedCourse,
        name: 'sharedCourse',
        builder: (context, state) => SharedCourseScreen(
          shareToken: state.pathParameters['shareToken']!,
          kind: state.uri.queryParameters['kind'],
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationScreen(),
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
        path: AppRoutes.wizardCandidates,
        name: 'wizardCandidates',
        builder: (context, state) => const CandidatesScreen(),
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
        path: AppRoutes.poiDetail,
        name: 'poiDetail',
        builder: (context, state) => PoiDetailScreen(
          contentId: state.pathParameters['contentId']!,
          // 헤더 제목은 코스 리스트에서 넘어온 이름을 그대로 쓴다
          name: state.uri.queryParameters['name'] ?? '',
          regionName: state.uri.queryParameters['region'],
        ),
      ),
      GoRoute(
        path: AppRoutes.withdraw,
        name: 'withdraw',
        builder: (context, state) => const WithdrawScreen(),
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
          travelDays: AppRoutes.clampTripDays(
            int.tryParse(state.uri.queryParameters['days'] ?? '') ?? 1,
          ),
        ),
      ),
    ],
  );
});

/// 탭 셋(홈·내 코스·마이)이 함께 쓰는 껍데기.
///
/// 탭바를 여기 한 번만 두어 화면이 바뀌어도 살아남게 한다 — 그래야 알약이
/// 이전 자리에서 새 자리로 미끄러진다. 화면마다 두면 매번 새로 생겨
/// 이미 도착한 상태로 그려진다.
class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.location, required this.child});

  /// 지금 열린 경로 — 어느 탭을 활성으로 그릴지 이 값이 정한다
  final String location;
  final Widget child;

  AppTab? get _current => switch (location) {
    AppRoutes.home => AppTab.home,
    AppRoutes.myCourses => AppTab.myCourse,
    AppRoutes.my => AppTab.my,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // 콘텐츠가 탭바 뒤로 지나가야 유리 너머로 비친다
      extendBody: true,
      body: child,
      bottomNavigationBar: AppTabPills(
        current: _current,
        onTap: (tab) {
          final path = switch (tab) {
            AppTab.home => AppRoutes.home,
            AppTab.myCourse => AppRoutes.myCourses,
            AppTab.my => AppRoutes.my,
          };
          if (path != location) context.go(path);
        },
      ),
    );
  }
}
