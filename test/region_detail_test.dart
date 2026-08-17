import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/region/presentation/region_detail_screen.dart';

/// 지역 상세 — 시안(코스_상세)의 순서와 접힘 규칙을 고정한다.
void main() {
  /// 3줄을 확실히 넘기는 소개글
  const longStory =
      '한때 검은 석탄을 캐내던 삼탄아트마인은 이제 빛과 색으로 가득한 복합문화공간으로 다시 태어났다. '
      '화암동굴의 신비로운 종유석 사이를 걷고 아리랑시장 좌판에서 곤드레밥 한 그릇을 비우면 '
      '하루가 저문다. 정선은 그렇게 느리게 흐르는 시간을 품고 있다. '
      '가을이면 능선마다 단풍이 번지고 겨울에는 눈꽃이 마을을 덮는다.';

  Future<void> pump(
    WidgetTester tester, {
    String? story = longStory,
    List<Map<String, dynamic>> spots = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          regionDetailProvider('정선').overrideWith(
            (ref) async => {
              'id': '정선',
              'name': '정선',
              'sido': '강원',
              'headline': '🏔️ 폐광촌에서 예술마을로',
              'story': ?story,
              'benefitBadge': '숙박 할인',
              'photos': const <String>[],
              'highlightSpots': spots,
            },
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RegionDetailScreen(regionId: '정선'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('화면 구성', () {
    testWidgets('제목과 혜택 뱃지를 보여준다', (tester) async {
      await pump(tester);

      expect(find.text('정선 · 강원'), findsOneWidget);
      expect(find.text('숙박 할인'), findsOneWidget);
    });

    testWidgets('한 줄 제목은 그리지 않는다', (tester) async {
      // 시안에 headline 자리가 없다 — 제목·뱃지 바로 아래가 본문이다
      await pump(tester);
      expect(find.text('🏔️ 폐광촌에서 예술마을로'), findsNothing);
    });

    testWidgets("'기본 정보' 대신 인구감소지역 안내로 끝맺는다", (tester) async {
      await pump(tester);

      expect(find.text('기본 정보'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('새롭게 주목받는 인구감소지역이에요'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('익숙한 여행지에서 조금 벗어나'), findsOneWidget);
    });

    testWidgets('소개글이 없으면 그 칸을 접는다', (tester) async {
      // 서버 89곳은 소개글이 없다 — 빈 칸이 남으면 안 된다
      await pump(tester, story: null);

      expect(find.textContaining('삼탄아트마인'), findsNothing);
      expect(find.text('정선 · 강원'), findsOneWidget);
    });
  });

  group('소개글 접기', () {
    /// 소개 본문 위젯을 찾는다
    Text storyText(WidgetTester tester) => tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains('삼탄아트마인') ?? false),
      ),
    );

    testWidgets('처음에는 3줄까지만 보여준다', (tester) async {
      // 다 펼쳐 두면 긴 지역에서 사진·매력 포인트가 화면 밖으로 밀린다
      await pump(tester);

      expect(storyText(tester).maxLines, 3);
      expect(storyText(tester).overflow, TextOverflow.ellipsis);
    });

    testWidgets('쉐브론을 누르면 펼쳐진다', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('region-story-toggle')));
      await tester.pumpAndSettle();

      expect(storyText(tester).maxLines, isNull);
    });

    testWidgets('펼친 뒤 다시 누르면 접힌다', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('region-story-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('region-story-toggle')));
      await tester.pumpAndSettle();

      expect(storyText(tester).maxLines, 3);
    });

    testWidgets('짧은 소개글에는 쉐브론을 두지 않는다', (tester) async {
      // 눌러도 변화가 없는 버튼은 없느니만 못하다
      await pump(tester, story: '삼탄아트마인이 있는 고장.');

      expect(find.byKey(const Key('region-story-toggle')), findsNothing);
    });
  });

  group('매력 포인트 장소', () {
    testWidgets('장소가 있으면 지역명을 붙여 제목을 만든다', (tester) async {
      await pump(
        tester,
        spots: [
          {'name': '삼탄아트마인', 'caption': '관광'},
        ],
      );

      await tester.scrollUntilVisible(
        find.text('정선 매력 포인트 장소'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('삼탄아트마인'), findsOneWidget);
    });

    testWidgets('장소가 없으면 그 칸을 통째로 접는다', (tester) async {
      await pump(tester);
      expect(find.text('정선 매력 포인트 장소'), findsNothing);
    });
  });
}
