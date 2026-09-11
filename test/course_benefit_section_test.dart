import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/presentation/course_screen.dart';
import 'package:offway/features/course/presentation/widgets/course_benefit_section.dart';
import 'package:offway/features/policy/data/policy_repository.dart';
import 'package:offway/features/policy/presentation/region_benefit_card.dart';

/// 코스 확정 화면 아래의 '이 지역에서 누릴 수 있는 혜택' (시안 1482:53418).
///
/// 위 장소 목록에서 스친 혜택을, 담을지 정하기 직전 자리에서 카드로 한 번 더
/// 보여준다. 혜택이 없는 지역에서는 통째로 사라진다.
void main() {
  Map<String, dynamic> course({List<Map<String, dynamic>>? benefits}) => {
    'regionName': '정선군',
    'durationDays': 1,
    'travelDate': '2026-09-10',
    'days': [
      {
        'day': 1,
        'date': '2026-09-10',
        'dayOfWeek': '목',
        'places': [
          {
            'name': '삼탄아트마인',
            'category': '체험/문화',
            'kind': 'SIGHT',
            'poiContentId': '1',
            'catchphrase': '폐광촌 예술 체험 공간',
          },
        ],
      },
    ],
    'benefits': ?benefits,
  };

  Future<void> pump(
    WidgetTester tester, {
    List<Map<String, dynamic>>? benefits,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseProvider((
            regionId: '정선',
            desiredDays: 1,
          )).overrideWith((ref) async => course(benefits: benefits)),
          for (final id in [1, 2])
            policyDetailProvider(id).overrideWith(
              (ref) async => {
                'id': id,
                'name': '숙박세일페스타 $id',
                'benefitDetail': '인구감소지역 숙박 예약 시 숙박비 할인 쿠폰 지급',
                'applyUrl': 'https://example.com',
              },
            ),
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

  testWidgets('혜택이 여럿이면 카드를 그만큼 편다', (tester) async {
    await pump(
      tester,
      benefits: [
        {'text': '숙박 할인', 'policyId': 1},
        {'text': '체험 할인', 'policyId': 2},
      ],
    );

    expect(find.text('이 지역에서 누릴 수 있는 혜택'), findsOneWidget);
    expect(find.byType(RegionBenefitCard), findsNWidgets(2));
    // 서버가 준 뱃지 문구와 정책에서 받아 온 이름이 함께 보인다
    expect(find.text('숙박 할인'), findsOneWidget);
    expect(find.text('숙박세일페스타 1'), findsOneWidget);
    expect(find.text('숙박세일페스타 2'), findsOneWidget);
  });

  testWidgets('혜택이 없으면 섹션째 사라진다 — 구분 띠만 남기지 않는다', (tester) async {
    await pump(tester);

    expect(find.byType(CourseBenefitSection), findsNothing);
    expect(find.text('이 지역에서 누릴 수 있는 혜택'), findsNothing);
  });

  testWidgets('혜택 섹션은 장소 목록 뒤, 담기 유도 앞에 온다', (tester) async {
    await pump(
      tester,
      benefits: [
        {'text': '숙박 할인', 'policyId': 1},
      ],
    );

    final place = tester.getRect(find.text('삼탄아트마인'));
    final title = tester.getRect(find.text('이 지역에서 누릴 수 있는 혜택'));
    final prompt = tester.getRect(find.text('코스가 마음에 든다면?'));
    expect(title.top, greaterThan(place.bottom));
    expect(prompt.top, greaterThan(title.bottom));
  });

  testWidgets('시안 치수 — 카드 폭 362·높이 108, 카드 사이 10', (tester) async {
    await pump(
      tester,
      benefits: [
        {'text': '숙박 할인', 'policyId': 1},
        {'text': '체험 할인', 'policyId': 2},
      ],
    );

    final cards = find.byType(RegionBenefitCard);
    final first = tester.getRect(cards.at(0));
    final second = tester.getRect(cards.at(1));
    expect(first.left, 20);
    expect(first.width, 362);
    expect(first.height, 108);
    expect(second.top - first.bottom, 10);

    // 제목 아래 16 (시안: 제목 프레임 26 다음이 16)
    final title = tester.getRect(find.text('이 지역에서 누릴 수 있는 혜택'));
    expect(first.top - title.bottom, closeTo(16, 0.5));
  });

  testWidgets('구분 띠는 목록 여백을 거슬러 화면 폭을 꽉 채운다', (tester) async {
    await pump(
      tester,
      benefits: [
        {'text': '숙박 할인', 'policyId': 1},
      ],
    );

    // 목록은 좌우 20 패딩인데 띠는 0부터 402까지다
    final band = tester.getRect(
      find
          .byWidgetPredicate(
            (w) => w is ColoredBox && w.color == const Color(0xFFF4F4F5),
          )
          .first,
    );
    expect(band.left, 0);
    expect(band.width, 402);
    expect(band.height, 12);
  });

  testWidgets("장소 설명 앞에 '추천 '을 붙이지 않는다", (tester) async {
    // QA 9/11 — 코스에 실린 장소는 전부 추천이라 줄마다 되뇌는 말이었다
    await pump(
      tester,
      benefits: [
        {'text': '숙박 할인', 'policyId': 1},
      ],
    );

    expect(find.text('폐광촌 예술 체험 공간'), findsOneWidget);
    expect(find.textContaining('추천 폐광촌'), findsNothing);
  });
}
