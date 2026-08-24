import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../home/presentation/home_screen.dart'
    show homePlacesProvider, homeSnapshotProvider;
import '../data/region_list_repository.dart';
import 'widgets/category_chip.dart';
import 'widgets/region_card.dart';

/// 이번달 추천 여행지 — 카테고리 필터 + 2열 그리드.
///
/// 홈 위 섹션의 더보기다. 그 섹션이 **장소 카드**(core #305, `recommendedPlaces`)
/// 이므로 여기도 같은 장소들을 전부 편다 — 홈은 가로로 잘려 몇 장만 보이고,
/// 서버에 별도의 장소 목록 API는 없어 홈 응답이 곧 전체다(지역 6곳 ×
/// 카테고리별 2곳). 칩 필터는 홈과 같은 규칙으로 앱에서 거른다.
///
/// 장소 배치가 아직 안 돌아 홈이 지역 카드로 폴백하는 동안에는 여기도
/// 예전처럼 지역 목록 API(`GET /regions`, 89곳 페이지)를 탄다.
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

  final _scroll = ScrollController();
  final _regions = <Map<String, dynamic>>[];

  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  /// 첫 페이지를 받기 전인지 — 스켈레톤과 '더 불러오는 중'을 가른다
  bool get _isFirstLoad => _regions.isEmpty && _loading;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // 지역 목록은 장소가 비어 폴백할 때만 부른다 — build가 정한다
  }

  /// 장소 카드가 있어 그걸 쓰는 중인지. 폴백(지역 목록)일 때만 서버를 다시 부른다
  bool get _usingPlaces =>
      ref.read(homePlacesProvider).value?.isNotEmpty ?? false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 바닥에 닿기 전에 미리 다음 장을 부른다
  void _onScroll() {
    if (!_scroll.hasClients || _loading || !_hasMore) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _load();
  }

  /// [reset]이면 칩을 바꿔 처음부터 다시 받는다
  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _regions.clear();
        _page = 0;
        _hasMore = true;
      }
    });
    try {
      final page = await ref
          .read(regionListRepositoryProvider)
          .fetch(category: _selected?['key'] as String?, page: _page);
      if (!mounted) return;
      setState(() {
        _regions.addAll(page.regions);
        _hasMore = page.hasMore;
        _page++;
      });
    } catch (e) {
      if (!mounted) return;
      // 이미 받아둔 페이지는 남긴다 — 더 불러오다 실패했다고 목록을 비우지 않는다
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectCategory(Map<String, dynamic> filter) {
    if (_selected?['key'] == filter['key']) return;
    setState(() => _selected = Map<String, dynamic>.from(filter));
    // 장소는 앱이 거른다. 지역 목록(폴백)만 서버가 다시 걸러 준다
    if (!_usingPlaces) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
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
                  return _buildBody(cardExtent);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(double cardExtent) {
    final places = ref.watch(homePlacesProvider);
    // 홈이 아직 장소를 읽는 중이면 폴백 여부도 모른다 — 자리만 잡아둔다
    if (places.isLoading && places.value == null) {
      return _buildGrid(
        cardExtent,
        itemCount: _skeletonCardCount,
        builder: (_, _) =>
            const RegionCardSkeleton(style: RegionCardStyle.plain),
      );
    }
    if (places.value case final List<Map<String, dynamic>> served
        when served.isNotEmpty) {
      final list = filterCardsByCategory(served, _selected);
      if (list.isEmpty) return _buildEmpty();
      return _buildGrid(
        cardExtent,
        itemCount: list.length,
        builder: (context, i) =>
            RegionCard(region: list[i], style: RegionCardStyle.plain),
      );
    }

    // 장소가 비었다(배치 전) — 지역 목록으로 폴백. 첫 진입이면 지금 부른다
    if (_regions.isEmpty && !_loading && _error == null && _hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(reset: true);
      });
    }
    // 스피너 대신 카드가 들어올 자리를 미리 잡아둔다
    if (_isFirstLoad || (_regions.isEmpty && _error == null)) {
      return _buildGrid(
        cardExtent,
        itemCount: _skeletonCardCount,
        builder: (_, _) =>
            const RegionCardSkeleton(style: RegionCardStyle.plain),
      );
    }
    // 첫 페이지부터 실패했을 때만 목록 대신 오류를 낸다.
    // 서버 detail이 사용자 문구라 그대로 보여준다
    if (_regions.isEmpty && _error != null) {
      final e = _error;
      return Center(
        child: Text(
          e is ApiException ? e.detail : '추천 여행지를 불러오지 못했어요',
          textAlign: TextAlign.center,
          style: AppTypography.label1NormalMedium.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
      );
    }
    if (_regions.isEmpty) return _buildEmpty();

    // 마지막 줄에 다음 장을 기다리는 자리를 둔다
    final tail = _loading ? 2 : 0;
    return _buildGrid(
      cardExtent,
      controller: _scroll,
      itemCount: _regions.length + tail,
      builder: (context, i) => i >= _regions.length
          ? const RegionCardSkeleton(style: RegionCardStyle.plain)
          : RegionCard(region: _regions[i], style: RegionCardStyle.plain),
    );
  }

  Widget _buildGrid(
    double cardExtent, {
    required int itemCount,
    required Widget Function(BuildContext, int) builder,
    ScrollController? controller,
  }) {
    return GridView.builder(
      controller: controller,
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
              onTap: () => _selectCategory(filter),
            ),
        ],
      ),
    );
  }
}
