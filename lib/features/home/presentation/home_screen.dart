import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/curated_link_card.dart';
import '../../../core/widgets/curated_link_section.dart';
import '../../auth/application/current_user_provider.dart';
import '../../../core/utils/nickname.dart';
import '../../course/presentation/trip_outcome_prompt.dart';
import '../../notification/application/notification_provider.dart'
    show hasUnreadNotificationsProvider;
import '../../region/presentation/widgets/category_chip.dart';
import '../../region/presentation/widgets/leave_pick_card.dart';
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

/// '이번 연차엔 여기 어때요?' — 지역 카드
final homeRegionsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(homeSnapshotProvider.future)).regions,
);

/// '이번달 추천 여행지' — 장소 카드 (core #305).
/// 배치가 채우기 전에는 비어 온다 — 그때는 섹션을 통째로 접는다
final homePlacesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async => (await ref.watch(homeSnapshotProvider.future)).places,
);

/// 잔여 연차가 없어 온보딩(연차 입력)으로 보내야 하는가.
///
/// **다 읽힌 값에서만 판단한다.** 재조회(invalidate) 중에는 Riverpod이
/// 이전 값을 `.value`에 남겨두는데, 로그아웃 직후에는 그 자리에 게스트
/// (연차 null)가 있다 — 그걸 보고 보내면 재로그인한 회원이 이미 등록한
/// 연차를 두고도 온보딩으로 끌려간다 (#132).
///
/// 못 읽었거나 실패한 것도 '연차가 없다'와 다르다 — 홈은 그대로 두고
/// 다음 조회를 기다린다.
bool leaveOnboardingNeeded(AsyncValue<Map<String, dynamic>> user) {
  if (user.isLoading) return false;
  final data = user.value;
  return data != null && data['remainingLeaveDays'] == null;
}

/// 홈 '이번달 추천 여행지'에 보여줄 장소 카드.
///
/// 칩으로 거른 뒤, **'전체'일 때는 한 줄 소개가 있는 장소만** 남긴다 —
/// 첫 화면에서 소개 없는 카드가 섞이면 줄이 들쭉날쭉해 성기게 보인다.
/// 카테고리를 고르면 그 갈래는 소개가 없어도 전부 보여준다(고른 사람은
/// 그 갈래를 다 보고 싶은 것이고, 숙박·음식은 소개가 늦게 채워진다).
List<Map<String, dynamic>> homePlacesForChip(
  List<Map<String, dynamic>> places,
  Map<String, dynamic>? selected,
) {
  final isAll = selected == null || selected['key'] == 'ALL';
  if (!isAll) {
    return places.where((p) {
      final counts = p['categoryCounts'] as Map<String, dynamic>?;
      return (counts?[selected['label']] as int? ?? 0) > 0;
    }).toList();
  }
  return places
      .where((p) => (p['description'] as String?)?.isNotEmpty ?? false)
      .toList();
}

/// 히어로 카드 CTA 배경 — Figma가 Atomic Neutral/22(#303030)를 직접 쓴다
const _heroCtaBackground = AppPalette.neutral22;

