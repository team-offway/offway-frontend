import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../home/presentation/home_screen.dart' show homeSnapshotProvider;
import 'widgets/category_chip.dart';
import 'widgets/region_card.dart';

/// 이번달 추천 여행지 — 홈과 같은 데이터를 카테고리 필터 + 2열 그리드로 보여준다.
///
/// 목록 전용 API가 따로 없어 홈 스냅샷(`recommendedRegions`)을 그대로 읽는다.
class RegionListScreen extends ConsumerStatefulWidget {
  const RegionListScreen({super.key});

  @override
  ConsumerState<RegionListScreen> createState() => _RegionListScreenState();
}

class _RegionListScreenState extends ConsumerState<RegionListScreen> {
  /// 로딩 중 깔아둘 카드 자리 수 — 첫 화면에 걸쳐 보이는 만큼만
  static const _skeletonCardCount = 6;

  /// 고른 칩 `{key, label}` — null이면 '전체'
  Map<String, dynamic>? _selected;

  /// 선택된 카테고리의 콘텐츠가 있는 지역만 남긴다 (홈과 같은 규칙)
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    final selected = _selected;
    if (selected == null || selected['key'] == 'ALL') return all;
    return all.where((r) {
      final counts = r['categoryCounts'] as Map<String, dynamic>?;
      return (counts?[selected['label']] as int? ?? 0) > 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(homeSnapshotProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            _buildCategoryRow(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 셀 높이 공식은 카드가 소유한다 (구성 변경 시 한 곳만 수정)
                  final columnWidth = (constraints.maxWidth - 40 - 12) / 2;
                  final cardExtent = RegionCard.mainAxisExtentFor(
                    context,
                    columnWidth,
                  );
                  return snapshot.when(
                    // 스피너 대신 카드가 들어올 자리를 미리 잡아둔다
                    loading: () => _buildGrid(
                      cardExtent,
                      itemCount: _skeletonCardCount,
                      builder: (_, _) => const RegionCardSkeleton(
                        style: RegionCardStyle.plain,
                      ),
                    ),
                    // 서버 detail이 사용자 문구라 그대로 보여준다
                    error: (e, _) => Center(
                      child: Text(
                        e is ApiException ? e.detail : '추천 여행지를 불러오지 못했어요',
                        textAlign: TextAlign.center,
                        style: AppTypography.label1NormalMedium.copyWith(
                          color: AppColors.labelAlternative,
                        ),
                      ),
                    ),
                    data: (data) {
                      final list = _filter(data.regions);
                      if (list.isEmpty) return _buildEmpty();
                      return _buildGrid(
                        cardExtent,
                        itemCount: list.length,
                        builder: (context, i) => RegionCard(
                          region: list[i],
                          style: RegionCardStyle.plain,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(
    double cardExtent, {
    required int itemCount,
    required Widget Function(BuildContext, int) builder,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 24,
        mainAxisExtent: cardExtent,
      ),
      itemCount: itemCount,
      itemBuilder: builder,
    );
  }

  /// 고른 카테고리에 따라 안내 문구가 달라진다 —
  /// 전체가 비면 이번 달 자체가 비었다는 뜻이고, 카테고리가 비면 다른 걸 권한다
  Widget _buildEmpty() {
    final label = _selected?['label'] as String?;
    final isAll = label == null || _selected?['key'] == 'ALL';
    return Center(
      child: AppEmptyView(
        illustrationAsset: 'assets/icons/ic_empty_map.svg',
        title: isAll ? '이번달 추천 여행지가 없어요' : '이번달 [$label] 추천 여행지가 없어요',
        description: isAll ? '다음 달에 다시 확인해보세요' : '다른 카테고리도 확인해보세요',
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        // 없으면 Stack이 제목 크기로 줄어 Positioned가 화면 기준이 아니게 된다
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              '이번달 추천 여행지',
              style: AppTypography.headline2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
          ),
          Positioned(
            left: 6,
            child: AppBackButton(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    final filters =
        ref.watch(homeSnapshotProvider).value?.filters ??
        defaultCategoryFilters;
    final chips = filters.isEmpty ? defaultCategoryFilters : filters;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final filter in chips)
            CategoryChip(
              label: filter['label'] as String,
              iconAsset: categoryIcons[filter['key']] ?? categoryIcons['ALL']!,
              selected: filter['key'] == 'ALL'
                  ? _selected == null || _selected!['key'] == 'ALL'
                  : _selected?['key'] == filter['key'],
              onTap: () =>
                  setState(() => _selected = Map<String, dynamic>.from(filter)),
            ),
        ],
      ),
    );
  }
}
