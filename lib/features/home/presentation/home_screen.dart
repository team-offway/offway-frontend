import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
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

/// O-03 · 홈 (와이어프레임)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _textGray = Color(0xFF3A3A3A);
  static const _textMuted = Color(0xFF707070);
  static const _cardGray = Color(0xFFF7F7F7);
  static const _heroBg = Color(0xFFECF0F3);
  static const _chipGray = Color(0xFFF2F3F6);
  static const _imagePlaceholder = Color(0xFFC5C8CE);

  static const _categories = ['전체', '관광지', '숙박', '체험', '맛집'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(homeUserProvider);
    final regions = ref.watch(homeRegionsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SvgPicture.asset(
                'assets/icons/logo_wordmark.svg',
                height: 30,
                semanticsLabel: 'OffWay',
              ),
            ),
            const SizedBox(height: 16),
            _buildLeaveCard(user),
            const SizedBox(height: 12),
            _buildHeroCard(context, user),
            const SizedBox(height: 36),
            Row(
              children: [
                const Text(
                  '이번달 추천 여행지',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _labelNormal,
                    letterSpacing: -0.6,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push(AppRoutes.regionList),
                  child: const Text(
                    '더보기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _textMuted,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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

  Widget _buildLeaveCard(AsyncValue<Map<String, dynamic>> user) {
    final days = user.value?['remainingLeaveDays'];
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _cardGray,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/calendar_check.svg',
            width: 32,
            height: 32,
          ),
          const SizedBox(width: 12),
          const Text(
            '남은 연차 일수',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textGray,
              letterSpacing: -0.6,
            ),
          ),
          const Spacer(),
          Text(
            days == null ? '-' : '$days일',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textGray,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> user,
  ) {
    final nickname = user.value?['nickname'] ?? '오프웨이';
    return Container(
      height: 217,
      decoration: BoxDecoration(
        color: _heroBg,
        borderRadius: BorderRadius.circular(15),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -43,
            child: Image.asset(
              'assets/images/home_character.png',
              width: 354,
              height: 255,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            left: 21,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$nickname님, 어디로 떠날까요?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textGray,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '연차에 맞춘 추천 코스를 알려드려요!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textGray,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 15,
            bottom: 17,
            child: SizedBox(
              width: 123,
              height: 40,
              child: FilledButton(
                onPressed: () => context.push(AppRoutes.wizardDateGate),
                style: FilledButton.styleFrom(
                  backgroundColor: _imagePlaceholder,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '바로 추천받기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final label in _categories)
          Column(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: _chipGray,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _textMuted,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRegionCards(AsyncValue<List<Map<String, dynamic>>> regions) {
    return SizedBox(
      height: 229,
      child: regions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('추천 여행지를 불러오지 못했어요\n$e')),
        data: (list) => ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) => RegionCard(region: list[i]),
        ),
      ),
    );
  }
}
