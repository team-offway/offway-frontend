import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/app/app.dart';
import 'package:offway/core/location/origin_locator.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/auth/data/google_auth_service.dart';
import 'package:offway/features/course/data/course_repository.dart';
import 'package:offway/features/course/presentation/my_courses_screen.dart';
import 'package:offway/features/course_wizard/data/region_recommend_repository.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/my/presentation/my_screen.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';
import 'package:offway/features/region/data/region_list_repository.dart';
import 'package:offway/features/region/presentation/region_list_screen.dart';
import 'package:offway/features/region/presentation/widgets/leave_pick_card.dart';
import 'package:offway/mock/mock_data_source.dart';

/// Keychain 삭제가 실패하는 상황을 재현하는 저장소
class _FailingSecureStoragePlatform extends TestFlutterSecureStoragePlatform {
  _FailingSecureStoragePlatform() : super({});

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => throw Exception('keychain unavailable');
}

/// 테스트는 서버를 부르지 않는다 — 홈은 mock JSON을 그대로 돌려준다
class _FakeHomeRepository extends HomeRepository {
  _FakeHomeRepository() : super(Dio());

  @override
  Future<HomeSnapshot> fetch() async => HomeSnapshot(
    user: await MockDataSource.user(),
    regions: await MockDataSource.allRegions(),
    filters: const [
      {'key': 'ALL', 'label': '전체'},
      {'key': 'SIGHT', 'label': '관광지'},
      {'key': 'STAY', 'label': '숙박'},
      {'key': 'EXPERIENCE', 'label': '체험'},
      {'key': 'FOOD', 'label': '맛집'},
    ],
  );
}

/// 온보딩 연차 저장 — 네트워크 없이 항상 성공한 것으로 친다
class _FakeLeaveRepository extends LeaveRepository {
  _FakeLeaveRepository() : super(Dio());

  @override
  Future<double> updateTotalDays(double totalDays) async => totalDays;

  /// 가용시간 계산은 실패로 친다 — 위저드가 로컬 추정 폴백으로 흐른다
  @override
  Future<AvailableTime> availableTime({
    required String transport,
    DateTime? startDate,
    DateTime? endDate,
    String? periodStyle,
    DateTime? baseDate,
    String? weekendBridge,
    int? leaveDays,
  }) async => throw const ApiException(
    status: 0,
    code: 'TEST',
    detail: '테스트에는 서버가 없어요',
  );
}

/// 지역 목록 더보기 — mock 지역을 한 페이지로 돌려준다.
/// 실제로는 서버가 89곳을 페이지로 끊어 주지만, 화면 검증에는 한 장이면 된다
class _FakeRegionListRepository extends RegionListRepository {
  _FakeRegionListRepository() : super(Dio());

  @override
  Future<RegionPage> fetch({
    String? category,
    int page = 0,
    int size = 20,
  }) async => RegionPage(
    regions: page == 0 ? await MockDataSource.allRegions() : const [],
    hasMore: false,
  );
}

/// 후보지역 추천 — mock 후보를 새 카드 형태로 돌려준다.
/// id가 mock 코스의 키('정선')와 같아 코스 화면까지 이어지는 플로우가 유지된다.
class _FakeRegionRecommendRepository extends RegionRecommendRepository {
  _FakeRegionRecommendRepository() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> recommend({
    required Origin origin,
    required String transport,
    required int maxReachMinutes,
  }) async {
    final data = await MockDataSource.regions();
    final list = (data['candidates'] as List).cast<Map<String, dynamic>>();
    return [
      for (final r in list)
        {
          'id': r['id'],
          'name': r['name'],
          'sido': r['sido'],
          'imageUrl': r['imageUrl'],
          'badge': r['badge'],
          'description': r['description'],
          'reachMinutes': r['travelMinutesByCar'],
          if (r['benefitBadge'] != null) 'benefitBadge': r['benefitBadge'],
        },
    ];
  }
}

/// 코스 생성 — 옛 mock 선택 규칙(지역 일치 + 희망일수에 가장 가까운 코스)을 재현한다
class _FakeCourseRepository extends CourseRepository {
  _FakeCourseRepository() : super(Dio());

