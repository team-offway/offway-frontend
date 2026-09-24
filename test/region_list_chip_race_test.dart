import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/home/application/home_providers.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/policy/data/region_policies_provider.dart';
import 'package:offway/features/region/data/region_list_repository.dart';
import 'package:offway/features/region/presentation/region_list_screen.dart';

/// 추천 여행지 목록 — 불러오는 도중에 칩을 바꾸면 **새 칩의 목록**이 나와야 한다.
///
/// 예전에는 불러오는 중이면 새 요청을 버려, 칩은 '숙박'이 켜졌는데 목록은
/// '전체' 결과로 채워진 채 남았다.
class _GatedRepository extends RegionListRepository {
  _GatedRepository() : super(Dio());

  /// 카테고리별로 응답을 붙잡아 둔다 — 도착 순서를 테스트가 정한다
  final gates = <String, Completer<void>>{};

  @override
  Future<RegionPage> fetch({
    String? category,
    int page = 0,
    int size = 20,
  }) async {
    final key = category ?? 'ALL';
    await (gates[key] ??= Completer<void>()).future;
    return RegionPage(
      regions: [
        toRegionCardMap({
          'regionId': key.hashCode,
          'name': '$key 지역 · 강원',
          'categories': const <Map<String, dynamic>>[],
        }),
      ],
      hasMore: false,
    );
  }
}

void main() {
  const filters = [
    {'key': 'ALL', 'label': '전체'},
    {'key': 'STAY', 'label': '숙박'},
  ];

  testWidgets('불러오는 도중에 칩을 바꾸면 새 칩의 목록이 나온다', (tester) async {
    final repo = _GatedRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 장소가 비어 지역 목록(서버)으로 폴백하는 경로
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '영찬'},
              regions: [],
              places: [],
              filters: filters,
            ),
          ),
          regionPoliciesProvider.overrideWith((ref) async => {}),
          regionListRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: RegionListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    // '전체' 첫 장을 기다리는 중에 '숙박'을 누른다
    await tester.tap(find.text('숙박'));
    await tester.pump();

    // 숙박이 먼저 오고, 옛 '전체' 응답이 늦게 온다
    (repo.gates['STAY'] ??= Completer<void>()).complete();
    await tester.pump();
    (repo.gates['ALL'] ??= Completer<void>()).complete();
    await tester.pumpAndSettle();

    expect(find.textContaining('STAY 지역'), findsWidgets);
    expect(find.textContaining('ALL 지역'), findsNothing);
  });
}
