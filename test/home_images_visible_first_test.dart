import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/course/application/pending_trip_provider.dart';
import 'package:offway/features/home/application/home_providers.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/region/presentation/widgets/region_card.dart';

/// 홈 '이번달 추천 여행지' — **처음 보이는 사진부터** 받는다.
///
/// 카드 50여 장을 한꺼번에 만들어 사진도 한꺼번에 받았다. 보이는 3~4장이
/// 화면 밖 사진과 대역폭을 나눠 쓰느라 늦게 떴다.
void main() {
  List<Map<String, dynamic>> regions(int n) => [
    for (var i = 1; i <= n; i++)
      {
        'id': '$i',
        'name': '지역$i',
        'sido': '도',
        'imageUrl': 'https://example.com/$i.jpg',
        'categoryCounts': const {},
      },
  ];

  testWidgets('화면 근처 카드만 사진을 받고, 넘기면 이어서 받는다', (tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) async => {'nickname': '영찬', 'remainingLeaveDays': 12.0},
          ),
          homeSnapshotProvider.overrideWith(
            (ref) async => HomeSnapshot(
              user: const {'remainingLeaveDays': 12.0},
              regions: regions(30),
            ),
          ),
          pendingTripProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    List<RegionCard> cards() => tester
        .widgetList<RegionCard>(find.byType(RegionCard))
        .where((c) => c.style == RegionCardStyle.boxed)
        .toList();
    int loading() => cards().where((c) => c.loadImage).length;

    // 카드는 전부 만든다 — 줄 높이가 가장 긴 카드에 맞춰진다
    expect(cards().length, greaterThanOrEqualTo(30));
    // 사진은 보이는 카드(402폭에 2~3장)와 그 뒤 두 장만
    final first = loading();
    expect(first, lessThanOrEqualTo(5));
    expect(first, greaterThanOrEqualTo(3));

    // 옆으로 넘기면 다음 카드들도 받는다
    await tester.drag(find.byType(RegionCard).at(1), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(loading(), greaterThan(first));
  });

  test('처음 보일 사진 주소 — 추천 여행지 줄의 앞 몇 장', () {
    final snapshot = HomeSnapshot(user: const {}, regions: regions(8));
    expect(homeFirstImageUrls(snapshot, count: 5), [
      for (var i = 1; i <= 5; i++) 'https://example.com/$i.jpg',
    ]);
  });
}
