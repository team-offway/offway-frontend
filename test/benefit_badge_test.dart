import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/policy/domain/region_benefit.dart';
import 'package:offway/features/policy/presentation/benefit_badge.dart';

/// 혜택 뱃지 — 네 화면이 같은 위젯을 쓴다(core #418).
void main() {
  Future<void> pump(
    WidgetTester tester,
    RegionBenefit benefit, {
    BenefitBadgeSize size = BenefitBadgeSize.normal,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BenefitBadge(benefit: benefit, size: size),
      ),
    ),
  );

  testWidgets('브랜드색 8% 배경에 브랜드색 글자다', (tester) async {
    // 회색(Fill/Normal)로 되돌아가면 혜택이 분류 뱃지처럼 보인다
    await pump(tester, const RegionBenefit(text: '입장료 50% 할인', policyId: 7));

    final box = tester.widget<Container>(find.byType(Container));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.primaryNormal.withValues(alpha: 0.08));
    expect(
      tester.widget<Text>(find.text('입장료 50% 할인')).style?.color,
      AppColors.primaryNormal,
    );
  });

  testWidgets('정책 id가 없으면 눌러도 아무 일도 없다', (tester) async {
    // 옛 문자열 계약으로 온 혜택이 이 경우다. 시트를 못 여는데 눌리면
    // 반응 없는 버튼이 된다
    await pump(tester, const RegionBenefit(text: '숙박 할인'));

    final gesture = tester.widget<GestureDetector>(
      find.byType(GestureDetector),
    );
    expect(gesture.onTap, isNull);
  });

  testWidgets('정책 id가 있으면 누를 수 있다', (tester) async {
    await pump(tester, const RegionBenefit(text: '숙박 할인', policyId: 2));

    final gesture = tester.widget<GestureDetector>(
      find.byType(GestureDetector),
    );
    expect(gesture.onTap, isNotNull);
  });

  testWidgets('카드 안에서는 상세보다 촘촘하다', (tester) async {
    // 시안이 자리마다 다르게 잡은 값이다 — 하나로 뭉치면 좁은 카드에서
    // 뱃지가 이름을 밀어낸다
    await pump(
      tester,
      const RegionBenefit(text: '숙박 할인'),
      size: BenefitBadgeSize.card,
    );
    final card = tester.getSize(find.byType(Container));

    await pump(tester, const RegionBenefit(text: '숙박 할인'));
    final normal = tester.getSize(find.byType(Container));

    expect(card.width, lessThan(normal.width));
    expect(card.height, lessThan(normal.height));
  });
}
