import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/region/presentation/widgets/region_card.dart';

void main() {
  testWidgets('글자 크기 배율을 키워도 그리드 셀 안에서 넘치지 않는다', (tester) async {
    const region = {
      'id': '정선',
      'name': '아주아주긴지역이름테스트',
      'sido': '강원',
      'description': '설명',
      'benefit': {'text': '숙박비 30% 지원', 'policyId': 7},
    };

    for (final scale in [1.0, 1.3, 1.6]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) {
                const columnWidth = 170.0;
                final extent = RegionCard.mainAxisExtentFor(
                  context,
                  columnWidth,
                );
                return Center(
                  child: SizedBox(
                    width: columnWidth,
                    height: extent,
                    child: const RegionCard(
                      region: region,
                      style: RegionCardStyle.plain,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      // 오버플로우가 있으면 렌더 예외로 실패한다
      expect(tester.takeException(), isNull, reason: '배율 $scale에서 넘침');
    }
  });

  testWidgets('설명은 두 줄까지 보여준다 — 한 줄로 자르면 문장이 끊긴다', (tester) async {
    const region = {
      'id': '정선',
      'name': '정선',
      'sido': '강원',
      'description': '폐광촌에서 다시 태어난 마을 폐광촌에서 다시 태어난 마을',
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: RegionCard(region: region)),
      ),
    );

    final desc = tester.widget<Text>(
      find.text('폐광촌에서 다시 태어난 마을 폐광촌에서 다시 태어난 마을'),
    );
    expect(desc.maxLines, 2);
    expect(desc.overflow, TextOverflow.ellipsis);
  });

  testWidgets('스켈레톤은 실제 카드와 같은 높이를 차지한다', (tester) async {
    // 높이가 어긋나면 데이터가 도착하는 순간 화면이 튄다.
    const region = {
      'id': '정선',
      'name': '정선',
      'sido': '강원',
      'description': '폐광촌에서 다시 태어난 마을',
      'benefit': {'text': '숙박비 30% 지원', 'policyId': 7},
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RegionCard(region: region),
            RegionCardSkeleton(),
          ],
        ),
      ),
    );

    final card = tester.getSize(find.byType(RegionCard));
    final skeleton = tester.getSize(find.byType(RegionCardSkeleton));
    expect(skeleton.width, card.width);
    expect(skeleton.height, closeTo(card.height, 1));
  });

  testWidgets('뱃지 없는 카드는 스켈레톤도 뱃지 자리를 비운다', (tester) async {
    // 홈의 '이번달 추천'에는 혜택 뱃지가 없는 지역이 섞여 있다.
    // 스켈레톤이 늘 뱃지를 그리면 데이터 도착 순간 카드가 그만큼 줄어든다.
    const region = {
      'id': '영월',
      'name': '영월',
      'sido': '강원',
      'description': '동강과 별빛이 흐르는 고을',
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RegionCard(region: region),
            RegionCardSkeleton(hasBadge: false),
          ],
        ),
      ),
    );

    final card = tester.getSize(find.byType(RegionCard));
    final skeleton = tester.getSize(find.byType(RegionCardSkeleton));
    expect(skeleton.height, closeTo(card.height, 1));
  });

  testWidgets('혜택 뱃지는 브랜드색 8% 배경에 브랜드색 글자다', (tester) async {
    const region = {
      'id': '정선',
      'name': '정선',
      'sido': '강원',
      'description': '설명',
      'benefit': {'text': '입장료 50% 할인', 'policyId': 7},
    };
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RegionCard(region: region)),
      ),
    );

    // 회색(Fill/Normal)로 되돌아가면 혜택이 분류 뱃지처럼 보인다
    final box = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('입장료 50% 할인'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, AppColors.primaryNormal.withValues(alpha: 0.08));

    final text = tester.widget<Text>(find.text('입장료 50% 할인'));
    expect(text.style?.color, AppColors.primaryNormal);
  });
}
