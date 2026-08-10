import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../home/presentation/home_screen.dart' show homeSnapshotProvider;

/// 연차 사용 내역 한 건.
///
/// 코스에서 차감된 건([courseName])과 직접 등록한 건([reason])은 생김새가
/// 다르다 — 코스 건은 파란 카드에 코스명을, 직접 등록은 사유와 메모를 보여준다.
typedef LeaveUsage = ({
  DateTime usedOn,
  double days,
  String? reason,
  String? memo,
  String? courseName,
});

/// TODO(server): `GET /api/v1/leaves/me/usages`가 아직 없다 (POST만 존재).
/// 조회 API가 열리면 이 mock을 리포지토리 호출로 바꾼다.
final leaveUsagesProvider = Provider.autoDispose<List<LeaveUsage>>((ref) {
  return [
    (
      usedOn: DateTime(2026, 6, 12),
      days: 1,
      reason: '개인 사유',
      memo: '코로나에 걸렸음 콜록콜ㄱ록 아이고',
      courseName: null,
    ),
    (
      usedOn: DateTime(2026, 6, 12),
      days: 1,
      reason: '개인 사유',
      memo: '청춘! 이는 듣기만 하여도 가슴이 설레는 말이다. 청춘의 피는 끓는다.',
      courseName: null,
    ),
    (
      usedOn: DateTime(2026, 6, 12),
      days: 1,
      reason: null,
      memo: null,
      courseName: '정선 여행',
    ),
  ];
});

/// 내 연차 — 잔여 일수와 사용 내역을 한 화면에 모은다.
/// 홈의 '남은 연차 일수' 줄에서 들어온다.
class MyLeaveScreen extends ConsumerWidget {
  const MyLeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(homeSnapshotProvider).value?.user;
    final remaining = user?['remainingLeaveDays'] as num?;
    final usages = ref.watch(leaveUsagesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LeaveHeroCard(remaining: remaining),
                        const SizedBox(height: 8),
                        _RegisterRow(
                          // TODO(design): 등록 화면(18305:117380)은 다음 작업
                          onTap: () =>
                              showAppToast(context, '연차 등록 기능은 준비 중이에요'),
                        ),
                      ],
                    ),
                  ),
                  // 시안: 등록 줄과 '연차 사용 내역' 사이 54
                  const SizedBox(height: 54),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '연차 사용 내역',
                          style: AppTypography.headline1Bold.copyWith(
                            color: AppColors.labelNormal,
                          ),
                        ),
                        GestureDetector(
                          // TODO(design): 내역 전체 화면(18305:117591)은 다음 작업
                          onTap: () =>
                              showAppToast(context, '연차 사용 내역은 준비 중이에요'),
                          behavior: HitTestBehavior.opaque,
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
                  const SizedBox(height: 24),
                  if (usages.isEmpty)
                    const _EmptyUsages()
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          for (final (i, usage) in usages.indexed) ...[
                            if (i > 0) const SizedBox(height: 8),
                            LeaveUsageCard(usage: usage),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        // 없으면 Stack이 제목 크기로 줄어 Positioned가 화면 기준이 아니게 된다
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              '내 연차',
              style: AppTypography.headline2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
          ),
          Positioned(
            left: 6,
            child: AppBackButton(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
          ),
        ],
      ),
    );
  }
}

/// 잔여 일수만 쓰는 큰 숫자.
/// DS는 Display(36~56)를 2026-07-30 개편에서 뺐는데 시안이 42를 쓴다 —
/// 이 화면에서만 필요하므로 토큰을 되살리는 대신 여기 둔다.
const _remainingDaysStyle = TextStyle(
  fontSize: 42,
  fontWeight: FontWeight.w700,
  height: 1.375,
  letterSpacing: -1.0626,
  color: AppColors.staticWhite,
);

/// 잔여 연차를 크게 보여주는 하늘색 카드
class _LeaveHeroCard extends StatelessWidget {
  const _LeaveHeroCard({required this.remaining});

  final num? remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 187,
      decoration: BoxDecoration(
        color: AppColors.primaryNormal,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 캐리어 일러스트는 카드 오른쪽에 붙어 아래로 잘린다
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/leave_hero_luggage.png',
              fit: BoxFit.fitHeight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 23, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '잔여 연차일수',
                  style: AppTypography.headline1Bold.copyWith(
                    color: AppColors.backgroundNormalAlternative,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  remaining == null ? '-' : '${formatLeaveDays(remaining!)}일',
                  style: _remainingDaysStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// '사용 연차 등록하기' 줄 — 회색 카드에 아이콘·라벨·쉐브론
class _RegisterRow extends StatelessWidget {
  const _RegisterRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                'assets/icons/ic_calendar_edit.svg',
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '사용 연차 등록하기',
              style: AppTypography.body1NormalMedium.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const Spacer(),
            SvgPicture.asset(
              'assets/icons/ic_chevron_right.svg',
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
}

/// 사용 내역 카드 한 장.
///
/// 코스에서 차감된 건은 파란 배경에 코스명을, 직접 등록한 건은 회색 배경에
/// 사유와 메모를 보여준다.
class LeaveUsageCard extends StatelessWidget {
  const LeaveUsageCard({super.key, required this.usage, this.onTap});

  final LeaveUsage usage;
  final VoidCallback? onTap;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final fromCourse = usage.courseName != null;
    final d = usage.usedOn;
    final dateLabel =
        '${d.year}.${d.month.toString().padLeft(2, '0')}'
        '.${d.day.toString().padLeft(2, '0')}(${_weekdays[d.weekday - 1]})';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          // 코스에서 자동 차감된 건은 직접 등록한 건과 구분해 옅은 하늘색
          color: fromCourse
              ? AppPalette.lightBlue95
              : AppColors.backgroundElevatedAlternative,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: AppTypography.body1NormalBold.copyWith(
                      color: AppColors.labelNeutral,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (fromCourse)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/ic_chevron_down.svg',
                          width: 16,
                          height: 16,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            usage.courseName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label1NormalMedium.copyWith(
                              color: AppColors.primaryNormal,
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    if (usage.reason case final String reason)
                      Text(
                        reason,
                        style: AppTypography.label1NormalMedium.copyWith(
                          color: AppColors.labelNeutral,
                        ),
                      ),
                    if (usage.memo case final String memo) ...[
                      const SizedBox(height: 2),
                      Text(
                        memo,
                        style: AppTypography.label1ReadingRegular.copyWith(
                          color: AppColors.labelAlternative,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                '-${formatLeaveDays(usage.days)}일',
                style: AppTypography.body1NormalBold.copyWith(
                  color: AppColors.primaryNormal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사용 내역이 하나도 없을 때
class _EmptyUsages extends StatelessWidget {
  const _EmptyUsages();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          '아직 등록한 연차 사용 내역이 없어요',
          style: AppTypography.label1NormalMedium.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
      ),
    );
  }
}
