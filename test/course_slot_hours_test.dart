import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/data/course_repository.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';
import 'package:offway/features/course/presentation/widgets/place_info_sheet.dart';
import 'package:offway/features/course/application/course_providers.dart';

/// 정해진 응답만 돌려주는 어댑터 — 파싱을 실제로 태워 보려는 것이다
class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// 여행 당일 운영 안내는 **코스 응답에 실려 온 값**으로 그린다(#326).
///
/// 서버 `CourseResponse` 가 슬롯마다 `useTime`·`restDate` 를 싣는데 앱이 그걸
/// 버리고 장소마다 `GET /pois/{id}` 를 따로 받았다. 하루 6~8곳이면 그만큼이다.
void main() {
  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 오늘이 여행일이어야 운영 안내가 나온다
  final today = DateUtils.dateOnly(DateTime.now());

  /// 장소 하나짜리 당일 코스를 띄운다.
  ///
  /// [served] 가 참이면 코스 응답에 운영시간이 실린다. 장소 상세가 실제로
  /// 불렸는지 돌려준다
  Future<bool> pump(WidgetTester tester, {required bool served}) async {
    var fetched = false;
    tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiScheduleProvider('126508').overrideWith((ref) async {
            fetched = true;
            // 상세로 물러났을 때 나올 값 — 코스 응답 값과 구분되게 둔다
            return (useTime: '10:00 - 17:00', restDate: null);
          }),
          savedCourseDetailProvider('1').overrideWith(
            (ref) async => (
              saved: {
                'id': '1',
                'regionName': '정선군',
                'travelDate': iso(today),
                'startDate': iso(today),
                'endDate': iso(today),
                'shareToken': 'abc',
                'leaveDeducted': false,
                'consumedLeaveDays': 1.0,
              },
              course: {
                'regionName': '정선군',
                'durationDays': 1,
                'travelDate': iso(today),
                'days': [
                  {
                    'day': 1,
                    'date': iso(today),
                    'dayOfWeek': '월',
                    'places': [
                      {
                        'name': '삼탄아트마인',
                        'category': '관광지',
                        'kind': 'SIGHT',
                        'poiContentId': '126508',
                        // 코스 응답이 싣는 자리 — 없으면 키가 아예 안 온다
                        if (served) 'useTime': '09:00 - 18:00',
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
    return fetched;
  }

  testWidgets('코스 응답에 운영시간이 있으면 장소 상세를 부르지 않는다', (tester) async {
    final fetched = await pump(tester, served: true);

    expect(find.text('삼탄아트마인'), findsOneWidget);
    // 상시 개방이 아닌 운영시간이라 안내가 뜬다
    expect(find.text('운영시간 확인'), findsOneWidget);
    expect(fetched, isFalse, reason: '이미 받아 둔 운영시간을 두고 장소 상세를 다시 불렀다');
  });

  testWidgets('코스 응답에 없으면 그때만 장소 상세로 물러난다', (tester) async {
    // 옛 응답이거나 서버가 아직 운영시간을 못 받은 장소다
    final fetched = await pump(tester, served: false);

    expect(fetched, isTrue);
    expect(find.text('운영시간 확인'), findsOneWidget);
  });

  testWidgets('시트도 같은 값을 쓴다 — 눌러도 상세를 부르지 않는다', (tester) async {
    // 행 배지만 고치고 시트를 놓치면, 같은 장소인데 배지와 시트가 다른
    // 문구를 보인다. 둘이 같은 함수를 쓰는지 여기서 잠근다(#330)
    var fetched = false;
    tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiScheduleProvider('126508').overrideWith((ref) async {
            fetched = true;
            return (useTime: '상세에서 온 값', restDate: null);
          }),
          savedCourseDetailProvider('1').overrideWith(
            (ref) async => (
              saved: {
                'id': '1',
                'regionName': '정선군',
                'travelDate': iso(today),
                'startDate': iso(today),
                'endDate': iso(today),
                'shareToken': 'abc',
                'leaveDeducted': false,
                'consumedLeaveDays': 1.0,
              },
              course: {
                'regionName': '정선군',
                'durationDays': 1,
                'travelDate': iso(today),
                'days': [
                  {
                    'day': 1,
                    'date': iso(today),
                    'dayOfWeek': '월',
                    'places': [
                      {
                        'name': '삼탄아트마인',
                        'category': '관광지',
                        'kind': 'SIGHT',
                        'poiContentId': '126508',
                        'useTime': '09:00 - 18:00',
                        'restDate': '매주 월요일',
                        // 서버가 영업 중으로 판정 — 원문 파싱(시각 비교)에
                        // 기대지 않게 해 테스트가 시각에 흔들리지 않는다
                        'openingStatus': 'OPEN',
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

    // 장소를 눌러 시트를 연다
    await tester.tap(find.text('삼탄아트마인'));
    await tester.pumpAndSettle();

    // 코스 응답 값이 뜬다 — 상세에서 온 값이 아니다
    expect(find.text('09:00 - 18:00'), findsOneWidget);
    expect(find.text('상세에서 온 값'), findsNothing);
    expect(fetched, isFalse, reason: '시트가 이미 받아 둔 값을 두고 상세를 불렀다');
  });

  group('응답 파싱', () {
    /// 서버가 실제로 내려주는 모양 — `CourseResponse` 의 슬롯에 운영 정보가
    /// 함께 실린다. 값이 없는 장소는 키가 아예 안 온다(NON_NULL)
    Map<String, dynamic> body({
      required bool withHours,
      String useTime = '09:00 - 18:00',
      String restDate = '매주 월요일',
    }) => {
      'status': 200,
      'data': {
        'courseId': 1,
        'regionId': 15,
        'regionName': '정선군',
        'travelDays': 1,
        'travelDate': iso(today),
        'density': 'PACKED',
        'transport': 'CAR',
        'days': [
          {
            'day': 1,
            'date': iso(today),
            'dayOfWeek': '월',
            'items': [
              {
                'title': '삼탄아트마인',
                'categoryLabel': '관광지',
                'kind': 'SIGHT',
                'poiContentId': '126508',
                if (withHours) ...{
                  'useTime': useTime,
                  'restDate': restDate,
                  'openingStatus': 'CLOSED_TODAY',
                },
              },
            ],
          },
        ],
        'benefits': <Map<String, dynamic>>[],
      },
      'detail': '요청이 정상 처리되었습니다.',
      'code': 'OK',
      'pageResponse': null,
    };

    CourseRepository repositoryFor({
      required bool withHours,
      String useTime = '09:00 - 18:00',
      String restDate = '매주 월요일',
    }) => CourseRepository(
      Dio(BaseOptions())
        ..httpClientAdapter = _FixedResponseAdapter(
          body(withHours: withHours, useTime: useTime, restDate: restDate),
        ),
    );

    /// 첫 장소 하나를 꺼낸다
    Future<Map<String, dynamic>> firstPlace(CourseRepository r) async {
      final detail = await r.savedCourseDetail('1');
      return (((detail!.course['days'] as List).first
                      as Map<String, dynamic>)['places']
                  as List)
              .first
          as Map<String, dynamic>;
    }

    test('코스 응답의 운영 정보를 장소에 담는다', () async {
      // 서버가 보내는데 파싱에서 버리면 화면이 쓸 방법이 없다 — 예전이 그랬다
      final detail = await repositoryFor(
        withHours: true,
      ).savedCourseDetail('1');
      final place =
          ((detail!.course['days'] as List).first
                  as Map<String, dynamic>)['places']
              as List;
      final first = place.first as Map<String, dynamic>;

      expect(first['useTime'], '09:00 - 18:00');
      expect(first['restDate'], '매주 월요일');
      expect(first['openingStatus'], 'CLOSED_TODAY');
    });

    test('빈 문자열·공백은 값으로 치지 않는다 — 상세로 물러날 수 있어야 한다', () async {
      // 서버가 최상위를 `""` 로 채워 보내는 일이 실제로 있었다
      // (`poiScheduleOf` 주석). 키가 남으면 화면이 "값이 있다" 로 보고
      // 상세로 물러나지 않는데, 그 빈 값으로는 안내를 못 만든다 —
      // 휴무일인데 배지가 사라진다(#329)
      final first = await firstPlace(
        repositoryFor(withHours: true, useTime: '', restDate: '   '),
      );

      expect(first.containsKey('useTime'), isFalse);
      expect(first.containsKey('restDate'), isFalse);
    });

    test('연속 빈 줄은 접는다 — 장소 상세와 같은 규칙', () async {
      final first = await firstPlace(
        repositoryFor(
          withHours: true,
          useTime: '- 3월~10월 09:00\n\n\n- 11월~2월 10:00',
        ),
      );

      expect(first['useTime'], '- 3월~10월 09:00\n- 11월~2월 10:00');
    });

    test('없는 장소는 키를 만들지 않는다', () async {
      // null 로 채우면 화면이 "값이 있다" 와 구분하지 못해 상세로 물러나지 않는다
      final detail = await repositoryFor(
        withHours: false,
      ).savedCourseDetail('1');
      final place =
          ((detail!.course['days'] as List).first
                  as Map<String, dynamic>)['places']
              as List;
      final first = place.first as Map<String, dynamic>;

      expect(first.containsKey('useTime'), isFalse);
      expect(first.containsKey('restDate'), isFalse);
    });
  });
}
