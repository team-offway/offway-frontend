import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';
import 'package:offway/features/course/presentation/widgets/distance_chip.dart';

/// 장소 사이의 이동 거리 칩 (시안 18991:85155, QA 9/11).
///
/// **테두리 없는 회색 채움이다.** 예전에는 흰 바탕에 선을 둘렀는데, 점선
/// 동선 위에 놓이는 칩이라 선이 하나 더 겹쳐 복잡했다.
void main() {
  Future<Rect> pump(WidgetTester tester, int meters) async {
    tester.view.physicalSize = const Size(402 * 3, 400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: DistanceChip(meters: meters),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.getRect(find.byType(DistanceChip));
  }

  Container chipBox(WidgetTester tester) => tester.widget<Container>(
    find
        .descendant(
          of: find.byType(DistanceChip),
          matching: find.byType(Container),
        )
        .first,
  );

  testWidgets('채움이다 — 테두리를 두르지 않는다', (tester) async {
    await pump(tester, 14200);

    final decoration = chipBox(tester).decoration! as BoxDecoration;
    expect(decoration.color, AppColors.backgroundNormalAlternative);
    expect(decoration.border, isNull, reason: '아웃라인 → fill 로 바꿨다');
    expect(
      (decoration.borderRadius! as BorderRadius).topLeft.x,
      8,
      reason: '시안 반경 8',
    );
  });

  testWidgets('시안 치수 — 높이 30, 패딩 14·7, 글자 12', (tester) async {
    final chip = await pump(tester, 14200);
    expect(chip.height, 30);

    final text = tester.getRect(find.text('14.2km'));
    expect(text.left - chip.left, 14);
    expect(text.top - chip.top, 7);
    expect(tester.widget<Text>(find.text('14.2km')).style?.fontSize, 12);
  });

  testWidgets('폭은 글자에 맞춰 늘어난다 — 시안 프레임(59)은 글자를 담지 못한다', (tester) async {
    // 시안 렌더에서 '14.2km' 잉크만 39px 다. 양쪽 패딩 14를 더하면 67 이
    // 필요한데 컴포넌트 폭이 59로 남아 있다 — 갱신이 안 된 값이라 따르지 않는다
    final short = await pump(tester, 1200); // 1.2km
    final long = await pump(tester, 142300); // 142.3km
    expect(long.width, greaterThan(short.width));
    // 두 칩 모두 패딩은 그대로다
    expect(long.height, short.height);
  });

  testWidgets('미터를 km 한 자리로 적는다', (tester) async {
    await pump(tester, 14249);
    expect(find.text('14.2km'), findsOneWidget);

    await pump(tester, 800);
    expect(find.text('0.8km'), findsOneWidget);
  });

  testWidgets('내 코스 상세 — 시안 간격(블록 128, 분류→칩 12, 칩→다음 14)', (tester) async {
    // 칩은 앞 장소 블록에 바로 붙고 아래로만 2를 띄운다. 장소 줄이 위아래
    // 12씩 갖고 있어 눈에 보이는 간격이 12·14가 된다 (시안 18991:85115)
    tester.view.physicalSize = const Size(402 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const travelDate = '2026-09-15';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedCourseDetailProvider('1').overrideWith(
            (ref) async => (
              saved: {
                'id': '1',
                'regionName': '태안군',
                'travelDate': travelDate,
                'startDate': travelDate,
                'endDate': travelDate,
                'shareToken': 'abc',
                'leaveDeducted': false,
              },
              course: {
                'regionName': '태안군',
                'durationDays': 1,
                'travelDate': travelDate,
                'days': [
                  {
                    'day': 1,
                    'date': travelDate,
                    'dayOfWeek': '화',
                    'places': [
                      {
                        'name': '민어도선착장',
                        'category': '관광',
                        'kind': 'SIGHT',
                        'poiContentId': '1',
                        'catchphrase': '차박을 즐길 수 있는 선착장',
                      },
                      {
                        'name': '학암포해수욕장',
                        'category': '관광',
                        'kind': 'SIGHT',
                        'poiContentId': '2',
                        'catchphrase': '아름다운 낙조가 일품인 해수욕장',
                        'distanceFromPrevMeters': 4400,
                      },
                    ],
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

    final first = tester.getRect(find.text('민어도선착장'));
    final category = tester.getRect(find.text('관광').first);
    final chip = tester.getRect(find.byType(DistanceChip).first);
    final second = tester.getRect(find.text('학암포해수욕장'));

    expect(second.top - first.top, 128, reason: '시안 장소 블록 간격');
    expect(chip.top - category.bottom, 12);
    expect(second.top - chip.bottom, 14);
    // 칩은 목록 왼쪽 끝에 선다 — 점선(x=11.4)보다 오른쪽이다
    expect(chip.left, 20);
  });
}