  @override
  Future<Map<String, dynamic>> generate({
    required String regionId,
    required int travelDays,
    required String density,
    required String transport,
    required Origin origin,
    required DateTime travelDate,
    DateTime? confirmedDate,
  }) async {
    final data = await MockDataSource.courses();
    final courses = (data['courses'] as List)
        .cast<Map<String, dynamic>>()
        .where((c) => c['regionId'] == regionId)
        .toList();
    courses.sort(
      (a, b) => ((a['durationDays'] as int) - travelDays).abs().compareTo(
        ((b['durationDays'] as int) - travelDays).abs(),
      ),
    );
    return {
      ...courses.first,
      'regionName': regionId,
      '_save': <String, dynamic>{},
    };
  }

  @override
  Future<({int courseId, String? shareToken})> save(
    Map<String, dynamic> savePayload,
  ) async => (courseId: 1, shareToken: 'test-token');

  @override
  Future<void> deductLeave(int courseId) async {}

  @override
  Future<List<Map<String, dynamic>>> savedCourseCards({
    String scope = 'ALL',
  }) async {
    final data = await MockDataSource.courses();
    // 서버는 최신순으로 정렬해 준다 — mock은 오래된 것부터라 뒤집는다
    return (data['savedCourses'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .reversed
        .toList();
  }

  @override
  Future<({Map<String, dynamic> saved, Map<String, dynamic> course})?>
  savedCourseDetail(String courseId) async {
    final data = await MockDataSource.courses();
    final saved = (data['savedCourses'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((s) => s['id'] == courseId)
        .firstOrNull;
    if (saved == null) return null;
    final course = (data['courses'] as List)
        .cast<Map<String, dynamic>>()
        .where((c) => c['id'] == saved['courseId'])
        .firstOrNull;
    if (course == null) return null;
    return (saved: saved, course: course);
  }

  @override
  Future<void> delete(String courseId) async {}
}

/// 실서버를 부르는 repository를 전부 가짜로 바꾼다.
/// 테스트 환경은 HTTP를 400으로 막아, 안 바꾸면 화면 플로우가 전부 끊긴다.
/// 계정 선택 창을 띄우지 않고 바로 성공을 돌려주는 구글 로그인.
///
/// 테스트는 이 버튼으로 플로우에 진입하므로 실제 SDK를 타면 안 된다.
class _FakeGoogleAuthService implements GoogleAuthService {
  @override
  Future<GoogleLoginResult> login() async => (
    idToken: 'test-id-token',
    email: 'test@example.com',
    displayName: '테스트',
    userId: 'test-user-id',
  );

  @override
  Future<void> logout() async {}
}

final _serverOverrides = [
  googleAuthServiceProvider.overrideWithValue(_FakeGoogleAuthService()),
  homeRepositoryProvider.overrideWithValue(_FakeHomeRepository()),
  regionListRepositoryProvider.overrideWithValue(_FakeRegionListRepository()),
  leaveRepositoryProvider.overrideWithValue(_FakeLeaveRepository()),
  regionRecommendRepositoryProvider.overrideWithValue(
    _FakeRegionRecommendRepository(),
  ),
  courseRepositoryProvider.overrideWithValue(_FakeCourseRepository()),
];

void main() {
  setUp(() {
    // Keychain 플러그인은 테스트 환경에 없으므로 인메모리 구현으로 대체
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
  });
  testWidgets('앱 실행 시 로그인 화면이 보인다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('OffWay'), findsOneWidget); // 워드마크 로고
    expect(find.text('연차로 떠나는 로컬 여행'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('Apple로 시작하기'), findsOneWidget);
    expect(find.text('Google로 시작하기'), findsOneWidget);
  });

  testWidgets('소셜 로그인 버튼을 누르면 잔여연차 온보딩으로 이동한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();

    expect(find.text('남은 연차를 입력해 주세요'), findsOneWidget);
  });

  testWidgets('온보딩 연차가 한계에 닿으면 왜 못 바꾸는지 토스트로 알린다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();

    // 0일까지 내린 뒤 한 번 더 누르면 하한 안내가 뜬다
    await tester.tap(find.text('15일'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('0일'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.textContaining('0일보다 적게'), findsOneWidget);

    // 상한(99일)에서도 마찬가지
    await tester.tap(find.text('0일'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('99일'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.textContaining('최대 99일까지'), findsOneWidget);
  });

  testWidgets('온보딩에서 연차를 조절하고 시작하면 홈으로 이동한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();

    expect(find.text('15일'), findsOneWidget);
    // 반차 단위(0.5일)로 증감
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('15.5일'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('15일'), findsOneWidget);

    // 숫자를 눌러 직접 입력 (소수점 허용, 0.5 단위로 보정)
    await tester.tap(find.text('15일'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '7.3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('7.5일'), findsOneWidget);

    // 빈 여백을 탭해도 입력이 확정된다
    await tester.tap(find.text('7.5일'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text('남은 연차를 입력해 주세요'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(TextField), findsNothing); // 입력 모드 종료
    expect(find.text('3일'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pump();
    // rootBundle 로드가 FakeAsync에 갇힌 채 전역 캐시에 남지 않도록 실제 비동기로 완료시킨다
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    // 홈은 네트워크 이미지 로드가 있어 pumpAndSettle 대신 유한 pump 사용
    await tester.pump();
    expect(find.text('남은 연차 일수'), findsOneWidget); // 홈 도착
  });

  testWidgets('홈에 mock 사용자·추천 여행지가 표시된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    // rootBundle 로드(실제 I/O)가 FakeAsync에서 멈추지 않도록 runAsync로 대기
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    // 네트워크 이미지 로드가 있어 pumpAndSettle 대신 유한 pump 사용
    await tester.pump();

    expect(find.text('11일'), findsOneWidget); // mock 잔여연차
    expect(find.textContaining('어디로 떠나볼까요?'), findsOneWidget);
    expect(find.text('이번달 추천 여행지'), findsOneWidget);
    // 카드 제목과 썸네일 위 오버레이 두 곳에 지역명이 나온다
    expect(find.text('정선 · 강원'), findsNWidgets(2));
    expect(find.text('숙박비 30% 지원'), findsOneWidget);

    // 히어로 CTA는 브랜드 하늘색이 아니라 검정(Neutral/22)이다.
    // 다른 화면 CTA와 같아 보여 무심코 Primary로 바꾸기 쉬워 고정해 둔다.
    final cta = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('바로 추천받기'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(cta.style?.backgroundColor?.resolve({}), const Color(0xFF303030));
  });

  testWidgets('홈 아래에 "이번 연차엔 여기 어때요?" 카드가 깔린다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google로 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 섹션이 화면 밖에 있으므로 끌어올려 찾는다
    final section = find.text('이번 연차엔 여기 어때요?');
    await tester.scrollUntilVisible(
      section,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(section, findsOneWidget);

    // 시안 실측 190×220 — 카드가 그 크기로 깔린다
    final card = find.byType(LeavePickCard);
    expect(card, findsWidgets);
    expect(tester.getSize(card.first), const Size(190, 220));
  });

  testWidgets('하단 탭에서 마이로 이동하고 로그아웃하면 로그인 화면으로 돌아간다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('마이'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.textContaining('반가워요!'), findsOneWidget);
    expect(find.text('개인정보처리방침'), findsOneWidget);
    expect(find.text('회원탈퇴'), findsOneWidget);

    // 로그아웃은 확인 다이얼로그를 거친다
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    // 모달이 열리면 '로그아웃'이 메뉴와 제목 두 곳에 뜬다
    expect(find.text('정말 로그아웃 할까요?'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('연차로 떠나는 로컬 여행'), findsOneWidget); // 로그인 화면
  });

  testWidgets('로그아웃이 실패하면 로그인 화면으로 넘어가지 않고 알린다', (tester) async {
    // 토큰이 남은 채 로그인 화면으로 보내면 로그아웃된 줄 알게 되므로
    FlutterSecureStoragePlatform.instance = _FailingSecureStoragePlatform();

    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('마이'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.textContaining('로그아웃에 실패'), findsOneWidget);
    expect(find.byType(MyScreen), findsOneWidget); // 마이 화면에 그대로 머문다
    expect(find.text('연차로 떠나는 로컬 여행'), findsNothing);
  });

  testWidgets('하단 탭에서 내 코스로 이동하면 저장한 코스가 확정 여부와 함께 보인다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('내 코스'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    Finder inCourses(String text) => find.descendant(
      of: find.byType(MyCoursesScreen),
      matching: find.text(text),
    );

    // 서브탭 3종이 있고, 최신순(영월 미확정)이 위에 온다
    expect(inCourses('전체'), findsOneWidget);
    expect(inCourses('예정된 여행'), findsOneWidget);
    expect(inCourses('다녀온 여행'), findsOneWidget);
    expect(inCourses('영월 · 당일치기'), findsOneWidget);
    expect(inCourses('날짜 미정'), findsOneWidget);
    expect(inCourses('정선 · 2박3일'), findsOneWidget);
    expect(inCourses('2026.7.20 - 7.22'), findsOneWidget);
    // 끝난 여행에는 완료 뱃지가 붙는다 (mock 정선은 과거 날짜)
    expect(inCourses('여행완료'), findsOneWidget);
  });

  testWidgets('내 코스에서 확정 코스를 열면 날짜와 사용 연차가 보인다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('내 코스'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 확정 코스(정선)는 목록 아래쪽이라 스크롤해서 누른다
    final coursesList = find.descendant(
      of: find.byType(MyCoursesScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('정선 · 2박3일'),
      200,
      scrollable: coursesList,
    );
    // 떠 있는 하단 탭바가 카드를 덮지 않도록 한 번 더 올린다
    await tester.drag(coursesList, const Offset(0, -150));
    await tester.pump();
    await tester.tap(find.text('정선 · 2박3일'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.textContaining('정선 여행'), findsOneWidget);
    // 목록 카드(뒤에 남아 있음)와 상세가 같은 날짜 표기를 쓴다
    expect(find.text('2026.7.20 - 7.22'), findsWidgets);
    // 서버 계산이 stub에서 실패하므로 평일 수(월~수=3일) 폴백이 보인다
    expect(find.text('사용 연차 일수 3일'), findsOneWidget);
    expect(find.text('Day 3'), findsOneWidget);

    // 편집 시트에 날짜 수정과 삭제가 들어 있다
    await tester.tap(find.bySemanticsLabel('코스 편집'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('여행날짜 수정'), findsOneWidget);
    expect(find.text('코스 삭제'), findsOneWidget);
    // 시안 실측: 두 항목 상단 간격 52 (아이콘 배경 32 + 여백 20)
    final first = tester.getRect(find.text('여행날짜 수정'));
    final second = tester.getRect(find.text('코스 삭제'));
    expect(second.top - first.top, 52);
  });

  testWidgets('미확정 코스는 날짜 대신 일정 정하기 링크가 보인다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('내 코스'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 최신순 기본이라 미확정(영월)이 맨 위
    await tester.tap(find.text('영월 · 당일치기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.textContaining('영월 여행'), findsOneWidget);
    expect(find.text('여행 일정 정하기'), findsOneWidget);
    // 당일치기는 Day 탭이 하나뿐
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 2'), findsNothing);
  });

  testWidgets('미확정 코스에서 여행 일정 정하기를 누르면 캘린더로 이동한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('내 코스'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 미확정(영월) 코스로 들어가 일정 정하기 링크를 누른다
    await tester.tap(find.text('영월 · 당일치기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('여행 일정 정하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('여행 날짜 선택'), findsOneWidget);
    expect(find.text('최대 2박3일까지 선택할 수 있어요'), findsOneWidget);

    // 날짜를 고르기 전에는 선택 완료가 비활성
    final done = find.widgetWithText(FilledButton, '선택 완료');
    expect(tester.widget<FilledButton>(done).onPressed, isNull);

    // 시작일 하나만 고르면 코스 길이(당일치기=하루)만큼 범위가 완성된다.
    // 다음 달 중순(15일)을 쓴다 — 월말에 실행돼도 안전하고 그리드에서 유일하다.
    // 아래 코스 상세 화면이 트리에 남아 같은 숫자가 또 있을 수 있으므로
    // 화면에 실제로 보이는 셀만 대상으로 한다
    final today = DateUtils.dateOnly(DateTime.now());
    final nextMonth = DateTime(today.year, today.month + 1);
    await tester.scrollUntilVisible(
      find.text('${nextMonth.year}년 ${nextMonth.month}월'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    await tester.tap(find.text('15').hitTestable());
    await tester.pump();
    expect(find.text('가는날'), findsOneWidget);
    expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
  });

  testWidgets('하단 탭 전환은 좌우 슬라이드 없이 한 프레임에 끝난다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 홈 → 마이: 한 프레임 뒤 이미 제자리(dx=0)에 있어야 한다
    await tester.tap(find.text('마이'));
    await tester.pump();
    expect(find.byType(MyScreen), findsOneWidget);
    expect(tester.getTopLeft(find.byType(MyScreen)).dx, 0);

    await tester.pumpAndSettle();

    // 마이 → 홈도 마찬가지
    await tester.tap(find.text('홈'));
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.getTopLeft(find.byType(HomeScreen)).dx, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('홈 더보기 → 추천 여행지 목록에서 카테고리로 필터한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 시안에서 '더보기' 글자가 빠지고 쉐브론만 남았다 — 라벨로 찾는다
    await tester.tap(find.byKey(const Key('home-region-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 홈은 전환 없는 페이지라 목록 아래에 그대로 남아있다(불투명 배경에 가려짐).
    // 같은 문구가 홈에도 있으므로 목록 화면 안에서만 찾는다
    Finder inList(String text) => find.descendant(
      of: find.byType(RegionListScreen),
      matching: find.text(text),
    );
    // 지역명은 카드 제목과 썸네일 오버레이 두 곳에 나온다 — 제목만 겨냥한다
    Finder titleInList(String text) => find.descendant(
      of: find.byType(RegionListScreen),
      matching: find.byWidgetPredicate(
        (w) => w is Text && w.data == text && w.style?.fontSize == 15,
      ),
    );

    // 목록 화면: 헤더 + mock 5개 지역
    expect(inList('이번달 추천 여행지'), findsOneWidget);
    expect(titleInList('정선 · 강원'), findsOneWidget);
    // 마지막 지역은 뷰포트 아래라 스크롤해서 확인
    await tester.scrollUntilVisible(
      titleInList('영양 · 경북'),
      200,
      scrollable: find.descendant(
        of: find.byType(RegionListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(titleInList('영양 · 경북'), findsOneWidget);

    // 카테고리 필터는 지역별 콘텐츠 분포(실데이터) 기준으로 동작.
    // 칩 줄은 그리드 밖에 고정돼 있어 스크롤과 무관하게 늘 보인다
    await tester.tap(inList('체험'));
    await tester.pump();
    // 위에서 영양까지 내려둔 스크롤이 남아 있으므로 정선을 화면 안으로 올린다.
    // 오버레이 때문에 지역명이 두 번 나오므로 제목만 겨냥해야 단일 대상이 된다
    await tester.scrollUntilVisible(
      titleInList('정선 · 강원'),
      -200,
      scrollable: find.descendant(
        of: find.byType(RegionListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    // 오버레이가 붙어 지역명이 두 번 나오므로 카드 제목만 겨냥한다
    expect(titleInList('정선 · 강원'), findsOneWidget); // 체험 11건
  });

  testWidgets('홈에서 지역 카드를 누르면 지역 상세로 이동한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 지역 카드는 뷰포트 아래라 스크롤해서 올린 뒤 탭
    await tester.scrollUntilVisible(
      find.text('정선 · 강원').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('정선 · 강원').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.textContaining('폐광촌에서 예술마을로'), findsOneWidget);
    expect(find.text('정선 매력 포인트 장소'), findsOneWidget);

    // 기본 정보는 뷰포트 아래라 스크롤해서 확인
    await tester.scrollUntilVisible(
      find.text('기본 정보'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('인구감소지역 지정'), findsOneWidget);
  });

  testWidgets('바로 추천받기 → 날짜 갈림길에서 선택해야 다음이 활성화된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 400)); // 전환 애니메이션 완료
    await tester.pump();

    await tester.tap(find.text('바로 추천받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 페이지 전환

    expect(find.text('여행 날짜가 있나요?'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);

    // 선택 전에는 다음 버튼 비활성
    final nextButton = find.widgetWithText(FilledButton, '다음');
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

    await tester.tap(find.text('아직 안 정했어요'));
    await tester.pump();
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);
  });

  testWidgets('캘린더에서 2박3일 범위를 선택하면 선택 완료가 활성화된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('바로 추천받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('가고싶은 날짜가 있어요'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('여행 날짜 선택'), findsOneWidget);
    expect(find.text('최대 2박3일까지 선택할 수 있어요'), findsOneWidget);

    final done = find.widgetWithText(FilledButton, '선택 완료');
    expect(tester.widget<FilledButton>(done).onPressed, isNull);

    // 다음달 1일~2일 선택 (과거 날짜 회피, 첫 번째 달력의 셀은 중복 텍스트 가능성 → first)
    final nextMonth = DateTime.now().month == 12
        ? '1월'
        : '${DateTime.now().month + 1}월';
    await tester.scrollUntilVisible(
      find.textContaining(nextMonth),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    // 다음달 헤더 아래의 1, 2일 탭
    await tester.tap(find.text('1').last);
    await tester.pump();
    // 정책: 가는날+2일 초과 날짜는 비활성 — 탭해도 반응 없음
    await tester.tap(find.text('5').last);
    await tester.pump();
    expect(find.text('오는날'), findsNothing);
    await tester.tap(find.text('2').last);
    await tester.pump();

    expect(find.text('가는날'), findsOneWidget);
    expect(find.text('오는날'), findsOneWidget);
    expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
  });

  testWidgets('기간스타일: 당일치기는 바로, 연차만은 스테퍼 완료 후 다음이 활성화된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('바로 추천받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('아직 안 정했어요'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pump();
    // 전환이 끝나기 전에는 카드 탭이 흡수되므로 화면이 자리잡을 때까지 기다린다
    await tester.pumpAndSettle();

    expect(find.text('어떻게 떠날까요?'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('남은 연차일수 11일'), findsOneWidget); // mock 연차

    // 이전 화면(갈림길)의 '다음'이 트리에 남아있을 수 있어 최상단 것만 조회
    final next = find.widgetWithText(FilledButton, '다음').last;
    expect(tester.widget<FilledButton>(next).onPressed, isNull);

    // 당일치기: 모달 없이 바로 완료
    await tester.tap(find.text('당일치기 · 반차'));
    await tester.pump();
    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);

    // 연차만: 일수 선택 모달에서 완료해야 유지
    // 세 번째 카드는 작은 화면에서 액션 영역 아래로 밀려 있어 스크롤해서 누른다
    await tester.scrollUntilVisible(
      find.text('연차만 (주말 미포함)'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('연차만 (주말 미포함)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 시트 애니메이션
    expect(find.text('평일 연차, 며칠 쓸까요?'), findsOneWidget);
    // 2일·3일 두 버튼 중에서 고른다 (정책: 최소 2일 ~ 최대 2박3일)
    expect(find.text('1박2일'), findsOneWidget);
    expect(find.text('2박3일'), findsOneWidget);
    await tester.tap(find.text('1박2일'));
    await tester.pump();
    await tester.tap(find.text('완료'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
  });

  testWidgets('이동수단 → 일정밀도 → 로딩 → 후보지역까지 위저드가 이어진다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('바로 추천받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('아직 안 정했어요'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('당일치기 · 반차'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // O-05 이동수단
    expect(find.text('어떻게 이동하세요?'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    await tester.tap(find.text('대중교통'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // O-06 일정밀도
    expect(find.text('내가 선호하는 여행 스타일은?'), findsOneWidget);
    expect(find.text('4/4'), findsOneWidget);
    await tester.tap(find.text('널널한 일정'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // O-07 로딩 — 후보지역 화면이 검색 동안 직접 보여준다
    expect(find.textContaining('여행지를 찾고 있어요'), findsOneWidget);

    // 검색(mock 로드)이 끝나면 같은 화면이 결과로 바뀐다
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // O-08 후보지역
    // 개수만 브랜드색으로 강조하느라 한 Text를 조각으로 나눠 담는다
    expect(find.textContaining('조건에 맞는 여행지'), findsOneWidget);
    expect(find.text('정선 · 강원'), findsOneWidget);
    expect(find.text('폐광촌에서 다시 태어난 마을'), findsOneWidget);
    expect(find.text('추천순'), findsOneWidget); // 정렬 칩
    // 카드가 커서 두 번째 후보는 첫 화면 밖에 있다
    await tester.scrollUntilVisible(
      find.text('영월 · 강원'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('영월 · 강원'), findsOneWidget);
    // 다음 단계는 첫 카드에서 이어가므로 되돌려 놓는다
    await tester.scrollUntilVisible(
      find.text('정선 · 강원'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );

    // O-09 코스확정: 정선 카드 탭 → 당일치기 코스 (위저드에서 당일치기 선택했음)
    await tester.tap(find.text('정선 · 강원'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.textContaining('정선, 당일치기'), findsOneWidget);
    // 담기 버튼은 고정이 아니라 목록 끝에 따라오므로 스크롤해야 보인다
    await tester.scrollUntilVisible(
      find.text('내 코스에 담기'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('내 코스에 담기'), findsOneWidget);
    // 장소 리스트는 뷰포트 아래라 스크롤 후 확인
    await tester.scrollUntilVisible(
      find.text('가리왕산자연휴양림'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('가리왕산자연휴양림'), findsOneWidget); // mock 실데이터 코스
    expect(find.text('Day 1'), findsNothing); // 당일치기는 Day 탭 없음
  });

  testWidgets('2박3일 코스는 Day 탭으로 일자별 장소를 전환한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    // 코스 화면 직접 진입 (3일 희망 → 정선 2박3일 코스 매칭)
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push('/course/정선?days=3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 지역·기간만 브랜드색으로 강조하느라 한 Text를 조각으로 나눠 담는다
    expect(find.textContaining('추천코스입니다'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Day 1'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.scrollUntilVisible(
      find.text('가리왕산자연휴양림'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('가리왕산자연휴양림'), findsOneWidget); // Day1 첫 장소

    await tester.scrollUntilVisible(
      find.text('Day 2'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Day 2'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('하이원리조트'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('하이원리조트'), findsOneWidget); // Day2 숙박
    expect(find.text('가리왕산자연휴양림'), findsNothing);
  });

  testWidgets('코스 화면에서 내 코스에 담기를 누르면 내 코스 탭으로 이동한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _serverOverrides, child: const OffwayApp()),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push('/course/정선?days=3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 담기 버튼은 목록 끝에 따라오므로 스크롤해서 누른다
    await tester.scrollUntilVisible(
      find.text('내 코스에 담기'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('내 코스에 담기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 프리셋 경로(날짜 미지정)라 담기 전에 여행 날짜부터 확정한다
    expect(find.text('여행 날짜 선택'), findsOneWidget);
    expect(find.textContaining('날씨예보, 휴무일'), findsOneWidget);
    final done = find.widgetWithText(FilledButton, '선택 완료');
    expect(tester.widget<FilledButton>(done).onPressed, isNull); // 날짜 전엔 비활성

    // 오늘을 시작일로 고르면 코스 길이(3일)만큼 범위가 완성된다
    await tester.tap(find.text('${DateTime.now().day}').first);
    await tester.pump();
    expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
    await tester.tap(done);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 내 코스 목록에 도착 (담기 화면으로 되돌아가지 않는다)
    expect(find.byType(MyCoursesScreen), findsOneWidget);
    expect(find.text('내 코스에 담기'), findsNothing);
    // 전환 중에는 이전·새 Scaffold 양쪽에 토스트가 그려질 수 있어 개수는 세지 않는다
    expect(find.textContaining('내 코스에 담았어요'), findsWidgets);
  });
}
