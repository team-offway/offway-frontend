import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/presentation/poi_detail_screen.dart';
import 'package:offway/features/policy/presentation/benefit_badge.dart';

/// 장소 상세 상단바 — 들어온 경로에 따라 지역명을 띄운다.
void main() {
  const poi = {
    'title': '금수사',
    'catchphrase': '예술을 캐는 광산',
    'overview': '청춘! 이는 듣기만 하여도 가슴이 설레는 말이다.',
    'address': '강원특별자치도 정선군 고한읍 함백산로 1445-44',
    'lat': 37.1,
    'lng': 128.8,
  };

  Widget wrap({String? regionName, Map<String, dynamic>? extra}) =>
      ProviderScope(
        overrides: [
          poiDetailProvider(
            'X',
          ).overrideWith((ref) async => {...poi, ...?extra}),
        ],
        child: MaterialApp(
          home: PoiDetailScreen(
            contentId: 'X',
            name: '금수사',
            regionName: regionName,
          ),
        ),
      );

  testWidgets('지역 상세에서 들어오면 상단바에 지역명이 뜬다', (tester) async {
    await tester.pumpWidget(wrap(regionName: '동구 · 부산광역시'));
    await tester.pump();

    expect(find.text('동구 · 부산광역시'), findsOneWidget);
    // 장소명은 본문에서만 크게 보여준다 — 상단바에 넣으면 두 번 보인다
    expect(find.text('금수사'), findsOneWidget);
  });

  testWidgets('코스에서 들어오면 상단바를 비운다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    // 어느 지역인지 이미 알고 들어온 경로라 지역명을 띄우지 않는다
    expect(find.text('동구 · 부산광역시'), findsNothing);
    expect(find.text('금수사'), findsOneWidget);
  });

  testWidgets('혜택이 객체로 와도 뱃지를 그린다 (core #418)', (tester) async {
    // 서버가 문자열에서 객체로 바꾼 자리다 — `as String?`으로 읽던 때는
    // 혜택이 붙은 장소에서만 상세가 통째로 터졌다
    await tester.pumpWidget(
      wrap(
        extra: {
          'benefit': {
            'text': '숙박 할인',
            'policyType': 'STAY_FESTA',
            'policyId': 2,
            'applyUrl': 'https://ktostay.visitkorea.or.kr',
          },
        },
      ),
    );
    await tester.pump();

    expect(find.text('숙박 할인'), findsOneWidget);
    expect(find.byType(BenefitBadge), findsOneWidget);
  });

  testWidgets('혜택이 없으면 뱃지 자리도 없다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(BenefitBadge), findsNothing);
  });
}
