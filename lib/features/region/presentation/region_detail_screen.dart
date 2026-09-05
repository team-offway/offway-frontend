import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/image_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/place_thumbnail.dart';
import '../../course/presentation/widgets/expandable_description.dart';
import '../domain/region_visit_metrics.dart';
import 'widgets/quietest_day_banner.dart';
import '../../policy/domain/region_benefit.dart';
import '../../policy/presentation/benefit_badge.dart';
import '../../policy/presentation/region_benefit_card.dart';
import '../data/region_detail_repository.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/data_source_note.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';

/// 지역 상세 — `GET /regions/{id}` 하나로 채운다(core #307).
///
/// 예전에는 mock과 홈 카드, 장소 목록 셋을 섞었다. 그 조합으로 만든 장소에는
/// 사진이 없어 시안의 카드가 회색 판으로 남았다.

/// 매력 포인트 장소 개수 — 시안 노트: 최소 2 ~ 최대 10
const kMaxHighlightSpots = 10;

/// 매력 포인트 장소 카드 — 시안 실측
const _spotCardWidth = 190.0;
const _spotCardHeight = 220.0;

final regionDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, regionId) async {
      final data = await ref
          .watch(regionDetailRepositoryProvider)
          .detail(regionId);

      // 서버는 name에 시군구와 시도를 이미 합쳐 준다("동구 · 부산광역시")
      final spots =
          (data['highlightSpots'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];

      return {
        'id': regionId,
        'name': data['name'],
        // 혜택은 서버가 홈·장소 상세와 같은 모양으로 준다(core #418) —
        // 필드를 흩지 않고 통째로 넘긴다
        'benefit': data['benefit'],
        'photos': (data['photos'] as List?)?.cast<String>() ?? const <String>[],
        // 서버가 그 지역에 실제로 있는 것의 이름으로 만든 한 줄 문장이다(core #140).
        // 문단이 아니라 한 줄이라 펼치기 chevron은 쓸 자리가 없다
        if ((data['overview'] as String?)?.isNotEmpty ?? false)
          'story': data['overview'],
        // 공공데이터 출처 (core #417) — 리포지토리가 래퍼에서 꺼내 실어 준다
        '_sources': data['_sources'] ?? const <DataSource>[],
        // 한산한 요일·인기 추세 (core #438). 객체는 늘 오고 안의 두 값이
        // 각각 비어 있을 수 있다 — 재료가 모자라면 서버가 지어내지 않는다
        'visitMetrics': RegionVisitMetrics.parse(data['visitMetrics']),
        // 사진 없는 장소와 상한(10)은 서버가 이미 처리해 준다 — 앱에서 또
        // 자르면 세는 쪽과 그리는 쪽이 갈린다
        'highlightSpots': [
          for (final s in spots.take(kMaxHighlightSpots))
            {
              'name': s['name'],
              'caption': s['catchphrase'] ?? '',
              if (s['imageUrl'] != null) 'imageUrl': s['imageUrl'],
              if (s['poiContentId'] != null) 'poiContentId': s['poiContentId'],
            },
        ],
      };
    });

/// 지역 상세 정보 — 소개글·대표 이미지·매력 포인트 장소
class RegionDetailScreen extends ConsumerWidget {
  const RegionDetailScreen({super.key, required this.regionId});

