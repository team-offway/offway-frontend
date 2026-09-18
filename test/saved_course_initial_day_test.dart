import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';

/// 위젯·잠금화면에서 들어오면 **보여 주던 일자**가 열린다(#338).
///
/// 카드가 '2일차' 라고 적어 놓고 눌렀더니 1일차가 열리면, 방금 본 날을
/// 다시 찾아 눌러야 한다. 딥링크가 `?day=2` 를 싣고 이 화면이 그걸 받는다.
void main() {
  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final today = DateUtils.dateOnly(DateTime.now());

  /// 하루에 한 곳씩, 2박3일 코스 — 장소 이름으로 어느 날인지 안다
  final courseOverride = savedCourseDetailProvider('1').overrideWith(
    (ref) async => (
      saved: {
        'id': '1',
        'regionName': '정선군',
        'travelDate': iso(today),
        'startDate': iso(today),
        'endDate': iso(today.add(const Duration(days: 2))),
        'shareToken': 'abc',
        'leaveDeducted': false,
        'consumedLeaveDays': 3.0,
      },
      course: {
        'regionName': '정선군',
        'durationDays': 3,
        'travelDate': iso(today),
        'days': [
          for (var i = 0; i < 3; i++)
            {
              'day': i + 1,
              'date': iso(today.add(Duration(days: i))),
              'dayOfWeek': '월',
              'places': [
                {
                  'name': '${i + 1}일차장소',
                  'category': '관광지',
                  'kind': 'SIGHT',
                  'poiContentId': '10$i',
                },
              ],
            },
        ],
      },
    ),
  );

  void sizeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(WidgetTester tester, {int? initialDay}) async {
    sizeScreen(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [courseOverride],
        child: MaterialApp(
          theme: AppTheme.light,
          home: SavedCourseScreen(savedId: '1', initialDay: initialDay),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('일자를 주면 그 날이 열린다 — 방금 본 날을 다시 찾지 않게', (tester) async {
    await pump(tester, initialDay: 2);

    expect(find.text('2일차장소'), findsOneWidget);
    expect(find.text('1일차장소'), findsNothing);
  });

  testWidgets('일자가 없으면 첫날이다 — 출발 전에는 며칠째가 없다', (tester) async {
    await pump(tester);

    expect(find.text('1일차장소'), findsOneWidget);
  });

  testWidgets('열어 둔 화면에 다른 일자가 오면 따라간다', (tester) async {
    // 코스 상세를 보고 있는데 위젯을 누르면 `go` 로 같은 경로에 쿼리만
    // 바뀌어 들어온다. go_router 가 화면을 새로 만들지 않아, 받지 않으면
    // 2일차를 눌러도 1일차가 남는다
    sizeScreen(tester);
    final router = GoRouter(
      initialLocation: AppRoutes.savedCoursePath('1'),
      routes: [
        GoRoute(
          path: AppRoutes.savedCourse,
          builder: (context, state) => SavedCourseScreen(
            savedId: state.pathParameters['savedId']!,
            initialDay: int.tryParse(state.uri.queryParameters['day'] ?? ''),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [courseOverride],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1일차장소'), findsOneWidget);

    router.go(AppRoutes.savedCoursePath('1', day: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2일차장소'), findsOneWidget);
    expect(find.text('1일차장소'), findsNothing);
  });

  testWidgets('코스 길이를 넘는 일자는 첫날로 되돌린다 — 탭도 함께', (tester) async {
    // 코스를 줄여 담고 나서 옛 위젯을 누르면 없는 날이 올 수 있다.
    // 본문만 첫날로 떨어지고 탭은 아무 데도 안 켜지면 화면이 어긋난다
    await pump(tester, initialDay: 4);

    expect(find.text('1일차장소'), findsOneWidget);
    // 고른 날은 반전(글자가 inverseLabel)이다 — Day 1 이 켜져 있어야 한다
    expect(
      tester.widget<Text>(find.text('Day 1')).style?.color,
      AppColors.inverseLabel,
      reason: '본문은 첫날인데 탭은 아무것도 안 켜졌다',
    );
  });
}