/// O-03 · 홈
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TripOutcomePrompt {
  /// 로딩 중 깔아둘 지역 카드 자리 수 — 첫 화면에 걸쳐 보이는 만큼만
  static const _skeletonCardCount = 3;

  /// '이번 연차엔 여기 어때요?' 카드 개수 — 시안 노트: 최소 3 ~ 최대 7
  static const _minLeavePicks = 3;
  static const _maxLeavePicks = 7;

  /// 지역 카드 아래에서 '이번 연차엔' 제목까지.
  ///
  /// 시안은 혜택 뱃지 글자 아래로 42다. 뱃지에 자체 아래 여백 3이 있어
  /// 그만큼 덜 준다
  static const _sectionGap = 39.0;

  /// 고른 칩 `{key, label}` — null이면 '전체'
  Map<String, dynamic>? _selected;

  /// 선택된 카테고리의 콘텐츠가 있는 카드만 남긴다 — 더보기 화면과 같은 규칙
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) =>
      filterCardsByCategory(all, _selected);

  /// 온보딩으로 한 번만 보낸다 — 프로바이더가 다시 읽힐 때마다 go가
  /// 겹치면 화면이 덜컥거린다
  bool _redirectedToOnboarding = false;

  /// 잔여 연차가 없으면 온보딩으로.
  ///
  /// 아직 못 읽었거나 실패했으면 아무것도 하지 않는다 — 서버를 못 부른 것과
  /// '연차가 없다'는 다르다. 홈은 그대로 두고 다음 조회를 기다린다.
  void _redirectIfLeaveMissing(AsyncValue<Map<String, dynamic>> user) {
    if (_redirectedToOnboarding) return;
    if (!leaveOnboardingNeeded(user)) return;

    _redirectedToOnboarding = true;
    // build 도중에는 화면을 바꿀 수 없다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(AppRoutes.onboardingLeave);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 홈 API의 user.name은 비회원까지 아우르는 값이라 로그인해도 '게스트'가
    // 온다(core HomeResponse.GUEST_NAME). 로그인했으면 /users/me의 이름으로
    // 덮은 값을 쓴다
    final user = ref.watch(currentUserProvider);
    final regions = ref.watch(homeRegionsProvider);
    final places = ref.watch(homePlacesProvider);

    // 연차를 등록하지 않았으면 온보딩으로 돌려보낸다.
    //
    // 로그인 직후의 분기(isNewUser)만으로는 부족하다 — 그 값은 '이번에
    // 계정을 만들었나'라서 온보딩에서 앱을 껐다 켠 사람에게는 다시 false다.
    // 그러면 잔여 연차가 빈 채로 홈에 갇혀, 코스 추천이 제 값을 못 낸다.
    _redirectIfLeaveMissing(user);

    // 시안 노트: 여행 종료 D+1 첫 홈 진입시 "다녀오셨나요?" 모달
    watchTripOutcomePrompt();

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
            // 시안 실측: 연차 카드~히어로 10
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildHeroCard(context, user),
            ),
            // 시안 실측: 히어로~섹션 제목 42
            const SizedBox(height: 42),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '이번달 추천 여행지',
                    // 시안은 Headline 1/Bold(18) — heading1Bold(22)와 이름이 한 글자
                    // 차이라 잘못 집기 쉽다
                    style: AppTypography.headline1Bold.copyWith(
                      color: AppColors.labelNormal,
                    ),
                  ),
                  const Spacer(),
                  // 시안에서 '더보기' 글자는 숨겨지고 쉐브론만 남았다
                  Semantics(
                    button: true,
                    label: '추천 여행지 더 보기',
                    child: GestureDetector(
                      key: const Key('home-region-more'),
                      onTap: () => context.push(AppRoutes.regionList),
                      behavior: HitTestBehavior.opaque,
                      child: SvgPicture.asset(
                        'assets/icons/ic_chevron_right.svg',
                        // DS 쉐브론(Tight)은 12×24 비율이다
                        width: 12,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          AppColors.labelAlternative,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 시안 실측: 제목~칩 16, 칩~카드 16
            const SizedBox(height: 16),
            _buildCategoryRow(),
            const SizedBox(height: 16),
            _buildRegionCards(places, fallback: regions),
            const SizedBox(height: _sectionGap),
            _buildLeavePicks(regions),
            _buildCuratedLinks(),
          ],
        ),
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
            semanticsLabel: 'Offway',
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push(AppRoutes.notifications),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  'assets/icons/ic_bell.svg',
                  width: 24,
                  height: 24,
                ),
                // 안 읽은 알림이 있으면 종 오른쪽 위에 점을 찍는다
                if (ref.watch(hasUnreadNotificationsProvider))
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryNormal,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(AsyncValue<Map<String, dynamic>> user) {
    final days = user.value?['remainingLeaveDays'];
    return GestureDetector(
      onTap: () => context.push(AppRoutes.myLeave),
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
              // DS 쉐브론(Tight)은 12×24 비율이다
              width: 12,
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
    // 이름을 아직 못 읽었으면 이름 없이 인사한다.
    //
    // 기본값을 '오프웨이'로 두었더니 로그인 직후 '오프웨이님'으로 인사하고
    // 곧 내 이름으로 바뀌었다 — 남의 이름으로 불리는 것처럼 보인다.
    // 이름이 오면 그때 붙인다
    final nickname = user.value?['nickname'] as String?;
    final greeting = nickname == null
        ? '어디로 떠나볼까요?'
        : '${displayName(nickname)}님, 어디로 떠나볼까요?';
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
                greeting,
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
        ref.watch(homeSnapshotProvider).value?.filters ??
        defaultCategoryFilters;
    final chips = filters.isEmpty ? defaultCategoryFilters : filters;
    return Padding(
      // 가이드는 칩 줄만 21에서 시작해 화면 폭에 균등 배치된다
      padding: const EdgeInsets.symmetric(horizontal: 21),
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
              onTap: () =>
                  setState(() => _selected = Map<String, dynamic>.from(filter)),
            ),
        ],
      ),
    );
  }

  /// 화면 맨 끝 '지금 유용한 혜택과 정보' — 서버가 고른 외부 링크 (core #350).
  ///
  /// 목록이 아니라 **가로로 넘기는 큰 카드**다. 화면 끝에 붙는 덤이 아니라
  /// 위 '이번 연차엔 여기 어때요?'와 나란한 한 줄로, 홈이 보여 주려고 내미는
  /// 자리다.
  ///
  /// 홈을 아직 못 읽었거나 링크가 없으면 섹션째 접힌다. 로딩 자리도 두지
  /// 않는다 — 추천 카드를 다 본 뒤에 따라오는 것이라, 자리부터 잡아두면
  /// 화면 끝이 빈 채로 기다리게 된다
  Widget _buildCuratedLinks() {
    final links =
        ref.watch(homeSnapshotProvider).value?.curatedLinks ??
        const <CuratedLink>[];
    if (links.isEmpty) return const SizedBox.shrink();

    return Padding(
      // 위 섹션(가로 카드)과 붙지 않게 같은 간격을 준다
      padding: const EdgeInsets.only(top: _sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _CuratedLinksTitle(),
          ),
          // 시안 실측: 제목~카드 16, 카드 사이 18
          const SizedBox(height: 16),
          SizedBox(
            height: CuratedLinkCard.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: links.length,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (context, i) => CuratedLinkCard(link: links[i]),
            ),
          ),
        ],
      ),
    );
  }

  /// '이번 연차엔 여기 어때요?' — 위쪽 '이번달 추천 여행지'와 같은 목록을
  /// 쓰지만 카테고리 필터를 걸지 않는다. 조건 없이 지역만 훑어보는 자리다.
  ///
  /// 시안: 카드 3~7개. 서버가 그보다 많이 주면 앞에서 7개만 쓴다
  Widget _buildLeavePicks(AsyncValue<List<Map<String, dynamic>>> regions) {
    final picks = (regions.value ?? const <Map<String, dynamic>>[])
        .take(_maxLeavePicks)
        .toList();
    // 3개도 못 채우면 섹션째 감춘다 — 한두 장만 놓인 가로 목록은 비어 보인다
    if (regions.hasValue && picks.length < _minLeavePicks) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '이번 연차엔 여기 어때요?',
            style: AppTypography.headline1Bold.copyWith(
              color: AppColors.labelNormal,
            ),
          ),
        ),
        // 시안 실측: 제목~카드 16, 카드 사이 18
        const SizedBox(height: 16),
        SizedBox(
          height: LeavePickCard.height,
          child: regions.isLoading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _skeletonCardCount,
                  separatorBuilder: (_, _) => const SizedBox(width: 18),
                  itemBuilder: (_, _) => const LeavePickCardSkeleton(),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: picks.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 18),
                  itemBuilder: (context, i) => LeavePickCard(region: picks[i]),
                ),
        ),
      ],
    );
  }

  /// '이번달 추천 여행지' — 장소 카드를 그린다.
  ///
  /// [fallback]은 장소 배치가 아직 안 돈 동안 쓰는 지역 카드다. 시안은 장소를
  /// 원하지만 빈 섹션보다는 낫고, 서버가 채우는 대로 저절로 갈아탄다
  Widget _buildRegionCards(
    AsyncValue<List<Map<String, dynamic>>> regions, {
    AsyncValue<List<Map<String, dynamic>>>? fallback,
  }) {
    // 로딩·에러·빈 상태는 자리만 잡아두면 되므로 높이를 고정한다.
    // 카드가 들어오면 높이를 카드에 맡긴다 — 고정하면 카드 내용보다 커져
    // 뱃지 아래에 빈 영역이 남고 다음 섹션이 그만큼 밀려 내려간다
    final placeholderHeight = RegionCard.boxedHeightFor(context);

    return regions.when(
      // 스피너 대신 카드가 들어올 자리를 미리 잡아둔다 (O-03 스켈레톤)
      loading: () => SizedBox(
        height: placeholderHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _skeletonCardCount,
          separatorBuilder: (_, _) => const SizedBox(width: 20),
          itemBuilder: (_, _) => const RegionCardSkeleton(),
        ),
      ),
      // 서버 detail이 사용자 문구라 그대로 보여준다. 그 외에는 원인을 감춘다
      error: (e, _) => SizedBox(
        height: placeholderHeight,
        child: Center(
          child: Text(
            e is ApiException ? e.detail : '추천 여행지를 불러오지 못했어요',
            textAlign: TextAlign.center,
            style: AppTypography.label1NormalMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ),
      ),
      data: (served) {
        // 장소 배치(core #305)가 아직 안 돈 지역이 있다. 그럴 때 빈 칸을
        // 두느니 예전처럼 지역 카드를 보여준다 — 배치가 채우면 저절로 바뀐다
        final usingPlaces = served.isNotEmpty;
        final list = usingPlaces
            ? homePlacesForChip(served, _selected)
            : _filter(fallback?.value ?? served);
        if (list.isEmpty) {
          return SizedBox(
            height: placeholderHeight,
            child: Center(
              child: Text(
                '해당 카테고리의 여행지가 아직 없어요',
                style: AppTypography.label1NormalMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
            ),
          );
        }
        // Row로 감싸 카드가 스스로 높이를 정하게 한다. 가로 ListView는
        // 부모가 높이를 정해줘야 해서 여유분이 빈 영역으로 남는다
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(width: 20),
                RegionCard(region: list[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// '지금 유용한 **혜택과 정보**를 만나보세요' — 가운데 두 낱말만 브랜드색.
///
/// 두 줄로 접히는 문구라 `RichText` 한 덩이로 둔다. 낱말을 잘라 Row로 늘어
/// 놓으면 줄바꿈 자리를 앱이 정하게 되어, 기기 폭이 좁아질 때 엉뚱한 데서
/// 끊긴다.
class _CuratedLinksTitle extends StatelessWidget {
  const _CuratedLinksTitle();

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.headline1Bold.copyWith(
      color: AppColors.labelNormal,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: '지금 유용한 '),
          TextSpan(
            text: '혜택과 정보',
            style: base.copyWith(color: AppColors.primaryStrong),
          ),
          const TextSpan(text: '를\n만나보세요'),
        ],
      ),
    );
  }
}
