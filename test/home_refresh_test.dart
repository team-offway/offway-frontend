import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/course/application/pending_trip_provider.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/region/presentation/widgets/region_card.dart';

/// 홈을 당겨서 새로고침하면 서버를 다시 읽고 카드 순서를 섞는다.
///
/// 서버는 같은 순서로 답하므로 다시 읽어도 첫 화면이 그대로다 — 당겼는데
/// 아무것도 안 바뀌면 새로고침이 된 건지 알 수 없다. 순서만 섞고 내용은
/// 그대로 둔다.
void main() {
  List<Map<String, dynamic>> regions() => [
    for (var i = 1; i <= 7; i++)
      {'id': '$i', 'name': '지역$i', 'sido': '도', 'categoryCounts': const {}},
  ];

  group('shuffledForRefresh', () {
    final cards = regions();

    test('아직 안 당겼으면 서버 순서 그대로다', () {
      expect(shuffledForRefresh(cards, null), same(cards));
    });

    test('같은 씨앗이면 같은 순서다 — 재현된다', () {
      expect(shuffledForRefresh(cards, 1), shuffledForRefresh(cards, 1));
    });

    test('내용은 그대로 두고 순서만 바꾼다', () {
      final shuffled = shuffledForRefresh(cards, 1);
      expect(shuffled, isNot(orderedEquals(cards)));
      expect(shuffled, unorderedEquals(cards));
      // 원본은 건드리지 않는다 — 프로바이더가 든 목록이다
      expect(cards.first['name'], '지역1');
    });

    test('당길 때마다 다른 순서다', () {
      expect(
        shuffledForRefresh(cards, 1),
        isNot(orderedEquals(shuffledForRefresh(cards, 2))),
      );
    });
  });

  group('당겨서 새로고침', () {
    late int fetches;

    /// 두 번째 읽기를 붙들어 두고 싶을 때 — 도는 동안의 화면을 본다
    Completer<void>? holdSecondFetch;

    Future<void> pump(WidgetTester tester) async {
      fetches = 0;
      holdSecondFetch = null;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) async => {'nickname': '영찬', 'remainingLeaveDays': 12.0},
            ),
            homeSnapshotProvider.overrideWith((ref) async {
              fetches++;
              if (fetches == 2 && holdSecondFetch != null) {
                await holdSecondFetch!.future;
              }
              return HomeSnapshot(
                user: const {'remainingLeaveDays': 12.0},
                regions: regions(),
              );
            }),
            pendingTripProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// '이번달 추천 여행지' 카드의 이름을 왼쪽부터.
    ///
    /// 장소 배치가 비어 지역 카드로 물러난 상태다. 이 줄은 Row라 카드가 전부
    /// 만들어지고, 아래 '이번 연차엔' 줄은 지연 생성이라 화면 밖은 없다
    List<String> visiblePicks(WidgetTester tester) => [
      for (final card in tester.widgetList<RegionCard>(find.byType(RegionCard)))
        card.region['name'] as String,
    ];

    /// 손가락처럼 여러 프레임에 걸쳐 끌어내린다.
    ///
    /// `tester.drag`는 한 프레임에 끝나 쿠퍼티노 컨트롤의 당김→준비→새로고침
    /// 전이를 건너뛴다. 끌기만 하고 손은 떼지 않는다 — 도는 동안을 보려는
    /// 테스트가 있어서다. 놓는 것은 [release]가 한다
    Future<TestGesture> pullDown(WidgetTester tester) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('이번달 추천 여행지')),
      );
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    Future<void> release(WidgetTester tester, TestGesture gesture) async {
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> pullToRefresh(WidgetTester tester) async {
      await release(tester, await pullDown(tester));
      await tester.pumpAndSettle();
    }

    testWidgets('당기면 서버를 다시 읽는다', (tester) async {
      await pump(tester);
      expect(fetches, 1);

      await pullToRefresh(tester);

      expect(fetches, 2);
    });

    testWidgets('다시 읽은 뒤 카드 순서가 바뀐다', (tester) async {
      await pump(tester);
      final before = visiblePicks(tester);
      expect(before.first, '지역1');

      await pullToRefresh(tester);

      final after = visiblePicks(tester);
      expect(after, isNot(orderedEquals(before)));
      // 카드가 사라지거나 늘지는 않는다
      expect(after.length, before.length);
    });

    testWidgets('도는 동안 iOS 시스템 스피너가 보인다', (tester) async {
      // 사파리·메일의 그것 — 브랜드 마크나 DS Circular이 아니다
      await pump(tester);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      holdSecondFetch = Completer<void>();

      await release(tester, await pullDown(tester));

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      holdSecondFetch!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('당기기 전에는 서버 순서 그대로다', (tester) async {
      await pump(tester);
      expect(visiblePicks(tester).take(3), ['지역1', '지역2', '지역3']);
    });
  });
}
