import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/policy/data/policy_repository.dart';
import 'package:offway/features/policy/domain/region_benefit.dart';
import 'package:offway/features/policy/presentation/region_benefit_card.dart';

/// 지역 상세의 혜택 카드 (시안 18761:72093).
void main() {
  const policy = {
    'id': 1,
    'name': '지역사랑 휴가지원(반값여행)',
    'benefitDetail': '여행경비의 50%를 지역화폐로 환급',
    'applyUrl': 'https://korean.visitkorea.or.kr/dgtourcard/tour50.do',
  };

  Future<void> pump(
    WidgetTester tester,
    RegionBenefit benefit, {
    Map<String, dynamic>? detail = policy,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (detail != null)
            policyDetailProvider(1).overrideWith((ref) async => detail),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: RegionBenefitCard(benefit: benefit)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('뱃지·이름·설명을 함께 보여준다', (tester) async {
    await pump(tester, const RegionBenefit(text: '여행경비 50% 환급', policyId: 1));

    expect(find.text('여행경비 50% 환급'), findsOneWidget);
    // 이름과 설명은 지역 상세에 없어 정책 상세에서 받아 채운다
    expect(find.text('지역사랑 휴가지원(반값여행)'), findsOneWidget);
    expect(find.text('여행경비의 50%를 지역화폐로 환급'), findsOneWidget);
  });

  testWidgets('정책 상세를 기다리는 동안에도 뱃지는 먼저 뜬다', (tester) async {
    // 이미 아는 값이라 기다릴 이유가 없다. 카드 전체를 비워 두면 화면에
    // 빈 칸이 잠깐 생겼다 채워져 깜빡이는 것처럼 보인다
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policyDetailProvider(1).overrideWith(
            (ref) => Future.delayed(const Duration(seconds: 1), () => policy),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RegionBenefitCard(
              benefit: RegionBenefit(text: '여행경비 50% 환급', policyId: 1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('여행경비 50% 환급'), findsOneWidget);
    expect(find.text('지역사랑 휴가지원(반값여행)'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('지역사랑 휴가지원(반값여행)'), findsOneWidget);
  });

  testWidgets('갈 곳이 없으면 링크 아이콘도 없고 눌리지도 않는다', (tester) async {
    // applyUrl을 아직 안 적은 정책이 있다(core #418 · #119).
    // 눌러도 아무 일도 안 일어나는 자리를 남기지 않는다
    await pump(
      tester,
      const RegionBenefit(text: '숙박 할인', policyId: 1),
      detail: const {'id': 1, 'name': '숙박세일페스타'},
    );

    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('지역 상세의 신청 주소를 정책 상세보다 먼저 쓴다', (tester) async {
    // 둘 다 있으면 지역 응답이 정본이다 — 그쪽이 이 지역 기준으로 온다
    await pump(
      tester,
      const RegionBenefit(
        text: '숙박 할인',
        policyId: 1,
        applyUrl: 'https://ktostay.visitkorea.or.kr',
      ),
    );

    expect(find.byType(GestureDetector), findsOneWidget);
  });

  testWidgets('정책 id가 없어도 뱃지만으로 그린다', (tester) async {
    // 옛 문자열 계약으로 온 혜택이 이 경우다
    await pump(tester, const RegionBenefit(text: '숙박 할인'), detail: null);

    expect(find.text('숙박 할인'), findsOneWidget);
  });
}
