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
            Text(
              '연차 쓰기 좋은 날',
              style: AppTypography.headline1Bold.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const SizedBox(height: 16),
            for (final (i, holiday) in kGoldenHolidays.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              _HolidayRow(holiday: holiday),
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
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/ic_clock.svg',
                      width: 18,
                      height: 18,
                      excludeFromSemantics: true,
                      colorFilter: const ColorFilter.mode(
                        AppColors.labelNeutral,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$kGoldenHolidayYear년 연차 황금 타이밍',
                      style: AppTypography.label1ReadingBold.copyWith(
                        color: AppColors.labelNeutral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
  const _HolidayRow({required this.holiday});

  final GoldenHoliday holiday;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundNormalAlternative,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                holiday.rangeLabel,
                style: AppTypography.body2NormalBold.copyWith(
                  color: AppColors.labelNeutral,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                holiday.label,
                style: AppTypography.caption1Medium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '사용 연차 ${holiday.leaveDays}일',
                style: AppTypography.label2Bold.copyWith(
                  color: AppColors.labelNeutral,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '총 ${holiday.totalDays}일 연휴',
                style: AppTypography.label2Bold.copyWith(
                  color: AppColors.primaryStrong,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
