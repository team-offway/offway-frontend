import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/data_source_note.dart';
import '../data/region_list_repository.dart';
import '../../policy/data/region_policies_provider.dart';
import '../../../core/utils/bottom_inset.dart';
import 'widgets/category_chip.dart';
import 'widgets/region_card.dart';
import '../../home/application/home_providers.dart';
import '../../../core/widgets/app_title_bar.dart';
import '../../../core/widgets/app_error_view.dart';

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

  /// 지역 목록 응답의 출처 (core #417) — 페이지마다 같은 값이라 덮어 쓴다
  List<DataSource> _sources = const [];
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
  ///
  /// 다음 장이 실패했으면 **스크롤로는 다시 부르지 않는다** — 바닥 근처에서
  /// 조금만 움직여도 같은 실패 요청이 이어졌다(#390). 목록 끝의 '다시 시도'
  /// 를 눌렀을 때만 다시 부른다
  void _onScroll() {
    if (!_scroll.hasClients || _loading || !_hasMore || _error != null) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _load();
  }

  /// 칩을 바꾸거나 다시 시도할 때마다 올린다. 늦게 온 옛 응답은 이 값이
  /// 달라 버린다 — 불러오는 도중에 칩을 바꾸면 새 칩이 켜졌는데 목록은 옛
  /// 카테고리로 채워졌다
  int _generation = 0;

  /// [reset]이면 칩을 바꿔 처음부터 다시 받는다.
  ///
  /// 처음부터 받을 때는 **불러오는 중이어도 새로 시작한다**(옛 요청은 위
  /// [_generation]으로 버린다). 다음 장 읽기만 중복을 막는다
  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = reset ? ++_generation : _generation;
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
      if (!mounted || generation != _generation) return;
      setState(() {
        _regions.addAll(page.regions);
        _hasMore = page.hasMore;
        _sources = page.sources;
        _page++;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      // 이미 받아둔 페이지는 남긴다 — 더 불러오다 실패했다고 목록을 비우지 않는다
      setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
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
      // 출처 줄이 화면 끝이다 — 인디케이터 아래로 흐르게 두고 그만큼 더한다(#300)
      body: SafeArea(
        bottom: false,
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

  /// 지금 화면이 그리는 응답의 출처.
  ///
  /// 홈 장소 카드를 쓰는 중이면 홈 응답이 답이고, 그게 비어 지역 목록으로
  /// 폴백했으면 목록 응답이 답이다
  List<DataSource> get _shownSources {
    if (_usingPlaces) {
      return ref.watch(homeSnapshotProvider).value?.sources ??
          const <DataSource>[];
    }
    return _sources;
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
    // 한 지역의 혜택 전부 — 홈과 같은 색인이다. 서버는 대표 하나만 주므로
    // 카드에 붙여 뱃지가 `+1`을 그릴 수 있게 한다. 색인이 아직 없으면 대표뿐
    final index = ref.watch(regionPoliciesProvider).value;
    List<Map<String, dynamic>> withBenefits(List<Map<String, dynamic>> cards) =>
        index == null
        ? cards
        : [
            for (final card in cards)
              {...card, 'benefits': benefitsForCard(card, index)},
          ];

    if (places.value case final List<Map<String, dynamic>> served
        when served.isNotEmpty) {
      final list = withBenefits(filterCardsByCategory(served, _selected));
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
      return AppErrorView(
        description: e is ApiException ? e.detail : '추천 여행지를 불러오지 못했어요',
        // 오류를 지우고 처음부터 받는다 — 그동안 카드 자리가 먼저 깔린다
        onRetry: () => _load(reset: true),
      );
    }
    if (_regions.isEmpty) return _buildEmpty();

    // 마지막 줄에 다음 장을 기다리는 자리를 둔다
    final tail = _loading ? 2 : 0;
    final regions = withBenefits(_regions);
    return _buildGrid(
      cardExtent,
      controller: _scroll,
      itemCount: regions.length + tail,
      builder: (context, i) => i >= regions.length
          ? const RegionCardSkeleton(style: RegionCardStyle.plain)
          : RegionCard(region: regions[i], style: RegionCardStyle.plain),
      // 다음 장이 실패했으면 목록 끝에서 알리고 다시 부를 길을 준다 —
      // 받아 둔 카드는 그대로 둔다
      footer: _error != null && !_loading ? _buildNextPageError() : null,
    );
  }

  /// 카드 격자 + **목록 끝의 출처 한 줄**.
  ///
  /// 출처를 화면 아래 고정으로 두면 목록이 그 위에서 끝나, 인디케이터 자리가
  /// 빈 배경으로 남아 흰 띠처럼 보인다(#300). 다른 화면(코스 확정·후보 지역)
  /// 처럼 **목록의 마지막 항목**으로 넣어 함께 스크롤되게 한다 — 목록이
  /// 화면 끝까지 흐르고 그 아래 빈 자리가 생기지 않는다
  Widget _buildGrid(
    double cardExtent, {
    required int itemCount,
    required Widget Function(BuildContext, int) builder,
    ScrollController? controller,
    Widget? footer,
  }) {
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 24,
              mainAxisExtent: cardExtent,
            ),
            itemCount: itemCount,
            itemBuilder: builder,
          ),
        ),
        if (footer != null) SliverToBoxAdapter(child: footer),
        SliverToBoxAdapter(
          // **어느 응답을 그리는지에 따라 갈린다** — 장소 카드를 쓰는
          // 중이면 홈 응답의 출처고, 지역 목록으로 폴백했으면 그쪽이다.
          // 섞으면 안 쓴 출처를 표기하게 된다
          child: DataSourceNote(
            sources: _shownSources,
            // 카드와 출처 사이는 **24** — 내 코스 상세·장소 상세·코스 확정이
            // 쓰는 값과 같다. 아래로는 인디케이터만큼 흘려 보낸다
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12 + context.bottomInset),
          ),
        ),
      ],
    );
  }

  /// 다음 장을 못 불러왔을 때 목록 끝에 두는 한 줄 — 누르면 그 장을 다시 부른다
  Widget _buildNextPageError() {
    return Semantics(
      button: true,
      label: '더 불러오지 못했어요. 다시 시도',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _load,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '더 불러오지 못했어요',
                style: AppTypography.label1NormalMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '다시 시도',
                style: AppTypography.label1NormalBold.copyWith(
                  color: AppColors.primaryNormal,
                ),
              ),
            ],
          ),
        ),
      ),
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
    return AppTitleBar(
      title: '이번달 추천 여행지',
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.home),
    );
  }

  Widget _buildCategoryRow() {
    return CategoryChipRow(
      // 구성·순서는 서버가 정한다. 응답 전에는 기본 구성으로 자리를 지킨다
      filters: ref.watch(homeSnapshotProvider).value?.filters,
      selected: _selected,
      onSelect: _selectCategory,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    );
  }
}