  final String regionId;

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  // 소개글 본문
  static const _storyText = AppColors.labelNeutral;
  // 화면 끝 인구감소지역 안내 — 제목은 진하게, 설명은 흐리게
  static const _noteTitle = AppColors.labelStrong;
  static const _noteBody = AppColors.labelAlternative;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(regionDetailProvider(regionId));

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: region.when(
          loading: () => const AppCircularLoadingView(),
          error: (e, _) => AppErrorView(
            onRetry: () => ref.invalidate(regionDetailProvider(regionId)),
          ),
          data: (data) => data == null
              ? const Center(
                  child: AppEmptyView(
                    illustrationAsset: 'assets/icons/ic_empty_map.svg',
                    title: '지역 소개를 준비하고 있어요',
                    description: '조금만 기다려 주세요',
                  ),
                )
              : _buildBody(context, data),
        ),
      ),
      // 가이드에 이 화면은 하단 탭이 없다 — 상세는 뒤로가기로 돌아가는
      // 화면이라 탭이 떠 있으면 어느 탭 소속인지부터 헷갈린다
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> region) {
    final photos = (region['photos'] as List?)?.cast<String>() ?? const [];
    final spots =
        (region['highlightSpots'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    final benefit = RegionBenefit.tryParse(region['benefit']);

    return ListView(
      // 120은 하단 탭에 가리지 않기 위한 값이었다 — 탭을 뺐으니(가이드)
      // 홈 인디케이터 몫만 남긴다. 시안 실측 62
      padding: const EdgeInsets.only(bottom: 62),
      children: [
        _buildTopBar(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // 서버가 "동구 · 부산광역시" 형태로 합쳐 준다
                region['name'] as String? ?? '',
                // 가이드는 Heading 1/Bold(22·w600)다 — w700로 두면 더 두껍게 보인다
                style: AppTypography.heading1Bold.copyWith(color: _labelNormal),
              ),
              if (benefit != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BenefitBadge(
                    benefit: benefit,
                    size: BenefitBadgeSize.regionDetail,
                  ),
                ),
              ],
            ],
          ),
        ),
        // 시안: 뱃지 아래 16 → 소개글 → 사진. 사진이 먼저 오면 지역이
        // 어떤 곳인지 읽기 전에 스크롤부터 하게 된다
        if ((region['story'] as String?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ExpandableDescription(
              text: region['story'] as String,
              style: AppTypography.label1NormalMedium.copyWith(
                color: _storyText,
              ),
              semanticsLabel: '지역 소개',
            ),
          ),
        ],
        const SizedBox(height: 24),
        // 언제 가면 덜 붐비는지 (core #438) — 사진 위에 둔다. 값이 없으면
        // 위젯이 스스로 자리를 비운다
        if (region['visitMetrics'] case final RegionVisitMetrics m
            when m.quietestDay != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: QuietestDayBanner(quietestDay: m.quietestDay),
          ),
        ],
        _PhotoCarousel(photos: photos),
        const SizedBox(height: 36),
        if (spots.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              // 제목에는 시군구만 넣는다 — 서버 name은 "정선군 · 강원"처럼
              // 시도까지 붙어 있어 그대로 쓰면 '… 강원 매력 포인트 장소'가 된다
              '${(region['name'] as String? ?? '').split(' · ').first}'
              ' 매력 포인트 장소',
              // 가이드는 Headline 1/Bold(18)다
              style: AppTypography.headline1Bold.copyWith(color: _labelNormal),
            ),
          ),
          const SizedBox(height: 14),
          // 최대 10개까지 오므로 2열 그리드에 가둘 수 없다 — 옆으로 넘긴다
          SizedBox(
            height: _spotCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: spots.length,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (context, i) => _SpotCard(
                spot: spots[i],
                regionName: region['name'] as String? ?? '',
              ),
            ),
          ),
        ],
        // 이 지역에서 누릴 수 있는 혜택 — 매력 포인트를 훑은 다음 자리가
        // 맞다. 안내 문구(_PopulationDeclineNote)는 화면을 맺는 말이라 끝에 둔다.
        //
        // **혜택이 있는 지역에만 뜬다.** 예전에는 이 자리에 큐레이션 링크
        // (대한민국 구석구석·국가유산포털)를 그렸는데, 그 둘은 모든 지역에
        // 똑같이 붙는 고정 링크라 혜택이 없는 지역에서도 "혜택이 있어요"라고
        // 말했다. 시안(18761:72093)이 여기에 두는 것은 혜택 카드 하나다
        if (benefit != null) ...[
          const SizedBox(height: 44),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이 지역에서 누릴 수 있는 혜택이 있어요',
                  style: AppTypography.headline2Bold.copyWith(
                    color: _labelNormal,
                  ),
                ),
                // 시안 실측: 제목 아래 42 — 제목 프레임(26) 다음이 16이다
                const SizedBox(height: 16),
                RegionBenefitCard(benefit: benefit),
              ],
            ),
          ),
        ],
        // 시안 실측: 혜택 카드 아래 36
        const SizedBox(height: 36),
        const _PopulationDeclineNote(),
        // 공공데이터 출처 (core #417) — 화면을 맺는 안내 아래에 텍스트 한 줄
        DataSourceNote(
          sources:
              (region['_sources'] as List?)?.cast<DataSource>() ??
              const <DataSource>[],
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      // 버튼(44)이 아이콘(12)보다 넓어 좌측 여백을 줄여야 잉크가 다른
      // 화면들과 같은 자리(x=22)에 온다 — h14·v8은 오른쪽·아래로 밀렸었다
      padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
      child: Row(
        // 시안에는 뒤로가기만 있다. 공유 버튼이 있었으나 누르면 아무 일도
        // 일어나지 않아 고장난 것처럼 보였다 — 정책이 정해지면 시안과 함께
        // 다시 넣는다
        children: [AppBackButton(onTap: () => context.pop())],
      ),
    );
  }
}

