import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/presentation/course_screen.dart';
import 'package:offway/features/course/presentation/widgets/place_info_sheet.dart';

/// 코스 확정에서 장소를 누르면 **담은 뒤 화면과 같은 운영 정보 시트**가
/// 뜬다 (QA 9/11).
///
/// 예전에는 여기서만 바로 장소 상세로 넘어가, 같은 코스를 담기 전후로 다르게
/// 동작했다.
void main() {
  Map<String, dynamic> course() => {
    'regionName': '예산군',
    'durationDays': 1,
    'travelDate': '2026-09-20',
    'days': [
      {
        'day': 1,
        'date': '2026-09-20',
        'dayOfWeek': '일',
        'places': [
          {
            'name': '예산시장',
            'category': '관광',
            'kind': 'SIGHT',
            'poiContentId': '126508',
            'catchphrase': '예산 지역을 대표하는 재래시장',
          },
        ],
      },
    ],
  };

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseProvider((
            regionId: '4',
            desiredDays: 1,
          )).overrideWith((ref) async => course()),
          poiScheduleProvider('126508').overrideWith(
            (ref) async => (useTime: '09:00 ~ 18:00', restDate: '매주 월요일'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CourseScreen(regionId: '4', desiredDays: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('장소를 누르면 운영 정보 시트가 뜬다 — 바로 상세로 넘어가지 않는다', (tester) async {
    await pump(tester);

    expect(find.byType(PlaceInfoSheet), findsNothing);

    await tester.tap(find.text('예산시장'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceInfoSheet), findsOneWidget);
    // 시트가 운영시간·휴무일을 채운다
    expect(find.text('09:00 ~ 18:00'), findsOneWidget);
    expect(find.text('매주 월요일'), findsOneWidget);
  });

  testWidgets('담기 전이라 당일 경고는 뜨지 않는다', (tester) async {
    // 여행 날짜가 없어 '오늘'을 판정할 수 없다 — isToday 는 거짓이다
    await pump(tester);
    await tester.tap(find.text('예산시장'));
    await tester.pumpAndSettle();

    expect(find.text('오늘은 휴무일이에요'), findsNothing);
    expect(find.text('오늘 운영이 끝났어요'), findsNothing);
  });
}
