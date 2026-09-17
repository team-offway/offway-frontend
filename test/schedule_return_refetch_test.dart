import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';

/// 일정 화면을 다녀와도 코스 상세를 **한 번만** 다시 읽는다(#316).
///
/// 예전에는 자식(일정 화면)이 저장 성공 시 무효화하고, 부모(코스 상세)도
/// 돌아오면 무조건 무효화해 같은 `GET /courses/{id}` 가 두 번 나갔다.
/// 날짜를 안 바꾸고 뒤로만 나와도 한 번 나갔다.
///
/// **실제 진입점을 눌러 이동한다.** 라우터를 직접 밀면 부모의 `onTap` 이
/// 아예 안 돌아, 부모가 무효화를 하든 말든 테스트가 통과해 버린다.
void main() {
  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final start = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 3));

  /// 코스 상세를 띄우고, 편집 시트로 일정 화면을 다녀온다.
  ///
  /// [changeDate] 가 참이면 그 화면이 날짜를 바꾼 것처럼 무효화한다 —
  /// 실제 `CourseScheduleScreen._submit` 이 하는 일과 같다.
  /// 상세를 서버에서 읽은 횟수를 돌려준다
  Future<int> pumpAndReturn(
    WidgetTester tester, {
    required bool changeDate,
  }) async {
    var calls = 0;
    tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SavedCourseScreen(savedId: '1'),
        ),
        // 실제 경로에 가짜 일정 화면을 건다 — 부모는 이 주소로 push 한다
        GoRoute(
          path: AppRoutes.courseSchedule,
          builder: (_, _) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    // 날짜를 바꾼 경우에만 자식이 무효화한다
                    if (changeDate) {
                      ref.invalidate(savedCourseDetailProvider('1'));
                    }
                    context.pop();
                  },
                  child: const Text('닫기'),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedCourseDetailProvider('1').overrideWith((ref) async {
            calls++;
            return (
              saved: {
                'id': '1',
                'regionName': '정선군',
                'travelDate': iso(start),
                'startDate': iso(start),
                'endDate': iso(start.add(const Duration(days: 1))),
                'shareToken': 'abc',
                'leaveDeducted': false,
                'consumedLeaveDays': 2.0,
              },
              course: {
                'regionName': '정선군',
                'durationDays': 2,
                'travelDate': iso(start),
                'days': [
                  {
                    'day': 1,
                    'date': iso(start),
                    'dayOfWeek': '월',
                    'places': <Map<String, dynamic>>[],
                  },
                ],
              },
            );
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1, reason: '첫 진입에 한 번 읽는다');

    // 편집 → 여행날짜 수정 — 사용자가 실제로 가는 길이다
    await tester.tap(find.bySemanticsLabel('코스 편집'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('여행날짜 수정'));
    await tester.pumpAndSettle();

    expect(find.text('닫기'), findsOneWidget, reason: '일정 화면으로 갔어야 한다');
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    return calls;
  }

  testWidgets('날짜를 안 바꾸고 돌아오면 다시 읽지 않는다', (tester) async {
    final calls = await pumpAndReturn(tester, changeDate: false);

    expect(calls, 1, reason: '바뀐 게 없는데 상세를 다시 읽었다');
  });

  testWidgets('날짜를 바꾸면 한 번만 다시 읽는다 — 두 번이 아니다', (tester) async {
    final calls = await pumpAndReturn(tester, changeDate: true);

    expect(calls, 2, reason: '부모와 자식이 모두 무효화해 두 번 읽고 있다');
  });
}
