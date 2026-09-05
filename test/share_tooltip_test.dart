import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/app_tooltip_bubble.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';

/// 저장 코스 화면의 공유 유도 툴팁 (시안 18860:76589).
///
/// **신규 기능의 위치를 한 번 알리는 자리**다(DS Tooltip 사용 예시).
/// 코스를 읽기 시작하면 할 일을 다 한 셈이라 사라지고, 다시 뜨지 않는다.
void main() {
  ({Map<String, dynamic> saved, Map<String, dynamic> course}) detail() => (
    saved: {
      'id': '1',
      'regionName': '정선군',
      'travelDate': '2026-09-10',
      'shareToken': 'abc',
      'leaveDeducted': false,
    },
    course: {
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
    },
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedCourseDetailProvider('1').overrideWith((ref) async => detail()),
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

  testWidgets('들어오면 공유 버튼을 가리켜 알린다', (tester) async {
    await pump(tester);

    expect(find.byType(AppTooltipBubble), findsOneWidget);
    expect(find.text('여행 메이트에게 공유해보세요'), findsOneWidget);
  });

  testWidgets('스크롤을 내리면 사라진다', (tester) async {
    await pump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.byType(AppTooltipBubble), findsNothing);
  });

  testWidgets('맨 위로 돌아와도 다시 뜨지 않는다', (tester) async {
    // 한 번 알렸으면 할 일을 다 했다 — 돌아올 때마다 뜨면 잔소리가 된다
    await pump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.byType(AppTooltipBubble), findsNothing);
  });

  testWidgets('화살표를 시안 자리에 둔다', (tester) async {
    // 시안(18860:76589) 실측 — 툴팁 191 안에서 화살표는 x=163, 폭 20.
    // 오른쪽 여백 8이 코너 반지름 8과 정확히 만나 겹치지 않는다.
    // 한때 반지름을 더해 16으로 뒀다가 화살표가 8만큼 왼쪽으로 밀렸다
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: AppTooltipBubble(text: '여행 메이트에게 공유해보세요'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bubble = tester.getRect(find.byType(AppTooltipBubble));
    // 화살표는 시안 20×8 — 그 크기로 가려낸다(_ArrowPainter가 private이라
    // 타입으로는 못 집는다)
    final arrow = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.size == const Size(20, 8),
      ),
    );

    expect(bubble.right - arrow.right, closeTo(8, 0.5));
    expect(arrow.width, 20);
  });

  testWidgets('시안 크기를 지킨다', (tester) async {
    // 말풍선이 부모 폭을 다 먹으면 화살표가 붙을 자리를 잃는다
    // 테마를 줘야 Pretendard로 잰다 — 기본 서체는 폭이 달라 시안과 어긋난다
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: AppTooltipBubble(text: '여행 메이트에게 공유해보세요'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(AppTooltipBubble));
    expect(size.width, closeTo(191, 2));
    expect(size.height, 44);
  });
}
