import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';

/// 내 코스 상세의 D-day 뱃지 — 지난 여행인지는 **종료일**로 가른다.
///
/// 출발일(dDay)로 갈랐을 때는 2박3일의 둘째 날부터 '미방문'이 찍혔다.
/// 목록 카드(`courseCardBadge`)는 종료일 기준이라 같은 코스가 목록에선
/// D-DAY, 상세에선 미방문으로 어긋났다.
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

  final today = DateUtils.dateOnly(DateTime.now());

  testWidgets('여행 중 2일차는 D-DAY 다 — 미방문이 아니다', (tester) async {
    await pump(
      tester,
      start: today.subtract(const Duration(days: 1)),
      end: today.add(const Duration(days: 1)),
    );
    expect(find.text('D-DAY'), findsOneWidget);
    expect(find.text('미방문'), findsNothing);
  });

  testWidgets('출발 전은 D-n', (tester) async {
    await pump(
      tester,
      start: today.add(const Duration(days: 3)),
      end: today.add(const Duration(days: 5)),
    );
    expect(find.text('D-3'), findsOneWidget);
  });

  testWidgets('종료일이 지나면 미방문', (tester) async {
    await pump(
      tester,
      start: today.subtract(const Duration(days: 3)),
      end: today.subtract(const Duration(days: 1)),
    );
    expect(find.text('미방문'), findsOneWidget);
    expect(find.text('D-DAY'), findsNothing);
  });

  testWidgets('종료일이 지나고 다녀왔다고 답했으면 여행완료', (tester) async {
    await pump(
      tester,
      start: today.subtract(const Duration(days: 3)),
      end: today.subtract(const Duration(days: 1)),
      leaveDeducted: true,
    );
    expect(find.text('여행완료'), findsOneWidget);
  });
}
