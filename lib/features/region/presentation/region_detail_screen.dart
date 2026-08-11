import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_error_view.dart';
import '../data/region_places_repository.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_tab_pills.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../mock/mock_data_source.dart';
import '../../home/presentation/home_screen.dart' show homeSnapshotProvider;

/// 지역 상세 mock.
///
/// TODO(server): 지역 상세 API가 없다. 서버 홈 응답에는 소개글·매력 포인트가
/// 실리지 않아 화면을 채울 수 없어 mock을 유지한다.
///
/// 다만 홈·목록은 서버 데이터를 쓰므로 넘어오는 id가 숫자("1")다.
/// mock은 지역 이름("정선")을 키로 쓰므로, 서버 목록에서 이름을 찾아 이어준다.
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

      // 서버 id로 들어왔으면 그 지역의 이름으로 다시 찾는다
      try {
        final snapshot = await ref.watch(homeSnapshotProvider.future);
        for (final r in snapshot.regions) {
          if (r['id'] == regionId) {
            return findBy(r['name'] as String? ?? '');
          }
        }
      } on Exception {
        // 서버를 못 부르면 못 찾은 것으로 둔다
      }
      return null;
    });

/// 지역 상세 정보 — 대표 이미지·소개·매력 포인트 장소·기본 정보
class RegionDetailScreen extends ConsumerWidget {
  const RegionDetailScreen({super.key, required this.regionId});

  final String regionId;

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _bodyText = Color(0xFF6F767E);
  static const _infoText = Color(0xFF666666);
  static const _divider = Color(0xFFF2F3F6);
  static const _imagePlaceholder = Color(0xFFC5C8CE);
  static const _badgeBg = Color(0x293182F6); // rgba(49,130,246,0.16)
  static const _badgeText = Color(0xFF2272EB);

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
              ? _ServerRegionBody(regionId: regionId)
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
        const SizedBox(height: 16),
        _PhotoCarousel(photos: photos),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (region['headline'] as String?) ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                (region['story'] as String?) ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: _bodyText,
                  height: 24 / 14,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(height: 10, color: _divider),
        const SizedBox(height: 24),
        if (spots.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${region['name']} 매력 포인트 장소',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _labelNormal,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < spots.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: _SpotCard(spot: spots[i])),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(height: 10, color: _divider),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '기본 정보',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _labelNormal,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in [
                      region['transitInfo'] as String?,
                      region['designationNote'] as String?,
                    ])
                      if (line != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            line,
                            style: const TextStyle(
                              fontSize: 15,
                              color: _infoText,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          AppBackButton(onTap: () => context.pop()),
          const Spacer(),
          GestureDetector(
            // TODO(share): 지역 공유 기능 정책 확정 시 연결
            onTap: () {},
            child: const Icon(Icons.ios_share, size: 24, color: _labelNormal),
          ),
        ],
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
                    ? Container(color: RegionDetailScreen._imagePlaceholder)
                    : PageView.builder(
                        controller: _controller,
                        itemCount: total,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => Image.network(
                          widget.photos[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: RegionDetailScreen._imagePlaceholder,
                          ),
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

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot});

  final Map<String, dynamic> spot;

  @override
  Widget build(BuildContext context) {
    final imageUrl = spot['imageUrl'] as String?;
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        height: 188,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: RegionDetailScreen._imagePlaceholder,
              child: imageUrl == null
                  ? null
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
            ),
            // 이미지 위 글자 가독성 확보
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              right: 12,
              child: Text(
                spot['name'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// mock에 없는 서버 지역(89곳)의 상세.
///
/// 소개글·매력 포인트는 서버에 없지만 관광명소 목록은 받을 수 있다.
/// 빈 화면 대신 그 목록으로 채운다.
class _ServerRegionBody extends ConsumerWidget {
  const _ServerRegionBody({required this.regionId});

  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sights = ref.watch(regionSightsProvider(regionId));

    // 뒤로가기는 어떤 상태에서도 있어야 한다 — 목록이 비거나 실패해도
    // 이전 화면으로 돌아갈 수 있어야 갇히지 않는다
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 20, 0),
          child: Row(
            children: [
              AppBackButton(onTap: () => context.pop()),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '가볼 만한 곳',
                  style: AppTypography.headline1Bold.copyWith(
                    color: AppColors.labelNormal,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sights.when(
            loading: () => const AppCircularLoadingView(),
            error: (e, _) => AppErrorView(
              onRetry: () => ref.invalidate(regionSightsProvider(regionId)),
            ),
            data: (places) => places.isEmpty
                ? const Center(
                    child: AppEmptyView(
                      illustrationAsset: 'assets/icons/ic_empty_map.svg',
                      title: '지역 소개를 준비하고 있어요',
                      description: '조금만 기다려 주세요',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    children: [
                      for (final place in places) _ServerPlaceRow(place: place),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// 서버 장소 한 줄 — 인허가 데이터라 사진이 없다. 이름·분류·주소만 보여준다
class _ServerPlaceRow extends StatelessWidget {
  const _ServerPlaceRow({required this.place});

  final Map<String, dynamic> place;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (place['name'] as String?) ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body1NormalBold.copyWith(
              color: AppColors.labelNormal,
            ),
          ),
          if (place['categoryLabel'] case final String label) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.label2Medium.copyWith(
                color: AppColors.primaryNormal,
              ),
            ),
          ],
          if (place['address'] case final String address) ...[
            const SizedBox(height: 2),
            Text(
              address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label2Regular.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
