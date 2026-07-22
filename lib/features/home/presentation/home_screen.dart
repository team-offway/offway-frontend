import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../mock/mock_data_source.dart';

/// 홈 mock 데이터 (서버 연동 시 repository 프로바이더로 교체)
final homeUserProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => MockDataSource.user(),
);
final homeRegionsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final data = await MockDataSource.regions();
  return [
    ...(data['candidates'] as List).cast<Map<String, dynamic>>(),
    ...(data['monthlyPicks'] as List).cast<Map<String, dynamic>>(),
  ];
});

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
  static const _badgeBg = Color(0x293182F6); // rgba(49,130,246,0.16)
  static const _badgeText = Color(0xFF2272EB);
  static const _tabInactive = Color(0xFF6F767E);

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
            const Text(
              'offway',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.black,
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
                  // TODO(home): 추천 여행지 전체 목록 화면 연결
                  onTap: () {},
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
      bottomNavigationBar: const _HomeTabPills(),
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
          itemBuilder: (context, i) => _RegionCard(region: list[i]),
        ),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region});

  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context) {
    final imageUrl = region['imageUrl'] as String?;
    final badge = region['benefitBadge'] as String?;
    return Container(
      width: 177,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: HomeScreen._chipGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              height: 123,
              width: double.infinity,
              color: HomeScreen._imagePlaceholder,
              child: imageUrl == null
                  ? null
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${region['name']} · ${region['sido']}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HomeScreen._labelNormal,
              letterSpacing: -0.6,
            ),
          ),
          Text(
            (region['description'] as String?) ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: HomeScreen._textMuted,
              letterSpacing: -0.6,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: HomeScreen._badgeBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: HomeScreen._badgeText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 하단 플로팅 탭 (홈/내 코스/마이) — 내 코스·마이 화면은 추후 작업
class _HomeTabPills extends StatelessWidget {
  const _HomeTabPills();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xCCFFFFFF),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _TabPill(
                    label: '홈',
                    iconAsset: 'assets/icons/tab_home.svg',
                    active: true,
                  ),
                  SizedBox(width: 8),
                  _TabPill(
                    label: '내 코스',
                    iconAsset: 'assets/icons/tab_course.svg',
                  ),
                  SizedBox(width: 8),
                  _TabPill(label: '마이', iconAsset: 'assets/icons/tab_my.svg'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.iconAsset,
    this.active = false,
  });

  final String label;
  final String iconAsset;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2D3037) : HomeScreen._tabInactive;
    return Container(
      width: 72,
      height: double.infinity,
      decoration: BoxDecoration(
        color: active ? const Color(0x14000000) : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}
