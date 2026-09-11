import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/app_tooltip_bubble.dart';
import 'package:offway/core/widgets/place_thumbnail.dart';
import 'package:offway/features/course/data/course_tooltip_storage.dart';
import 'package:offway/features/course/presentation/course_screen.dart';
import 'package:offway/features/course/presentation/saved_course_screen.dart';

/// 화면별 툴팁 역할 분리 (시안 1505:55696 · 1505:56078).
///
/// | 화면 | 툴팁 | 끝나는 시점 |
/// |---|---|---|
/// | 코스 확정(저장 전) | 코스를 공유해보세요 | 닫기(X) |
/// | 내 코스(담고 첫 진입) | 눌러서 자세히 보기 | 장소를 눌러 봄 |
/// | 내 코스(재진입) | 코스를 공유해보세요 | 닫기(X) |
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('저장소', () {
    late CourseTooltipStorage storage;
    setUp(() => storage = CourseTooltipStorage(const FlutterSecureStorage()));

    test('공유 안내를 닫기 전에는 열려 있다', () async {
      expect(await storage.isSharePromptClosed(), isFalse);
    });

    test('닫으면 남는다 — 다음 코스에서도 안 뜬다', () async {
      await storage.closeSharePrompt();
      expect(await storage.isSharePromptClosed(), isTrue);
    });

    test("'자세히 보기' 안내는 코스마다 따로 센다", () async {
      // 새로 담은 코스는 처음 보는 코스다 — 앱 전체에 한 번만 띄우면
      // 두 번째 코스부터는 상세로 가는 길을 모른 채 목록만 본다
      await storage.markDetailHintDone('1');
      expect(await storage.isDetailHintDone('1'), isTrue);
      expect(await storage.isDetailHintDone('2'), isFalse);
    });
  });

  group('내 코스 화면', () {
    const travelDate = '2026-12-25'; // 아직 안 간 여행

    Future<void> pump(WidgetTester tester, {String savedId = '1'}) async {
      tester.view.physicalSize = const Size(402 * 3, 874 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedCourseDetailProvider(savedId).overrideWith(
              (ref) async => (
                saved: {
                  'id': savedId,
                  'regionName': '정선군',
                  'travelDate': travelDate,
                  'startDate': travelDate,
                  'endDate': travelDate,
                  'shareToken': 'abc',
                  'leaveDeducted': false,
                },
                course: {
                  'regionName': '정선군',
                  'durationDays': 1,
                  'travelDate': travelDate,
                  'days': [
                    {
                      'day': 1,
                      'date': travelDate,
                      'dayOfWeek': '금',
                      'places': [
                        for (var i = 1; i <= 6; i++)
                          {
                            'name': '장소 $i',
                            'category': '관광',
                            'kind': 'SIGHT',
                            'poiContentId': '$i',
                            'catchphrase': '설명 $i',
                            if (i > 1) 'distanceFromPrevMeters': 11500,
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
            home: SavedCourseScreen(savedId: savedId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder tip(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byType(AppTooltipBubble),
    );

    testWidgets('담고 첫 진입 — 맨 위에서는 아직 안 뜬다', (tester) async {
      await pump(tester);
      // 시안 노트가 '스크롤링 이후'로 못박는다. 맨 위에서 띄우면 가리키는
      // 카드가 화면 밖이라 무엇을 누르라는 것인지 안 보인다
      expect(tip('눌러서 자세히 보기'), findsNothing);
    });

    testWidgets('담고 첫 진입 — 목록까지 내리면 뜬다', (tester) async {
      await pump(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(tip('눌러서 자세히 보기'), findsOneWidget);
      // 안내는 한 번에 하나만 — 공유 툴팁은 그 다음 차례다
      expect(tip('코스를 공유해보세요'), findsNothing);
    });

    testWidgets('장소를 눌러 보면 끝난다 — 다시 열어도 안 뜬다', (tester) async {
      await pump(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tip('눌러서 자세히 보기'), findsOneWidget);

      await tester.tap(find.text('장소 1'));
      await tester.pumpAndSettle();

      final storage = CourseTooltipStorage(const FlutterSecureStorage());
      expect(await storage.isDetailHintDone('1'), isTrue);
    });

    testWidgets('재진입 — 공유 안내로 바뀐다', (tester) async {
      // 지난번에 눌러 봤다
      await CourseTooltipStorage(
        const FlutterSecureStorage(),
      ).markDetailHintDone('1');

      await pump(tester);

      expect(tip('코스를 공유해보세요'), findsOneWidget);
      expect(tip('눌러서 자세히 보기'), findsNothing);
    });

    testWidgets('공유 안내를 닫은 적이 있으면 재진입에도 안 뜬다', (tester) async {
      final storage = CourseTooltipStorage(const FlutterSecureStorage());
      await storage.markDetailHintDone('1');
      await storage.closeSharePrompt();

      await pump(tester);

      expect(find.byType(AppTooltipBubble), findsNothing);
    });

    testWidgets("'자세히 보기' 툴팁에는 닫기 버튼이 없다", (tester) async {
      // 눌러 보면 끝나는 안내라 X 없이도 스스로 사라진다(시안)
      await pump(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final bubble = tester.widget<AppTooltipBubble>(tip('눌러서 자세히 보기'));
      expect(bubble.onClose, isNull);
    });

    testWidgets('두 번째 장소를 가리킨다 — 첫 장소는 역·터미널이라 열 것이 없다', (tester) async {
      await pump(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final bubble = tester.getRect(
        find
            .ancestor(
              of: find.text('눌러서 자세히 보기'),
              matching: find.byType(Container),
            )
            .first,
      );
      // 화살표는 위를 향하고, 말풍선은 **둘째 장소 사진 바로 아래**에 선다.
      // 그래야 꼭짓점이 그 사진을 짚는다(시안 1505:56078)
      final widget = tester.widget<AppTooltipBubble>(
        find.byType(AppTooltipBubble),
      );
      expect(widget.arrowAtBottom, isFalse, reason: '화살표는 위를 향한다');

      final whole = tester.getRect(find.byType(AppTooltipBubble));
      final thumbs = find.byType(PlaceThumbnail);
      final secondThumb = tester.getRect(thumbs.at(1));
      final thirdThumb = tester.getRect(thumbs.at(2));

      // 둘째 사진 밑단에 **맞닿는다** — 시안은 사진 끝과 화살표 시작이
      // 같은 자리다. 띄우면 어느 사진 것인지 흐려진다
      expect(whole.top - secondThumb.bottom, closeTo(0, 1.5));
      // 셋째 사진을 덮지 않는다
      expect(whole.bottom, lessThan(thirdThumb.top));
      expect(bubble.width, closeTo(128, 2.5));
    });

    testWidgets('말풍선이 자리를 차지하지 않는다 — 목록이 밀리지 않는다', (tester) async {
      await pump(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final p1 = tester.getRect(find.text('장소 1')).top;
      final p2 = tester.getRect(find.text('장소 2')).top;
      final p3 = tester.getRect(find.text('장소 3')).top;

      // 툴팁이 낀 구간(1→2)과 없는 구간(2→3)의 간격이 같아야 한다
      expect(p2 - p1, p3 - p2);
    });

    testWidgets('말풍선 오른쪽 끝이 썸네일 오른쪽 끝과 만난다', (tester) async {
      await pump(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final bubble = tester.getRect(
        find
            .ancestor(
              of: find.text('눌러서 자세히 보기'),
              matching: find.byType(Container),
            )
            .first,
      );
      // 시안 좌표: 툴팁 254~382, 썸네일 312~382 — 목록 여백 20 안쪽이다
      expect(402 - bubble.right, 20);
      expect(bubble.width, closeTo(128, 2.5));
    });
  });

  group('코스 확정 화면', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(402 * 3, 874 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseProvider((regionId: '정선', desiredDays: 1)).overrideWith(
              (ref) async => {
                'regionName': '정선군',
                'durationDays': 1,
                'travelDate': '2026-12-25',
                'days': [
                  {
                    'day': 1,
                    'date': '2026-12-25',
                    'dayOfWeek': '금',
                    'places': [
                      for (var i = 1; i <= 6; i++)
                        {
                          'name': '장소 $i',
                          'category': '관광',
                          'kind': 'SIGHT',
                          'poiContentId': '$i',
                        },
                    ],
                  },
                ],
              },
            ),
          ],
          child: const MaterialApp(
            home: CourseScreen(regionId: '정선', desiredDays: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('처음에는 공유 안내가 뜬다', (tester) async {
      await pump(tester);
      expect(find.text('코스를 공유해보세요'), findsOneWidget);
    });

    testWidgets('닫기(X)를 누르면 남는다 — 다음 코스에도 안 뜬다', (tester) async {
      await pump(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(AppTooltipBubble),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('코스를 공유해보세요'), findsNothing);

      final storage = CourseTooltipStorage(const FlutterSecureStorage());
      expect(await storage.isSharePromptClosed(), isTrue);

      // 화면을 새로 열어도 안 뜬다
      await pump(tester);
      expect(find.text('코스를 공유해보세요'), findsNothing);
    });

    testWidgets('스크롤로 감춘 것은 남기지 않는다 — 닫기와 다르다', (tester) async {
      await pump(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('코스를 공유해보세요'), findsNothing);

      // 읽는 동안 비켜 준 것뿐이라 기록하지 않는다
      final storage = CourseTooltipStorage(const FlutterSecureStorage());
      expect(await storage.isSharePromptClosed(), isFalse);
    });
  });
}
