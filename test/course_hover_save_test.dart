import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/presentation/course_screen.dart';

/// 코스 확정 화면 하단에 떠 있는 '내 코스에 담기' (시안 18860:77008).
///
/// **최초 진입에는 떠 있고 스크롤을 내리면 사라진다.** 코스를 훑는 동안
/// 화면 아래를 가리지 않으려는 것이고, 맨 위로 돌아오면 다시 나온다.
void main() {
  Map<String, dynamic> course() => {
    'regionName': '정선군',
    'durationDays': 1,
    'travelDate': '2026-09-10',
    'days': [
      {
        'day': 1,
        'date': '2026-09-10',
        'dayOfWeek': '목',
        'places': [
          for (var i = 1; i <= 8; i++)
            {
              'name': '장소 $i',
              'category': '관광',
              'kind': 'SIGHT',
              'poiContentId': '$i',
              'travelMinutes': 10,
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
            regionId: '정선',
            desiredDays: 1,
          )).overrideWith((ref) async => course()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CourseScreen(regionId: '정선', desiredDays: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// 떠 있는 버튼만 — 목록 끝의 버튼과 문구가 같아 자리로 가른다
  Finder hoverButton() => find.descendant(
    of: find.byType(InkWell),
    matching: find.text('내 코스에 담기'),
  );

  testWidgets('최초 진입에는 떠 있다', (tester) async {
    await pump(tester);

    expect(hoverButton(), findsOneWidget);
  });

  testWidgets('스크롤을 내리면 사라진다', (tester) async {
    await pump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // 사라진 것은 투명도라 위젯은 남는다 — 눌리지 않는지로 본다
    final ignore = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(AnimatedOpacity),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue);
  });

  testWidgets('맨 위로 돌아오면 다시 나온다', (tester) async {
    // 방향이 아니라 위치가 기준이다 — 위로 조금 올렸다고 도로 뜨면
    // 목록 가운데서 버튼이 깜빡인다
    await pump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    final ignore = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(AnimatedOpacity),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isFalse);
  });

  testWidgets('목록 끝의 버튼은 그대로 있다', (tester) async {
    // 떠 있는 버튼은 덤이다 — 끝까지 내려온 사람이 쓰던 자리를 뺏지 않는다
    await pump(tester);

    await tester.scrollUntilVisible(
      find.text('새로운 추천 받기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('내 코스에 담기'), findsWidgets);
  });
}
