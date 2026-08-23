import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/place_thumbnail.dart';
import '../../course/presentation/widgets/expandable_description.dart';
import '../data/region_places_repository.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_tab_pills.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../mock/mock_data_source.dart';
import '../../home/presentation/home_screen.dart' show homeSnapshotProvider;

/// 지역 상세.
///
/// 지역 상세 전용 API는 아직 없다. 두 갈래로 채운다.
/// - mock에 있는 지역(정선·영월 등): 소개글·사진까지 갖춘 mock을 그대로 쓴다
/// - 서버 89개 지역: 홈 카드 정보 + 장소 목록(`/regions/{id}/places`)으로
///   같은 형태를 만들어 준다. 소개글·사진은 없어 그 칸은 비워둔다
/// 매력 포인트 장소 개수 — 시안 노트: 최소 2 ~ 최대 10
const kMaxHighlightSpots = 10;

/// 매력 포인트 장소 카드 — 시안 실측
const _spotCardWidth = 190.0;
const _spotCardHeight = 220.0;

final regionDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, regionId) async {
      final all = await MockDataSource.allRegions();

      Map<String, dynamic>? findBy(String key) {
        for (final r in all) {
          if (r['id'] == key || r['name'] == key) return r;
        }
        return null;
      }

      final direct = findBy(regionId);
      if (direct != null) return direct;

      // 서버 지역 — 홈 카드에서 이름·이미지를 얻고 장소로 매력 포인트를 채운다.
      // 조회가 실패하면 그대로 던진다 — 화면이 재시도 가능한 에러로 받는다.
      // null은 '그런 지역이 없다'는 뜻으로만 쓴다
      final snapshot = await ref.watch(homeSnapshotProvider.future);
      Map<String, dynamic>? card;
      for (final r in snapshot.regions) {
        if (r['id'] == regionId) {
          card = r;
          break;
        }
      }
      if (card == null) return null;

      // mock에 같은 이름이 있으면 소개글까지 갖춘 그쪽이 낫다
      final byName = findBy(card['name'] as String? ?? '');
      if (byName != null) return byName;

      final sights = await ref.watch(regionSightsProvider(regionId).future);
      return {
        'id': regionId,
        'name': card['name'],
        'sido': card['sido'],
        if (card['benefitBadge'] != null) 'benefitBadge': card['benefitBadge'],
        if (card['benefitPolicyId'] != null)
          'benefitPolicyId': card['benefitPolicyId'],
        // 대표 사진은 홈 카드 이미지 한 장뿐이다
        'photos': [if (card['imageUrl'] case final String url) url],
        // 인허가 데이터에는 사진·소개가 없어 이름과 분류만 채운다.
        // id를 함께 실어 탭하면 장소 상세로 갈 수 있게 한다
        'highlightSpots': [
          for (final p in sights.take(kMaxHighlightSpots))
            {
              'name': p['name'],
              'caption': p['categoryLabel'] ?? '',
              if (p['id'] != null) 'poiContentId': p['id'],
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
  // 혜택 뱃지 — 시안 Badge와 같은 브랜드색 8% 배경 + 브랜드색 글자.
  // 예전에는 다른 파랑(#3182F6)을 쓰고 있어 카드 뱃지와 색이 달랐다
  static final _badgeBg = AppColors.primaryNormal.withValues(
    alpha: AppOpacity.o8,
  );
  static const _badgeText = AppColors.primaryNormal;
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
          // mock에 없는 지역(서버 89곳)은 소개글이 없다 —
          // 대신 서버가 주는 관광명소 목록으로 화면을 채운다
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
      bottomNavigationBar: AppTabPills(
        current: null,
        onTap: (tab) => switch (tab) {
          AppTab.home => context.go(AppRoutes.home),
          AppTab.myCourse => context.go(AppRoutes.myCourses),
          AppTab.my => context.go(AppRoutes.my),
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> region) {
    final photos = (region['photos'] as List?)?.cast<String>() ?? const [];
    final spots =
        (region['highlightSpots'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    final benefit = region['benefitBadge'] as String?;

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _buildTopBar(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${region['name']} · ${region['sido']}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: _labelNormal,
                  letterSpacing: -0.8,
                ),
              ),
              if (benefit != null) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _badgeBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    benefit,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _badgeText,
                    ),
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
        _PhotoCarousel(photos: photos),
        const SizedBox(height: 36),
        if (spots.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '${region['name']} 매력 포인트 장소',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _labelNormal,
              ),
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
        // 시안: 매력 포인트 아래 52 (카드 220 + 여백)
        const SizedBox(height: 52),
        const _PopulationDeclineNote(),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
/// 탭하면 장소 상세로 간다. 인허가 데이터에는 사진이 없어 회색 판만 남는
/// 경우가 많은데, 그래도 이름은 읽혀야 하므로 아래쪽을 어둡게 깐다.
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: AppColors.backgroundNormalAlternative,
                child: PlaceThumbnail(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  radius: 0,
                  iconSize: 48,
                ),
              ),
              Positioned(
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
                      shadows: [
                        Shadow(blurRadius: 12, color: Color(0x29000000)),
                      ],
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
