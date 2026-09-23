import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';
import 'package:offway/features/course/application/course_providers.dart';
import 'package:offway/features/leave/data/consumed_leave_provider.dart';

/// 코스 상세의 '사용 연차' 뱃지 — **상세에 실려 온 값이 먼저다**(core #322).
///
/// 차감한 코스는 서버가 확정한 차감량이 상세 응답에 들어 있다. 그걸 두고
/// `POST /leaves/available-time` 을 다시 부르면 화면에 들어올 때마다 한 건씩
/// 더 나간다(#314). 공유 이미지 경로는 원래 이 규칙이었는데 화면에 늘 보이는
/// 뱃지만 빠져 있었다.
void main() {
  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final today = DateUtils.dateOnly(DateTime.now());
  final start = today.add(const Duration(days: 3));
  final end = today.add(const Duration(days: 5));

  /// [consumedLeaveDays] 를 상세에 실어 띄운다. 서버가 실제로 불렸는지
  /// [fetched] 로 돌려준다
  Future<bool> pump(
    WidgetTester tester, {
    required double? consumedLeaveDays,
    double served = 2,
  }) async {
    var fetched = false;
    tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripConsumedLeaveProvider.overrideWith((ref, arg) async {
            fetched = true;
            return served;
          }),
          savedCourseDetailProvider('1').overrideWith(
            (ref) async => (
              saved: {
                'id': '1',
                'regionName': '정선군',
                'travelDate': iso(start),
                'startDate': iso(start),
                'endDate': iso(end),
                'shareToken': 'abc',
                'leaveDeducted': consumedLeaveDays != null,
                'consumedLeaveDays': ?consumedLeaveDays,
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
    return fetched;
  }

  testWidgets('상세에 차감량이 있으면 서버에 다시 묻지 않는다', (tester) async {
    final fetched = await pump(tester, consumedLeaveDays: 4);

    expect(find.text('사용 연차 일수 4일'), findsOneWidget);
    expect(fetched, isFalse, reason: '이미 받아 둔 차감량을 두고 available-time 을 불렀다');
  });

  testWidgets('상세에 없으면 그때만 서버에 묻는다', (tester) async {
    // 아직 차감 전인 코스는 상세에 값이 없다 — 예상 차감량을 서버가 센다
    final fetched = await pump(tester, consumedLeaveDays: null, served: 2);

    expect(fetched, isTrue);
    expect(find.text('사용 연차 일수 2일'), findsOneWidget);
  });

  testWidgets('상세 값이 서버 계산보다 우선한다', (tester) async {
    // 둘이 다를 수 있다 — 공휴일이 나중에 바뀌었거나 사용자가 날짜를 고쳤을 때.
    // 확정된 것은 서버가 차감할 때 적어 준 값이다
    await pump(tester, consumedLeaveDays: 4, served: 2);

    expect(find.text('사용 연차 일수 4일'), findsOneWidget);
    expect(find.text('사용 연차 일수 2일'), findsNothing);
  });
}
