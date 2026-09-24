import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';
import 'package:offway/features/course/presentation/widgets/place_info_sheet.dart';
import 'package:offway/features/course/application/course_providers.dart';

/// 오늘 문 여는지는 **서버 판정을 쓴다**(#331).
///
/// 앱이 원문을 뜯어 요일을 맞추던 방식은 `매주 월요일 (단, 공휴일인 경우 …)`
/// 같은 값에서 틀렸다 — 여는 곳을 닫혔다고 말했다.
void main() {
  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final today = DateUtils.dateOnly(DateTime.now());
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final todayLabel = weekdays[DateTime.now().weekday - 1];

  /// 여행 당일 코스 상세를 띄운다.
  ///
  /// [status] 는 서버가 보낸 코드값, [restDate] 는 원문이다
  Future<void> pump(
    WidgetTester tester, {
    String? status,
    String? useTime = '09:00~18:00',
    String? restDate,

    /// 출발일을 오늘에서 며칠 옮길지 — 음수면 이미 떠난 여행이다
    int startOffset = 0,
    int endOffset = 0,
  }) async {
    final start = today.add(Duration(days: startOffset));
    final end = today.add(Duration(days: endOffset));
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
                'leaveDeducted': false,
                'consumedLeaveDays': 1.0,
              },
              course: {
                'regionName': '정선군',
                'durationDays': endOffset - startOffset + 1,
                'travelDate': iso(start),
                'days': [
                  for (var i = 0; i <= endOffset - startOffset; i++)
                    {
                      'day': i + 1,
                      'date': iso(start.add(Duration(days: i))),
                      'dayOfWeek': '월',
                      'places': [
                        {
                          'name': i == 0 ? '삼탄아트마인' : '${i + 1}일차장소',
                          'category': '관광지',
                          'kind': 'SIGHT',
                          'poiContentId': '126508',
                          'useTime': ?useTime,
                          'restDate': ?restDate,
                          'openingStatus': ?status,
                        },
                      ],
                    },
                ],
              },
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SavedCourseScreen(savedId: '1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('목록 배지', () {
    testWidgets('서버가 휴무로 판정하면 휴무일', (tester) async {
      await pump(tester, status: 'CLOSED_TODAY');
      expect(find.text('휴무일'), findsOneWidget);
    });

    testWidgets('아직 안 열었거나 이미 닫혔으면 운영시간 확인 — 배지는 두 마디만 쓴다', (tester) async {
      await pump(tester, status: 'BEFORE_OPEN');
      expect(find.text('운영시간 확인'), findsOneWidget);
      expect(find.text('아직 문을 열기 전이에요'), findsNothing);

      await pump(tester, status: 'CLOSED_NOW');
      expect(find.text('운영시간 확인'), findsOneWidget);
    });

    testWidgets('공휴일 예외를 서버가 읽으면 휴무 배지가 안 뜬다', (tester) async {
      // **이것이 이 변경의 값어치다.** 원문에는 오늘 요일이 들어 있지만
      // 괄호 안 예외 때문에 실제로는 연다 — 앱의 요일 매칭은 여기서 틀렸다
      await pump(
        tester,
        status: 'OPEN',
        restDate: '매주 $todayLabel요일 (단, 공휴일인 경우 그 다음 공휴일이 아닌 날 휴관)',
      );

      expect(find.text('휴무일'), findsNothing);
      // 영업 중이므로 아무 배지도 안 뜬다
      expect(find.text('운영시간 확인'), findsNothing);
    });

    testWidgets('영업 중이면 배지를 띄우지 않는다', (tester) async {
      // 여는 시간이 적혀 있다는 이유만으로 뜨던 예전 규칙은 문 연 곳까지
      // 붉게 표시했다 — 무엇을 확인하라는 것인지 알 수 없었다
      await pump(tester, status: 'OPEN');

      expect(find.text('운영시간 확인'), findsNothing);
      expect(find.text('휴무일'), findsNothing);
    });

    testWidgets('서버 판정이 없으면 예전처럼 원문을 본다', (tester) async {
      // 여행일이 오늘이 아니면 서버가 안 싣는다 — 그때 판정이 사라지면 안 된다
      await pump(tester, restDate: '매주 $todayLabel요일');
      expect(find.text('휴무일'), findsOneWidget);
    });
  });

  group('언제 뜨는가', () {
    testWidgets('오늘에 해당하는 날 탭에서 뜬다 — 출발일만 보던 것을 고쳤다', (tester) async {
      // 2박3일 코스에서 어제 떠나 오늘이 2일차다. 예전에는 출발일 하루만
      // 봐서(`dDay == 0`) 정작 오늘 갈 곳의 휴무를 몰랐다
      await pump(tester, status: 'CLOSED_TODAY', startOffset: -1, endOffset: 1);

      // 기본은 Day 1(어제) — 지나간 날이라 안 뜬다
      expect(find.text('휴무일'), findsNothing);

      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();
      expect(find.text('휴무일'), findsOneWidget);
    });

    testWidgets('지나간 날 탭에는 오늘 기준 안내가 안 붙는다', (tester) async {
      // 3일차가 오늘인데 1일차 탭을 열면, 이미 지나간 날의 장소에
      // '오늘은 휴무일이에요' 가 뜨면 안 된다 — 서버 판정은 장소 단위로
      // 실려 와 어느 날 탭에서든 같은 값이다
      await pump(tester, status: 'CLOSED_TODAY', startOffset: -2, endOffset: 0);

      expect(find.text('휴무일'), findsNothing);

      await tester.tap(find.text('Day 3'));
      await tester.pumpAndSettle();
      expect(find.text('휴무일'), findsOneWidget);
    });

    testWidgets('아직 안 떠난 여행에는 안 뜬다', (tester) async {
      await pump(tester, status: 'CLOSED_TODAY', startOffset: 3, endOffset: 5);

      expect(find.text('휴무일'), findsNothing);
    });

    testWidgets('이미 끝난 여행에도 안 뜬다', (tester) async {
      await pump(
        tester,
        status: 'CLOSED_TODAY',
        startOffset: -5,
        endOffset: -3,
      );

      expect(find.text('휴무일'), findsNothing);
    });
  });

  group('장소 시트', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('삼탄아트마인'));
      await tester.pumpAndSettle();
    }

    testWidgets('서버 문구를 그대로 보여준다', (tester) async {
      await pump(tester, status: 'CLOSED_TODAY');
      await openSheet(tester);
      expect(find.text('오늘은 휴무일이에요'), findsOneWidget);
    });

    testWidgets('아직 문을 열기 전 — 새로 생긴 문구', (tester) async {
      await pump(tester, status: 'BEFORE_OPEN');
      await openSheet(tester);
      expect(find.text('아직 문을 열기 전이에요'), findsOneWidget);
    });

    testWidgets('운영이 끝났으면 운영시간 칸에 뜬다', (tester) async {
      await pump(tester, status: 'CLOSED_NOW');
      await openSheet(tester);
      expect(find.text('오늘 운영이 끝났어요'), findsOneWidget);
    });

    testWidgets('영업 중이면 원문을 그대로 둔다', (tester) async {
      await pump(tester, status: 'OPEN', useTime: '09:00~18:00');
      await openSheet(tester);
      expect(find.text('09:00~18:00'), findsOneWidget);
      expect(find.text('오늘 운영이 끝났어요'), findsNothing);
    });
  });

  test('코드값을 판정으로 옮긴다 — UNKNOWN 만 버린다', () {
    expect(
      todayOpeningOf({'openingStatus': 'CLOSED_TODAY'}),
      TodayOpening.closedToday,
    );
    expect(
      todayOpeningOf({'openingStatus': 'CLOSED_NOW'}),
      TodayOpening.closedNow,
    );
    expect(
      todayOpeningOf({'openingStatus': 'BEFORE_OPEN'}),
      TodayOpening.beforeOpen,
    );
    // **버리지 않는다.** 버리면 "판정했고 문제없음" 과 "판정 없음" 이
    // 구분되지 않아 원문 폴백이 돌고, 서버가 읽은 예외를 앱이 도로 무시한다
    expect(todayOpeningOf({'openingStatus': 'OPEN'}), TodayOpening.open);
    expect(TodayOpening.open.message, isNull, reason: '알릴 말은 없다');
    // 서버가 아예 안 내려보낸다
    expect(todayOpeningOf({'openingStatus': 'UNKNOWN'}), isNull);
    expect(todayOpeningOf({}), isNull);
  });
}
