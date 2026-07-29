import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_tab_pills.dart';
import '../../../mock/mock_data_source.dart';
import '../../region/presentation/widgets/region_card.dart';

/// 홈 mock 데이터 (서버 연동 시 repository 프로바이더로 교체)
final homeUserProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => MockDataSource.user(),
);
final homeRegionsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => MockDataSource.allRegions(),
);

/// 홈 카테고리 칩 정의 ('전체'는 필터 없음)
enum _Category {
  all('전체', 'assets/icons/ic_cat_all.svg'),
  sight('관광지', 'assets/icons/ic_cat_sight.svg'),
  stay('숙박', 'assets/icons/ic_cat_stay.svg'),
  experience('체험', 'assets/icons/ic_cat_experience.svg'),
  food('맛집', 'assets/icons/ic_cat_food.svg');

  const _Category(this.label, this.iconAsset);

  final String label;
  final String iconAsset;
}

/// O-03 · 홈
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _Category _selected = _Category.all;

  /// 선택된 카테고리의 콘텐츠가 있는 지역만 남긴다 (목록 화면과 같은 규칙)
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    if (_selected == _Category.all) return all;
    return all.where((r) {
      final counts = r['categoryCounts'] as Map<String, dynamic>?;
      return (counts?[_selected.label] as int? ?? 0) > 0;
    }).toList();
  }

  void _showPreparing(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature 기능은 준비 중이에요')));
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            _buildCategoryRow(),
            const SizedBox(height: 16),
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
              days == null ? '-' : '$days일',
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
      child: Stack(
        children: [
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
            right: 0,
            bottom: 0,
            child: FilledButton(
              onPressed: () => context.push(AppRoutes.wizardDateGate),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNormal,
                foregroundColor: AppColors.staticWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 9,
                ),
                minimumSize: Size.zero,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final category in _Category.values)
            _CategoryChip(
              category: category,
              selected: _selected == category,
              onTap: () => setState(() => _selected = category),
            ),
        ],
      ),
    );
  }

  Widget _buildRegionCards(AsyncValue<List<Map<String, dynamic>>> regions) {
    return SizedBox(
      height: 230,
      child: regions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('추천 여행지를 불러오지 못했어요\n$e')),
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
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _Category category;
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
            child: SvgPicture.asset(category.iconAsset, width: 29, height: 29),
          ),
          const SizedBox(height: 6),
          Text(
            category.label,
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
