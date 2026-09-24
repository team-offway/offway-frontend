import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/home/application/home_providers.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/policy/data/region_policies_provider.dart';
import 'package:offway/features/region/data/region_list_repository.dart';
import 'package:offway/features/region/presentation/region_list_screen.dart';

/// 추천 여행지 목록 — 다음 장을 못 불러오면 **목록 끝에서 알리고**, 스크롤로는
/// 다시 부르지 않는다(#390). 예전에는 알림 없이 스크롤할 때마다 같은 실패
/// 요청이 이어졌다.
class _Repository extends RegionListRepository {
  _Repository() : super(Dio());

  final calls = <int>[];

  /// 다음 장(1)이 이만큼 실패한다
  int failuresLeft = 1;

  @override
  Future<RegionPage> fetch({
    String? category,
    int page = 0,
    int size = 20,
  }) async {
    calls.add(page);
    if (page == 1 && failuresLeft > 0) {
      failuresLeft--;
      throw const ApiException(status: 500, code: 'X', detail: '서버 오류');
    }
    return RegionPage(
      regions: [
        for (var i = 0; i < 10; i++)
          toRegionCardMap({
            'regionId': page * 100 + i,
            'name': '지역${page}_$i · 강원',
            'categories': const <Map<String, dynamic>>[],
          }),
      ],
      hasMore: page == 0,
    );
  }
}

void main() {
  testWidgets('다음 장이 실패하면 끝에서 알리고, 다시 시도를 눌러야 다시 부른다', (tester) async {
    final repo = _Repository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '영찬'},
              regions: [],
              places: [],
            ),
          ),
          regionPoliciesProvider.overrideWith((ref) async => {}),
          regionListRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: RegionListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, [0]);

    // 바닥까지 내려 다음 장을 부른다 → 실패
    final list = find.byType(CustomScrollView).first;
    await tester.drag(list, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(repo.calls, [0, 1]);
    await tester.drag(list, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.text('더 불러오지 못했어요'), findsOneWidget);

    // 바닥 근처에서 더 움직여도 다시 부르지 않는다
    await tester.drag(list, const Offset(0, 100));
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(repo.calls, [0, 1]);

    // 다시 시도를 누르면 그 장을 다시 부르고, 줄이 사라진다
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(repo.calls, [0, 1, 1]);
    expect(find.text('더 불러오지 못했어요'), findsNothing);
  });
}