/// 대표 이미지 캐러셀 — 좌우로 넘기고 현재 위치를 1/7 형태로 표시
class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos});

  final List<String> photos;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: 237,
          child: Stack(
            children: [
              Positioned.fill(
                child: total == 0
                    ? const PlaceThumbnail(
                        imageUrl: null,
                        width: double.infinity,
                        height: double.infinity,
                        radius: 0,
                        iconSize: 64,
                      )
                    : PageView.builder(
                        controller: _controller,
                        itemCount: total,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => PlaceThumbnail(
                          imageUrl: widget.photos[i],
                          width: double.infinity,
                          height: double.infinity,
                          radius: 0,
                          iconSize: 64,
                        ),
                      ),
              ),
              if (total > 1)
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x66000000),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1}/$total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 매력 포인트 장소 카드 — 시안 실측 190×220, 반경 12.
///
/// 탭하면 장소 상세로 간다. 사진 위에 이름을 얹으므로 밝은 사진에서도
/// 글자가 읽히도록 아래쪽을 어둡게 깐다.
class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot, required this.regionName});

  final Map<String, dynamic> spot;

  /// 장소 상세 상단바에 띄울 지역명 — 어디를 보다 들어왔는지 남긴다
  final String regionName;

  @override
  Widget build(BuildContext context) {
    final imageUrl = spot['imageUrl'] as String?;
    final name = spot['name'] as String? ?? '';
    final contentId = spot['poiContentId']?.toString();

    return GestureDetector(
      // 아직 id가 없는 mock 지역은 눌러도 갈 곳이 없다
      onTap: contentId == null
          ? null
          : () => context.push(
              AppRoutes.poiDetailPath(
                contentId,
                name: name,
                regionName: regionName,
              ),
            ),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        // 사진처럼 대비가 큰 가장자리는 기본 antiAlias 로 자르면
        // 모서리에 계단이 비친다
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: SizedBox(
          width: _spotCardWidth,
          height: _spotCardHeight,
          // 그라데이션과 이름은 **사진이 실제로 뜬 뒤에만** 얹는다.
          //
          // 예전에는 늘 깔려 있어서, 사진이 없거나 로딩에 실패하면 회색 자리
          // 위에 검정 띠만 남았다(QA). 가이드는 그 경우를 스켈레톤(로딩)과
          // 아이콘(실패)으로만 둔다 — 이름 없이.
          child: imageUrl == null
              ? const _SpotFallback()
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  cacheManager: appImageCacheManager,
                  fit: BoxFit.cover,
                  // 디스크 캐시 + 카드 폭까지만 디코드 (PlaceThumbnail과 같은 이유)
                  memCacheWidth: PlaceThumbnail.decodeWidthFor(
                    context,
                    _spotCardWidth,
                  ),
                  // 페이드 없이 즉시 — PlaceThumbnail과 같은 이유
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  // 받는 동안은 스켈레톤만 둔다
                  placeholder: (_, _) => const _SpotFallback(showIcon: false),
                  errorWidget: (_, _, _) => const _SpotFallback(),
                  // 사진이 실제로 뜬 뒤에만 그라데이션과 이름을 얹는다.
                  // imageBuilder에 오는 provider에는 memCacheWidth가 안 걸려
                  // 있다 — 여기서 다시 감싸지 않으면 원본 크기로 디코드한다
                  imageBuilder: (context, provider) => Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: ResizeImage(
                          provider,
                          width: PlaceThumbnail.decodeWidthFor(
                            context,
                            _spotCardWidth,
                          ),
                        ),
                        fit: BoxFit.cover,
                      ),
                      _SpotNameOverlay(name: name),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// 사진이 없을 때의 자리 — 가이드의 Skeleton(5% 회색) 위 이미지 아이콘.
/// 로딩 중에는 [showIcon]을 꺼 스켈레톤만 남긴다
class _SpotFallback extends StatelessWidget {
  const _SpotFallback({this.showIcon = true});

  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.fillAlternative,
      alignment: Alignment.center,
      child: showIcon
          ? SvgPicture.asset(
              'assets/icons/ic_image.svg',
              // 가이드 실측 36
              width: 36,
              height: 36,
              colorFilter: const ColorFilter.mode(
                AppColors.labelDisable,
                BlendMode.srcIn,
              ),
            )
          : null,
    );
  }
}

/// 사진 위에 얹는 장소명 — 흰 글자가 묻히지 않게 아래를 어둡게 깐다
class _SpotNameOverlay extends StatelessWidget {
  const _SpotNameOverlay({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        child: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.467,
            shadows: [Shadow(blurRadius: 12, color: Color(0x29000000))],
          ),
        ),
      ),
    );
  }
}

/// 화면 맨 아래 안내 — 이 지역이 왜 추천되는지 한 줄로 남긴다.
///
/// 예전에는 이 자리에 '기본 정보'(교통편·지정 안내)가 있었다. 시안이
/// 그 자리를 이 문구로 바꿨다 — 개별 지역의 사실 나열보다, 여기 모인
/// 지역들이 어떤 곳인지 말하는 편이 이 화면의 끝맺음에 맞는다.
class _PopulationDeclineNote extends StatelessWidget {
  const _PopulationDeclineNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/icons/ic_heart_fill.svg',
            width: 48,
            height: 48,
          ),
          // 시안: 하트 아래 24
          const SizedBox(height: 24),
          Text(
            '새롭게 주목받는 인구감소지역이에요',
            textAlign: TextAlign.center,
            style: AppTypography.headline2Bold.copyWith(
              color: RegionDetailScreen._noteTitle,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '익숙한 여행지에서 조금 벗어나,\n지역의 새로운 매력을 만나보세요.',
            textAlign: TextAlign.center,
            style: AppTypography.body2NormalMedium.copyWith(
              color: RegionDetailScreen._noteBody,
            ),
          ),
        ],
      ),
    );
  }
}
