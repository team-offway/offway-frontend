import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../mock/mock_data_source.dart';
import 'widgets/region_card.dart';

/// 추천 여행지 전체 목록 mock (서버 연동 시 목록 API로 교체)
final regionListProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => MockDataSource.allRegions(),
);

/// 이번달 추천 여행지 — 카테고리 필터 + 2열 그리드
class RegionListScreen extends ConsumerStatefulWidget {
  const RegionListScreen({super.key});

  @override
  ConsumerState<RegionListScreen> createState() => _RegionListScreenState();
}

class _RegionListScreenState extends ConsumerState<RegionListScreen> {
  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _textMuted = Color(0xFF707070);
  static const _chipGray = Color(0xFFF2F3F6);
  static const _chipSelected = Color(0xFF191B1F);

  /// '전체'는 필터 없음을 의미한다
  static const _categories = ['전체', '관광지', '숙박', '체험', '맛집'];

  String _selected = _categories.first;

  /// 선택된 카테고리의 콘텐츠가 있는 지역만 남긴다
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    if (_selected == _categories.first) return all;
    return all.where((r) {
      final counts = r['categoryCounts'] as Map<String, dynamic>?;
      return (counts?[_selected] as int? ?? 0) > 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final regions = ref.watch(regionListProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: regions.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('여행지를 불러오지 못했어요\n$e')),
                data: (all) {
                  final list = _filter(all);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // 셀 높이 공식은 카드가 소유한다 (구성 변경 시 한 곳만 수정)
                      final columnWidth = (constraints.maxWidth - 40 - 12) / 2;
                      final cardExtent = RegionCard.mainAxisExtentFor(
                        context,
                        columnWidth,
                      );
                      return _buildScroll(list, cardExtent);
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

  Widget _buildScroll(List<Map<String, dynamic>> list, double cardExtent) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCategoryRow()),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        if (list.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '해당 카테고리의 여행지가 아직 없어요',
                style: TextStyle(fontSize: 14, color: _textMuted),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 24,
                mainAxisExtent: cardExtent,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    RegionCard(region: list[i], style: RegionCardStyle.plain),
                childCount: list.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 8, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 22,
              color: _labelNormal,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '이번달 추천 여행지',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _labelNormal,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final label in _categories)
            GestureDetector(
              onTap: () => setState(() => _selected = label),
              child: Column(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: _chipGray,
                      borderRadius: BorderRadius.circular(20),
                      border: _selected == label
                          ? Border.all(color: _chipSelected, width: 1.5)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: _selected == label
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _selected == label ? _chipSelected : _textMuted,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
