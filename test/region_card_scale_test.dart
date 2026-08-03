import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/region/presentation/widgets/region_card.dart';

void main() {
  testWidgets('글자 크기 배율을 키워도 그리드 셀 안에서 넘치지 않는다', (tester) async {
    const region = {
      'id': '정선',
      'name': '아주아주긴지역이름테스트',
      'sido': '강원',
      'description': '설명',
      'benefitBadge': '숙박비 30% 지원',
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

  testWidgets('스켈레톤은 실제 카드와 같은 높이를 차지한다', (tester) async {
    // 높이가 어긋나면 데이터가 도착하는 순간 화면이 튄다.
    const region = {
      'id': '정선',
      'name': '정선',
      'sido': '강원',
      'description': '폐광촌에서 다시 태어난 마을',
      'benefitBadge': '숙박비 30% 지원',
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [RegionCard(region: region), RegionCardSkeleton()],
        ),
      ),
    );

    final card = tester.getSize(find.byType(RegionCard));
    final skeleton = tester.getSize(find.byType(RegionCardSkeleton));
    expect(skeleton.width, card.width);
    expect(skeleton.height, closeTo(card.height, 1));
  });
}
