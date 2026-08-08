import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_tab_pills.dart';
import '../../../core/widgets/app_toast.dart';
import '../../region/presentation/widgets/region_card.dart';
import '../data/home_repository.dart';

/// 홈 API 한 번으로 사용자·추천지역을 함께 받는다.
/// 온보딩에서 연차를 저장한 뒤에는 invalidate로 다시 불러온다.
final homeSnapshotProvider = FutureProvider<HomeSnapshot>(
  (ref) => ref.watch(homeRepositoryProvider).fetch(),
);

/// 다른 화면(마이·기간스타일)도 읽는 사용자 정보 — 이름을 유지해 결합을 끊지 않는다
final homeUserProvider = FutureProvider<Map<String, dynamic>>(
  (ref) async => (await ref.watch(homeSnapshotProvider.future)).user,
);
final homeRegionsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(homeSnapshotProvider.future)).regions,
);

/// 카테고리 키별 아이콘 — 구성·순서·라벨은 서버(filters)가 정하고 그림만 앱이 가진다
const _categoryIcons = <String, String>{
  'ALL': 'assets/icons/ic_cat_all.svg',
  'SIGHT': 'assets/icons/ic_cat_sight.svg',
  'STAY': 'assets/icons/ic_cat_stay.svg',
  'EXPERIENCE': 'assets/icons/ic_cat_experience.svg',
  'FOOD': 'assets/icons/ic_cat_food.svg',
};

/// 서버 응답이 오기 전에도 칩 자리가 비지 않도록 쓰는 기본 구성
const _defaultFilters = [
  {'key': 'ALL', 'label': '전체'},
  {'key': 'SIGHT', 'label': '관광지'},
  {'key': 'STAY', 'label': '숙박'},
  {'key': 'EXPERIENCE', 'label': '체험'},
  {'key': 'FOOD', 'label': '맛집'},
];

/// 히어로 카드 CTA 배경 — Figma가 Atomic Neutral/22(#303030)를 직접 쓴다
const _heroCtaBackground = AppPalette.neutral22;

