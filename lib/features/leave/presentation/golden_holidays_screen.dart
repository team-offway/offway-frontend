import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';
import '../domain/golden_holiday.dart';

/// 황금연휴 — 연차를 조금 써서 길게 쉬는 구간들 (시안 18900:72317).
///
/// 위에는 가장 긴 구간 하나를 크게(상단 카드), 아래에는 '연차 쓰기 좋은 날'
/// 목록. 값은 [kGoldenHolidays]에 박아 둔 편집 콘텐츠다 — 서버 공휴일은
/// 날짜만 줘서 이름과 고른 순서를 만들 수 없다.
class GoldenHolidaysScreen extends StatelessWidget {
  const GoldenHolidaysScreen({super.key});

  /// 상단 카드 배경 — 시안이 노란 단색(#FEFAE5)을 직접 쓴다.
  /// TODO(디자인시스템): Semantic 토큰이 생기면 교체한다
  static const _heroBackground = Color(0xFFFEFAE5);

  @override
  Widget build(BuildContext context) {
    final hero = kGoldenHolidays.first;

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: ListView(
          // 시안 실측: 상단바 아래 26, 좌우 20
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 26),
            _HeroCard(holiday: hero, background: _heroBackground),
            // 시안 실측: 상단 카드 아래 32 → 제목 → 16 → 목록(행 사이 8)
            const SizedBox(height: 32),
            // 시안 실측: 시계 24, 글자와 8 띄운다(아이콘 0~24, 글자 32)
            Row(
              children: [
                // 시안은 bulk 변형(테두리 없는 두 톤)이다 — ic_clock은
                // 외곽선형이라 같은 자리에 놓으면 더 진하고 얇게 보인다.
                //
                // 에셋의 원반에 opacity 0.4가 박혀 있고 srcIn 색의 알파와
                // 곱해진다. labelAlternative(0.61)를 그대로 씌우면
                // 원반 0.244 → #CECFCF 로 시안 실측 #CECFD0과 맞는다
                SvgPicture.asset(
                  'assets/icons/ic_clock_bulk.svg',
                  width: 24,
                  height: 24,
                  excludeFromSemantics: true,
                  colorFilter: const ColorFilter.mode(
                    AppColors.labelAlternative,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$kGoldenHolidayYear년 연차 쓰기 좋은 날',
                  style: AppTypography.headline1Bold.copyWith(
                    color: AppColors.labelNormal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final (i, holiday) in kGoldenHolidays.indexed) ...[
              // 시안 실측: 행 사이 12
              if (i > 0) const SizedBox(height: 12),
              _HolidayRow(holiday: holiday, order: i + 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              GoldenHolidaysScreen.title,
              style: AppTypography.headline2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
          ),
          Positioned(
            // 목록 여백(20) 안쪽이라 다른 화면의 6보다 14만큼 당긴다
            left: -14,
            child: AppBackButton(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
          ),
        ],
      ),
    );
  }

  static const title = '$kGoldenHolidayYear 황금연휴 알아보기';
}

/// 상단 카드 — 가장 긴 구간을 큰 글자로, 오른쪽에 샌드위치 일러스트.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.holiday, required this.background});

  final GoldenHoliday holiday;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          // 시안 실측: 카드 오른쪽 위에 126×117, 위 6 · 오른쪽 4
          Positioned(
            top: 6,
            right: 4,
            // PNG 내보내기는 흰 배경이 박혀 와 노란 카드 위에 흰 상자가 떴다.
            // 이 일러스트는 마스크·블러가 없어 SVG로 투명하게 그린다
            child: SvgPicture.asset(
              'assets/images/golden_holiday_sandwich.svg',
              width: 126,
              height: 117,
              excludeFromSemantics: true,
            ),
          ),
          Padding(
            // 시안 실측: 안쪽 24·25
            padding: const EdgeInsets.fromLTRB(24, 25, 24, 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 시안(1534:44652)이 시계를 여기서 빼고 아래 목록 제목으로
                // 옮겼다 — 카드는 날짜를 앞세우는 자리다
                Text(
                  '$kGoldenHolidayYear년 연차 황금 타이밍',
                  style: AppTypography.label1ReadingBold.copyWith(
                    color: AppColors.labelNeutral,
                  ),
                ),
                // 시안 실측: 제목 아래 12 (0~18 → 30)
                const SizedBox(height: 12),
                Text(
                  holiday.heroRangeLabel,
                  style: AppTypography.title3Bold.copyWith(
                    color: AppColors.labelNeutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '연차 ${holiday.leaveDays}일로 최대 ${holiday.totalDays}일까지 쉴 수 있어요',
                  style: AppTypography.label1NormalMedium.copyWith(
                    color: AppColors.labelNeutral,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 목록 한 행 — 왼쪽에 기간과 무슨 연휴인지, 오른쪽에 쓰는 연차와 총 일수.
class _HolidayRow extends StatelessWidget {
  /// 앞에서 몇 등까지 순번을 파랗게 둘 것인가 — 시안(1535:45144)은 1~3만
  /// primary, 4·5는 회색이다. 위쪽이 더 쓸 만한 구간이라는 표시다
  static const _highlightedRanks = 3;

  /// 4등 아래 순번 색 — 시안 실측 #B0B0B0.
  /// TODO(디자인시스템): Semantic 토큰이 생기면 교체한다
  static const _dimmedRank = AppPalette.neutral80;

  const _HolidayRow({required this.holiday, required this.order});

  final GoldenHoliday holiday;

  /// 목록에서 몇 번째인가 — 1부터 센다
  final int order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 시안 실측(1535:45146): 안쪽 12·11. 높이를 고정하지 않는다 —
      // 글자가 한 줄 늘거나 서체가 바뀌면 그 안에서 넘친다.
      //
      // **바탕을 깔지 않는다.** 예전 시안은 회색 카드였는데 지금은 글만
      // 놓인다 — 줄마다 상자를 두르면 다섯 줄이 무거워진다
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 순번 — 고른 순서가 곧 추천 순서다(시안 1534:44705).
          //
          // 시안은 번호 폭을 글자마다 다르게 두지만(9~12) 그러면 줄마다
          // 글 시작점이 어긋난다. 가장 넓은 값으로 고정해 왼쪽을 맞춘다
          SizedBox(
            width: 12,
            child: Text(
              '$order',
              textAlign: TextAlign.center,
              style: AppTypography.headline1Bold.copyWith(
                color: order <= _highlightedRanks
                    ? AppColors.primaryNormal
                    : _dimmedRank,
              ),
            ),
          ),
          // 시안 실측: 번호와 글 사이 20
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 시안이 이름을 위로 올렸다 — 무슨 연휴인지 먼저 읽힌다
                Text(
                  holiday.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption1Regular.copyWith(
                    color: AppColors.labelAlternative,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  holiday.rangeLabel,
                  // 한 줄로 둔다 — 접히면 행이 두 배로 길어져 시안과 어긋난다
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body2NormalMedium.copyWith(
                    color: AppColors.labelNeutral,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '사용 연차 ${holiday.leaveDays}일',
                style: AppTypography.label2Medium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '총 ${holiday.totalDays}일 연휴',
                style: AppTypography.label2Medium.copyWith(
                  color: AppColors.primaryNormal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
