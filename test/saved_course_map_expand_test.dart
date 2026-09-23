import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';
import 'package:offway/features/course/presentation/widgets/course_map.dart';
import 'package:offway/features/course/application/course_providers.dart';

/// 내 코스 상세의 지도는 펼치고 접어도 **같은 지도**여야 한다(#363).
///
/// 펼칠 때만 감싸는 위젯을 벗겨 트리 모양이 바뀌면, 아래가 통째로 버려져
/// 네이버 지도가 새로 만들어지고 마커를 다시 그렸다 — 탭할 때마다 깜빡였다.
void main() {
  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> pump(
    WidgetTester tester, {
    required DateTime start,
    required DateTime end,
    bool leaveDeducted = false,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedCourseDetailProvider('1').overrideWith(
            (ref) async => (
              saved: {
                'id': '1',
                'regionName': '정선군',
                'travelDate': iso(start),
                'startDate': iso(start),
                'endDate': iso(end),
                'shareToken': 'abc',
                'leaveDeducted': leaveDeducted,
              },
              course: {
                'regionName': '정선군',
                'durationDays': 3,
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
            ),
          ),
        ],
        child: const MaterialApp(home: SavedCourseScreen(savedId: '1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('지도를 펼치고 접어도 지도 element 가 그대로다', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    await pump(
      tester,
      start: today.add(const Duration(days: 3)),
      end: today.add(const Duration(days: 5)),
    );

    final before = tester.element(find.byType(CourseMap));

    await tester.tap(find.byType(CourseMap), warnIfMissed: false);
    await tester.pump();
    expect(find.bySemanticsLabel('지도 접기'), findsOneWidget);
    expect(identical(tester.element(find.byType(CourseMap)), before), isTrue);

    await tester.tap(find.bySemanticsLabel('지도 접기'));
    await tester.pump();
    expect(identical(tester.element(find.byType(CourseMap)), before), isTrue);
  });
}