/// O-03 · 홈
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 로딩 중 깔아둘 지역 카드 자리 수 — 첫 화면에 걸쳐 보이는 만큼만
  static const _skeletonCardCount = 3;

  /// 고른 칩 `{key, label}` — null이면 '전체'
  Map<String, dynamic>? _selected;

  /// 선택된 카테고리의 콘텐츠가 있는 지역만 남긴다 (목록 화면과 같은 규칙)
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    final selected = _selected;
    if (selected == null || selected['key'] == 'ALL') return all;
    return all.where((r) {
      final counts = r['categoryCounts'] as Map<String, dynamic>?;
      return (counts?[selected['label']] as int? ?? 0) > 0;
    }).toList();
  }

  void _showPreparing(String feature) {
    showAppToast(context, '$feature 기능은 준비 중이에요');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(homeUserProvider);
    final regions = ref.watch(homeRegionsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 120),
          children: [
            _buildTopBar(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildLeaveCard(user),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildHeroCard(context, user),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '이번달 추천 여행지',
                    style: AppTypography.heading2Bold.copyWith(
                      color: AppColors.labelNormal,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.regionList),
                    child: Text(
                      '더보기',
                      style: AppTypography.headline2Regular.copyWith(
                        color: AppColors.labelAlternative,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 가이드: 섹션 제목~칩 34, 칩~카드 20
            const SizedBox(height: 34),
            _buildCategoryRow(),
            const SizedBox(height: 20),
            _buildRegionCards(regions),
          ],
        ),
      ),
      bottomNavigationBar: AppTabPills(
        current: AppTab.home,
        onTap: (tab) {
          // 탭끼리는 형제 화면이므로 스택을 쌓지 않고 교체한다
          if (tab == AppTab.myCourse) context.go(AppRoutes.myCourses);
          if (tab == AppTab.my) context.go(AppRoutes.my);
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/logo_wordmark.svg',
            height: 24,
            semanticsLabel: 'OffWay',
          ),
          const Spacer(),
          GestureDetector(
            // TODO(notification): 알림 기능 정책 확정 시 연결
            onTap: () => _showPreparing('알림'),
            child: SvgPicture.asset(
              'assets/icons/ic_bell.svg',
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(AsyncValue<Map<String, dynamic>> user) {
    final days = user.value?['remainingLeaveDays'];
    return GestureDetector(
      // TODO(my-leave): 내 연차 화면 디자인 확정 후 연결
      onTap: () => _showPreparing('내 연차'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundNormalAlternative,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.backgroundNormal,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/icons/ic_timer.svg',
                width: 26,
                height: 26,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '남은 연차 일수',
              style: AppTypography.body1NormalMedium.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              // 서버가 double로 주므로(반차 0.5 단위) 15.0일로 보이지 않게 다듬는다
              days == null ? '-' : '${formatLeaveDays(days as num)}일',
              style: AppTypography.body1NormalBold.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const Spacer(),
            SvgPicture.asset(
              'assets/icons/ic_chevron_right.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppColors.labelAlternative,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> user,
  ) {
    final nickname = user.value?['nickname'] ?? '오프웨이';
    return Container(
      height: 230,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundNormalAlternative,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 카드 패딩 밖으로 나가 아래·왼쪽에 걸치는 배경 일러스트.
          // 문구·버튼보다 먼저 그려 뒤에 깔리게 한다.
          // 발밑은 카드 바닥에 잘려 들어간다 — 띄우면 붕 뜬 것처럼 보인다.
          Positioned(
            left: -7,
            bottom: -24,
            child: SvgPicture.asset(
              'assets/images/home_hero_character.svg',
              width: 228,
              excludeFromSemantics: true,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$nickname님, 어디로 떠나볼까요?',
                style: AppTypography.heading2Bold.copyWith(
                  color: AppColors.labelNormal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '연차에 맞춘 추천 코스를 알려드려요!',
                style: AppTypography.label2Medium.copyWith(
                  color: AppColors.labelNeutral,
                ),
              ),
            ],
          ),
          Positioned(
            // 시안 좌표 기준 버튼은 카드 오른쪽·아래에서 각각 18 (카드 패딩 24 보정)
            right: -6,
            bottom: -6,
            child: FilledButton(
              onPressed: () => context.push(AppRoutes.wizardDateGate),
              style: FilledButton.styleFrom(
                // TODO(디자인시스템): 디자인이 Atomic Neutral/22를 직접 참조한다.
                // 이 검정을 가리키는 Semantic 토큰이 생기면 그걸로 교체할 것.
                backgroundColor: _heroCtaBackground,
                foregroundColor: AppColors.staticWhite,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                // 가이드 버튼 크기 123×40 — 글자 높이에 맡기면 38로 줄어든다
                minimumSize: const Size(0, 40),
                fixedSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('바로 추천받기', style: AppTypography.body2NormalBold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    // 구성·순서는 서버가 정한다. 응답 전에는 기본 구성으로 자리를 지킨다
    final filters =
        ref.watch(homeSnapshotProvider).value?.filters ?? _defaultFilters;
    final chips = filters.isEmpty ? _defaultFilters : filters;
    return Padding(
      // 가이드는 칩 줄만 21에서 시작해 화면 폭에 균등 배치된다
      padding: const EdgeInsets.symmetric(horizontal: 21),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final filter in chips)
            _CategoryChip(
              label: filter['label'] as String,
              iconAsset:
                  _categoryIcons[filter['key']] ?? _categoryIcons['ALL']!,
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

  Widget _buildRegionCards(AsyncValue<List<Map<String, dynamic>>> regions) {
    return SizedBox(
      height: 230,
      child: regions.when(
        // 스피너 대신 카드가 들어올 자리를 미리 잡아둔다 (O-03 스켈레톤)
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _skeletonCardCount,
          separatorBuilder: (_, _) => const SizedBox(width: 20),
          itemBuilder: (_, _) => const RegionCardSkeleton(),
        ),
        // 서버 detail이 사용자 문구라 그대로 보여준다. 그 외에는 원인을 감춘다
        error: (e, _) => Center(
          child: Text(
            e is ApiException ? e.detail : '추천 여행지를 불러오지 못했어요',
            textAlign: TextAlign.center,
            style: AppTypography.label1NormalMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ),
        data: (all) {
          final list = _filter(all);
          if (list.isEmpty) {
            return Center(
              child: Text(
                '해당 카테고리의 여행지가 아직 없어요',
                style: AppTypography.label1NormalMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 20),
            itemBuilder: (context, i) => RegionCard(region: list[i]),
          );
        },
      ),
    );
  }
}

/// 카테고리 칩 — 선택되면 Primary 테두리와 진한 라벨
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: AppColors.backgroundNormalAlternative,
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: AppColors.primaryNormal, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(iconAsset, width: 29, height: 29),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style:
                (selected
                        ? AppTypography.caption2Bold
                        : AppTypography.caption2Regular)
                    .copyWith(
                      color: selected
                          ? AppColors.labelNeutral
                          : AppColors.labelAlternative,
                    ),
          ),
        ],
      ),
    );
  }
}
