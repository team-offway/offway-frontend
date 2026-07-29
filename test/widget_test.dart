import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/app/app.dart';
import 'package:offway/features/course/presentation/my_courses_screen.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/my/presentation/my_screen.dart';
import 'package:offway/features/region/presentation/region_list_screen.dart';

/// Keychain 삭제가 실패하는 상황을 재현하는 저장소
class _FailingSecureStoragePlatform extends TestFlutterSecureStoragePlatform {
  _FailingSecureStoragePlatform() : super({});

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => throw Exception('keychain unavailable');
}

void main() {
  setUp(() {
    // Keychain 플러그인은 테스트 환경에 없으므로 인메모리 구현으로 대체
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
  });
  testWidgets('앱 실행 시 로그인 화면이 보인다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('OffWay'), findsOneWidget); // 워드마크 로고
    expect(find.text('연차로 떠나는 로컬 여행'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('Apple로 시작하기'), findsOneWidget);
    expect(find.text('Google로 시작하기'), findsOneWidget);
  });

  testWidgets('소셜 로그인 버튼을 누르면 잔여연차 온보딩으로 이동한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();

    expect(find.text('남은 연차를 입력해 주세요'), findsOneWidget);
  });

  testWidgets('온보딩에서 연차를 조절하고 시작하면 홈으로 이동한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
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
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    // rootBundle 로드(실제 I/O)가 FakeAsync에서 멈추지 않도록 runAsync로 대기
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    // 네트워크 이미지 로드가 있어 pumpAndSettle 대신 유한 pump 사용
    await tester.pump();

    expect(find.text('11일'), findsOneWidget); // mock 잔여연차
    expect(find.textContaining('어디로 떠날까요?'), findsOneWidget);
    expect(find.text('이번달 추천 여행지'), findsOneWidget);
    expect(find.text('정선 · 강원'), findsOneWidget);
    expect(find.text('숙박비 30% 지원'), findsOneWidget);
  });

  testWidgets('하단 탭에서 마이로 이동하고 로그아웃하면 로그인 화면으로 돌아간다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
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

    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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
    await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
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
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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

    // 최신순이 기본이라 나중에 저장한 영월(미확정)이 위에 온다
    expect(inCourses('영월 · 당일치기'), findsOneWidget);
    expect(inCourses('날짜 미정 · 8월경'), findsOneWidget);
    expect(inCourses('정선 · 2박 3일'), findsOneWidget);
    expect(inCourses('7/20(월) – 7/22(수)'), findsOneWidget);

    // 정렬을 바꿔도 두 코스가 그대로 보인다
    await tester.tap(inCourses('최신순'));
    await tester.pump();
    expect(inCourses('오래된순'), findsOneWidget);
    expect(inCourses('정선 · 2박 3일'), findsOneWidget);
  });

  testWidgets('내 코스에서 확정 코스를 열면 날짜와 사용 연차가 보인다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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
    await tester.scrollUntilVisible(
      find.text('정선 · 2박 3일'),
      200,
      scrollable: find.descendant(
        of: find.byType(MyCoursesScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('정선 · 2박 3일'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.textContaining('정선 여행'), findsOneWidget);
    expect(find.text('2026.7.20 - 7.22'), findsOneWidget);
    expect(find.text('사용 연차 일수 2일'), findsOneWidget);
    // 2박3일이라 Day 탭이 3개, 코스 삭제 버튼이 하단에 있다
    expect(find.text('Day 3'), findsOneWidget);
    expect(find.text('코스 삭제하기'), findsOneWidget);
  });

  testWidgets('미확정 코스는 날짜 대신 일정 정하기 링크가 보인다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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

    // 가는날·오는날을 고르면 활성화된다.
    // 다음 달 중순(15·16일)을 쓴다 — 월말에 실행돼도 두 날짜가 같은 달 안에 있고,
    // 한 달 그리드에서 그 숫자는 유일하다. 아래 코스 상세 화면이 트리에 남아
    // 같은 숫자가 또 있을 수 있으므로 화면에 실제로 보이는 셀만 대상으로 한다
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
    await tester.tap(find.text('16').hitTestable());
    await tester.pump();
    expect(find.text('가는날'), findsOneWidget);
    expect(find.text('오는날'), findsOneWidget);
    expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
  });

  testWidgets('하단 탭 전환은 좌우 슬라이드 없이 한 프레임에 끝난다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('더보기'));
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

    // 목록 화면: 헤더 + mock 5개 지역
    expect(inList('이번달 추천 여행지'), findsOneWidget);
    expect(inList('정선 · 강원'), findsOneWidget);
    // 마지막 지역은 뷰포트 아래라 스크롤해서 확인
    await tester.scrollUntilVisible(
      inList('영양 · 경북'),
      200,
      scrollable: find.descendant(
        of: find.byType(RegionListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(inList('영양 · 경북'), findsOneWidget);

    // 카테고리 필터는 지역별 콘텐츠 분포(실데이터) 기준으로 동작.
    // 위에서 스크롤을 내렸으니 카테고리 줄이 다시 보이도록 올린다
    await tester.scrollUntilVisible(
      inList('체험'),
      -200,
      scrollable: find.descendant(
        of: find.byType(RegionListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(inList('체험'));
    await tester.pump();
    expect(inList('정선 · 강원'), findsOneWidget); // 체험 11건
  });

  testWidgets('홈에서 지역 카드를 누르면 지역 상세로 이동한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 지역 카드는 뷰포트 아래라 스크롤해서 올린 뒤 탭
    await tester.scrollUntilVisible(
      find.text('정선 · 강원'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('정선 · 강원'));
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
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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

    // 연차만: 스테퍼 모달에서 완료해야 유지
    await tester.tap(find.text('연차만 (주말 미포함)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 시트 애니메이션
    expect(find.text('연차를 얼마나 사용할까요?'), findsOneWidget);
    expect(find.text('3일(2박3일)'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('2일(1박2일)'), findsOneWidget);
    // 정책: 최소 2일 — 더 줄어들지 않음
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('2일(1박2일)'), findsOneWidget);
    await tester.tap(find.text('완료'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
  });

  testWidgets('이동수단 → 일정밀도 → 로딩 → 후보지역까지 위저드가 이어진다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Google로 시작하기'),
    ); // 카카오·Apple은 실제 SDK 호출이라 stub인 구글로 진입
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
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
    expect(find.text('내가 선호하는 스타일은?'), findsOneWidget);
    expect(find.text('4/4'), findsOneWidget);
    await tester.tap(find.text('널널한 일정'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // O-07 로딩
    expect(find.textContaining('여행지를 찾고 있어요'), findsOneWidget);

    // 2초 후 후보지역 자동 이동 (mock 로드는 실제 비동기로 대기)
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // O-08 후보지역
    expect(find.textContaining('여행지 2곳을 찾았어요'), findsOneWidget);
    expect(find.text('정선 · 강원'), findsOneWidget);
    expect(find.text('추천1위'), findsOneWidget);
    expect(find.text('영월 · 강원'), findsOneWidget);
    expect(find.textContaining('2시간30분'), findsOneWidget); // 정선 150분

    // O-09 코스확정: 정선 카드 탭 → 당일치기 코스 (위저드에서 당일치기 선택했음)
    await tester.tap(find.text('정선 · 강원'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.textContaining('정선, 당일치기'), findsOneWidget);
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
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
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

    expect(find.textContaining('정선, 2박 3일'), findsOneWidget);
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
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push('/course/정선?days=3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    await tester.tap(find.text('내 코스에 담기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    // 내 코스 목록에 도착 (담기 화면으로 되돌아가지 않는다)
    expect(find.byType(MyCoursesScreen), findsOneWidget);
    expect(find.text('내 코스에 담기'), findsNothing);
    // 아직 실제로 담기지는 않으므로 담긴 것으로 오해하지 않도록 안내가 보인다
    expect(find.textContaining('코스 담기는 준비 중'), findsOneWidget);
  });
}
