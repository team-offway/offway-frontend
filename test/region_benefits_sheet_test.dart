import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/policy/data/policy_repository.dart';
import 'package:offway/features/region/presentation/widgets/region_card.dart';

/// 혜택이 여럿인 지역 카드 — 뱃지에 `+1`, 누르면 고르는 시트, 고르면 정책 상세.
void main() {
  const two = [
    {'text': '여행경비 50% 환급', 'policyId': 1},
    {'text': '관광지 입장 할인', 'policyId': 3, 'policyName': '디지털관광주민증'},
  ];

  Future<void> pump(WidgetTester tester, Map<String, dynamic> region) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policyDetailProvider.overrideWith(
            (ref, id) async => {
              'id': id,
              'name': id == 1 ? '지역사랑 휴가지원(반값여행)' : '디지털관광주민증',
              'benefitDetail': id == 1 ? '경비 절반 환급' : '관광지 입장료 할인',
            },
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: RegionCard.boxedWidth,
              child: RegionCard(region: region),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('혜택이 둘이면 뱃지에 +1이 붙는다', (tester) async {
    await pump(tester, {
      'id': '15',
      'name': '영월군',
      'sido': '강원특별자치도',
      'benefit': two[0],
      'benefits': two,
    });

    // 문구는 서버가 준 그대로, `+1`은 옆의 작은 칩이다
    expect(find.text('여행경비 50% 환급'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('정책 id가 없는 행은 눌러도 아무 일도 없다', (tester) async {
    // 옛 문자열 계약으로 온 혜택 — 상세를 열 수 없는데 시트만 닫히면 고장으로 읽힌다
    await pump(tester, {
      'id': '15',
      'name': '영월군',
      'sido': '강원특별자치도',
      'benefit': {'text': '이름만 있는 혜택'},
      'benefits': [
        {'text': '이름만 있는 혜택'},
        two[1],
      ],
    });
    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('이름만 있는 혜택').last);
    await tester.pumpAndSettle();

    // 시트가 그대로 열려 있다
    expect(find.text('영월군 · 강원특별자치도 혜택'), findsOneWidget);
  });

  testWidgets('혜택 행마다 링크 아이콘이 앞에 붙는다', (tester) async {
    // 시안: 링크 아이콘(24) + 간격 8 + 이름, 오른쪽에 쉐브론
    await pump(tester, {
      'id': '15',
      'name': '영월군',
      'sido': '강원특별자치도',
      'benefit': two[0],
      'benefits': two,
    });
    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();

    final links = find.byWidgetPredicate(
      (w) =>
          w is SvgPicture &&
          w.width == 24 &&
          (w.bytesLoader as SvgAssetLoader).assetName ==
              'assets/icons/ic_link.svg',
    );
    expect(links, findsNWidgets(2), reason: '혜택 두 건이면 아이콘도 둘');

    // 시안 실측 (71,72,76) — 오른쪽 쉐브론(Alternative)보다 진하다
    final icon = tester.widget<SvgPicture>(links.first);
    expect(
      icon.colorFilter,
      const ColorFilter.mode(AppColors.labelNeutral, BlendMode.srcIn),
    );
  });

  testWidgets('하나뿐이면 지금까지처럼 문구만이다', (tester) async {
    await pump(tester, {
      'id': '15',
      'name': '영월군',
      'sido': '강원특별자치도',
      'benefit': two[0],
      'benefits': [two[0]],
    });

    expect(find.text('여행경비 50% 환급'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('뱃지를 누르면 고르는 시트가, 고르면 그 정책 상세가 열린다', (tester) async {
    await pump(tester, {
      'id': '15',
      'name': '영월군',
      'sido': '강원특별자치도',
      'benefit': two[0],
      'benefits': two,
    });

    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();

    // 시트 — 지역 이름 제목과 정책 두 줄. 이름을 모르는 대표는 뱃지 문구가 이름이다
    expect(find.text('영월군 · 강원특별자치도 혜택'), findsOneWidget);
    expect(find.text('디지털관광주민증'), findsOneWidget);
    // 카드의 뱃지 하나 + 시트의 행 하나
    expect(find.text('여행경비 50% 환급'), findsNWidgets(2));

    await tester.tap(find.text('디지털관광주민증'));
    await tester.pumpAndSettle();

    // 고르는 시트는 닫히고 정책 상세 시트가 그 자리에 뜬다
    expect(find.text('영월군 · 강원특별자치도 혜택'), findsNothing);
    expect(find.text('디지털관광주민증'), findsOneWidget);
    expect(find.text('관광지 입장료 할인'), findsOneWidget);
  });
}
