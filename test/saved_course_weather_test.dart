import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';
import 'package:offway/features/leave/data/consumed_leave_provider.dart';
import 'package:offway/features/course/application/course_providers.dart';

/// 내 코스 상세의 일차별 날씨 — **그 일차의 날짜**로 가른다(#388).
///
/// 출발일까지 남은 날로만 봤을 때는 여행 둘째 날부터 "다녀온 여행" 이 되어
/// 오늘 탭의 날씨까지 사라졌다.
void main() {
  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> pump(
    WidgetTester tester, {
    required DateTime start,
    required DateTime end,
    bool leaveDeducted = false,
    int initialDay = 1,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 연차 계산은 서버를 부른다 — 값이 늘 있게 고정한다
          tripConsumedLeaveProvider.overrideWith((ref, range) async => 2.0),
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
                  for (var i = 0; i < 3; i++)
                    {
                      'day': i + 1,
                      'date': iso(start.add(Duration(days: i))),
                      'dayOfWeek': '월',
                      'weather': {'sky': '맑음', 'maxTemp': 21, 'minTemp': 12},
                      'places': <Map<String, dynamic>>[],
                    },
                ],
              },
            ),
          ),
        ],
        child: MaterialApp(
          home: SavedCourseScreen(savedId: '1', initialDay: initialDay),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  int weatherChips() => find
      .byWidgetPredicate((w) => w.runtimeType.toString() == '_WeatherChip')
      .evaluate()
      .length;
  final today = DateUtils.dateOnly(DateTime.now());

  testWidgets('여행 중 오늘(2일차) 탭에 날씨가 뜬다', (tester) async {
    await pump(
      tester,
      start: today.subtract(const Duration(days: 1)),
      end: today.add(const Duration(days: 1)),
      initialDay: 2,
    );
    expect(weatherChips(), 1);
  });

  testWidgets('여행 중 내일(3일차) 탭에도 날씨가 뜬다', (tester) async {
    await pump(
      tester,
      start: today.subtract(const Duration(days: 1)),
      end: today.add(const Duration(days: 1)),
      initialDay: 3,
    );
    expect(weatherChips(), 1);
  });

  testWidgets('여행 중 지난 일차(1일차) 탭에는 날씨가 없다', (tester) async {
    await pump(
      tester,
      start: today.subtract(const Duration(days: 1)),
      end: today.add(const Duration(days: 1)),
    );
    expect(weatherChips(), 0);
  });

  testWidgets('출발 전 여행은 그대로 날씨가 뜬다', (tester) async {
    await pump(
      tester,
      start: today.add(const Duration(days: 2)),
      end: today.add(const Duration(days: 4)),
    );
    expect(weatherChips(), 1);
  });

  testWidgets('다녀온 여행에는 날씨가 없다', (tester) async {
    await pump(
      tester,
      start: today.subtract(const Duration(days: 4)),
      end: today.subtract(const Duration(days: 2)),
    );
    expect(weatherChips(), 0);
  });
}
