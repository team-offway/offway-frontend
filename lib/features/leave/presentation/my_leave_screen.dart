import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_toast.dart';
import '../../course/presentation/trip_outcome_prompt.dart';
import '../data/leave_usages_provider.dart';
import '../domain/leave_usage.dart';
import 'widgets/leave_empty_view.dart';
import 'widgets/leave_new_chip.dart';

/// 내 연차 — 잔여 일수와 사용 내역을 한 화면에 모은다.
/// 홈의 '남은 연차 일수' 줄에서 들어온다.
class MyLeaveScreen extends ConsumerStatefulWidget {
  const MyLeaveScreen({super.key, this.fromNotification = false});

  /// "다녀오셨나요?" 알림을 눌러 들어왔는지.
  ///
  /// 시안에서 이 모달이 뜨는 자리는 **홈 진입**과 **그 알림** 둘뿐이다.
  /// 연차를 보러 그냥 들어온 사람에게까지 띄우면, 홈에서 '나중에 할게요'를
  /// 눌러 미룬 사람이 연차 화면마다 같은 질문을 다시 받는다.
  final bool fromNotification;

  @override
  ConsumerState<MyLeaveScreen> createState() => _MyLeaveScreenState();
}

class _MyLeaveScreenState extends ConsumerState<MyLeaveScreen>
    with TripOutcomePrompt {
  /// 펼쳐 둔 카드의 인덱스 — 한 번에 하나만 펼친다
  int? _expanded;

  /// 이미 연차 화면이다 — '보러가기'가 제자리를 가리킨다
  @override
  bool get showsLeaveShortcut => false;

  @override
  bool get entersFromNotification => widget.fromNotification;

  @override
  Widget build(BuildContext context) {
    // 알림을 눌러 들어온 경우에만 묻는다. 그 알림이 곧 질문이라 여기서
    // 안 띄우면 눌러도 아무 일이 없다
    if (widget.fromNotification) watchTripOutcomePrompt();

    final leave = ref.watch(myLeaveProvider);
    final remaining = leave.value?.remainingDays;
    final usagesAsync = ref.watch(leaveUsagesProvider);
    final all = usagesAsync.value ?? const <LeaveUsage>[];
    // 이 화면은 훑어보는 자리다 — 다 쌓아 두면 아래 '총 연차일수 수정하기'가
    // 한참 밑으로 밀려 보이지 않는다. 나머지는 '더보기'가 맡는다
    final usages = all.take(_maxCards).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                // 시안: 상단바와 히어로 카드 사이 24
                padding: const EdgeInsets.only(top: 24, bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LeaveHeroCard(remaining: remaining),
                        const SizedBox(height: 8),
                        _RegisterRow(
                          onTap: () => context.push(AppRoutes.leaveRegister),
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
                          onTap: () => context.push(AppRoutes.leaveUsages),
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
                  // 로딩·오류를 '내역 없음'으로 보여주면 재시도할 길이 사라진다
                  if (usagesAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: AppCircularLoadingView(),
                    )
                  else if (usagesAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: AppErrorView(
                        onRetry: () => ref.invalidate(myLeaveProvider),
                      ),
                    )
                  else if (usages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: LeaveEmptyView(),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          for (final (i, usage) in usages.indexed) ...[
                            if (i > 0) const SizedBox(height: 8),
                            LeaveUsageCard(
                              usage: usage,
                              expanded: _expanded == i,
                              // 코스 건만 펼쳐진다 — 직접 등록한 건은 더 볼 게 없다
                              onTap: usage.fromCourse
                                  ? () => setState(
                                      () =>
                                          _expanded = _expanded == i ? null : i,
                                    )
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  // 사용 내역을 보다가 '총량 자체가 틀렸다'를 깨닫는 자리다.
                  // 마이 탭 진입점(설정하러 찾아오는 경로)과 함께 둘로 굴린다
                  const SizedBox(height: 24),
                  const Divider(
                    height: 12,
                    thickness: 12,
                    color: AppColors.lineNormalAlternative,
                  ),
                  _TotalLeaveEntry(
                    onTap: () async {
                      final changed = await context.push<bool>(
                        AppRoutes.totalLeaveFromMyLeave,
                      );
                      if (!context.mounted || changed != true) return;
                      // 수정은 저쪽 화면에서 끝났지만 결과는 여기서 알린다 —
                      // 바뀐 잔여 일수가 보이는 자리가 여기라야 말이 맞는다
                      showAppToast(
                        context,
                        '연차 정보를 업데이트했어요.',
                        kind: AppToastKind.success,
                      );
                    },
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

/// 이 화면에 카드로 보여줄 사용 내역 개수.
///
/// 나머지는 '더보기'가 맡는다 — 서버가 목록을 잘라 주지 않아 앱에서 자른다
/// (`GET /leaves/me`에 개수·페이지 파라미터가 없다).
const _maxCards = 4;

/// 사용 내역 아래, 총 연차일수를 고치러 가는 자리.
///
/// 마이 탭에도 같은 곳으로 가는 줄이 있다. 둘은 맥락이 다르다 — 마이 탭은
/// 설정하러 찾아오는 경로고, 여기는 내역을 훑다가 **총량 자체가 틀렸음을
/// 깨닫는** 경로다. 그 자리에서 바로 이어 준다.
class _TotalLeaveEntry extends StatelessWidget {
  const _TotalLeaveEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 시안은 구분선 아래로 24를 띄우고, 그 안에서 다시 24를 둔 뒤 아이콘을
      // 놓는다. 스파클이 아이콘 위로 4.9 삐져나와 24만 주면 그만큼 먹힌다
      padding: const EdgeInsets.only(top: 48, bottom: 24),
      child: Column(
        children: [
          // 스파클은 아이콘 밖으로 삐져나온다 — 시안 좌표가 음수라
          // Stack에 clipBehavior.none을 줘야 잘리지 않는다
          SizedBox(
            width: 48.9,
            height: 48.9,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  'assets/icons/ic_timer.svg',
                  width: 48.9,
                  height: 48.9,
                  excludeFromSemantics: true,
                ),
                const Positioned(left: -15.7, top: -4.9, child: _Sparkle(7.3)),
                const Positioned(left: 45.7, top: 14, child: _Sparkle(9)),
                // 왼쪽 아래만 한 단 옅다 — 시안이 셋을 같은 색으로 두지
                // 않는다. 나란히 놓으면 반짝임이 평평해 보이기 때문이다
                const Positioned(
                  left: -4.5,
                  top: 39.9,
                  child: _Sparkle(9, tone: AppPalette.lightBlue70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '연차가 새로 갱신됐나요?\n총 연차일수를 수정할 수 있어요',
            textAlign: TextAlign.center,
            style: AppTypography.label2Regular.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
          const SizedBox(height: 16),
          // 여기가 목적지가 아니라 곁다리 제안이라 옅은 회색 버튼이다.
          // 총 연차 화면의 파란 버튼과 위계를 나눈다
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 189,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.fillNormal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '총 연차일수 수정하기',
                style: AppTypography.body1NormalMedium.copyWith(
                  color: AppColors.labelNeutral,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 타이머 둘레에 흩어 둔 반짝임.
///
/// 에셋 원본은 `#3DC2FF`(Light Blue 60)다. [tone]을 주면 그 색으로 덮는다 —
/// 시안이 세 개를 같은 농도로 두지 않아 하나만 한 단 옅게 쓴다.
class _Sparkle extends StatelessWidget {
  const _Sparkle(this.size, {this.tone});

  final double size;

  /// null이면 에셋 원본색을 그대로 쓴다
  final Color? tone;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/ic_star_four.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
    colorFilter: tone == null ? null : ColorFilter.mode(tone!, BlendMode.srcIn),
  );
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
      width: double.infinity,
      height: 187,
      decoration: BoxDecoration(
        color: AppColors.primaryNormal,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        // 없으면 Stack이 가장 큰 자식 크기로 줄어 카드가 화면 폭을 못 채운다
        fit: StackFit.expand,
        children: [
          // 캐리어 일러스트 — 시안 1:1 크기(156×141)로 오른쪽 12, 아래 0에 놓는다.
          // 카드(362×187) 안에서 실측한 값이라 늘리거나 자르지 않는다.
          //
          // SVG로 둔다 — PNG는 1배(182×187)라 3배 화면에서 뭉개졌다
          Positioned(
            right: 12,
            bottom: 0,
            width: 156,
            height: 141,
            child: SvgPicture.asset('assets/images/leave_hero_luggage.svg'),
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
/// 사유와 메모를 보여준다. 코스 건은 펼치면 '코스 자세히 보기'가 붙는다.
class LeaveUsageCard extends StatelessWidget {
  const LeaveUsageCard({
    super.key,
    required this.usage,
    this.onTap,
    this.expanded = false,
  });

  final LeaveUsage usage;
  final VoidCallback? onTap;

  /// 펼쳐서 '코스 자세히 보기'를 보이는지 — 코스 건에만 쓴다
  final bool expanded;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final fromCourse = usage.fromCourse;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 갓 등록한 것임을 맨 위에서 알린다 — 시안: 칩 아래 4
                      if (usage.isNewAt(DateTime.now())) ...[
                        const LeaveNewChip(),
                        const SizedBox(height: 4),
                      ],
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
                            // 펼침 상태를 쉐브론 방향으로 알린다
                            RotatedBox(
                              quarterTurns: expanded ? 2 : 0,
                              child: SvgPicture.asset(
                                'assets/icons/ic_chevron_down.svg',
                                width: 16,
                                height: 16,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                usage.courseName ?? '코스 차감',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label1NormalMedium
                                    .copyWith(color: AppColors.primaryNormal),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        if (reasonOf(usage.reason) case final String reason)
                          Text(
                            reason,
                            style: AppTypography.label1NormalMedium.copyWith(
                              color: AppColors.labelNeutral,
                            ),
                          ),
                        if (memoOf(usage) case final String memo) ...[
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
                    formatLeaveDelta(usage.days),
                    style: AppTypography.body1NormalBold.copyWith(
                      color: AppColors.primaryNormal,
                    ),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: CourseDetailButton(courseId: usage.courseId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 펼친 코스 카드 아래에 붙는 '코스 자세히 보기'
class CourseDetailButton extends StatelessWidget {
  const CourseDetailButton({super.key, required this.courseId});

  final int? courseId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 담아둔 코스를 지웠으면 갈 곳이 없어 알려만 준다
        final id = courseId;
        if (id == null) {
          showAppToast(context, '연결된 코스를 찾을 수 없어요');
          return;
        }
        context.push(AppRoutes.savedCoursePath('$id'));
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          // 시안 Fill/Normal — 파란 카드 위에 얹히는 옅은 회색
          color: AppColors.fillNormal,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '코스 자세히 보기',
          style: AppTypography.body2NormalMedium.copyWith(
            color: AppColors.labelNeutral,
          ),
        ),
      ),
    );
  }
}

/// 카드에 두 줄로 보여줄 사유와 메모.
///
/// 지금은 서버가 `reason`·`memo`를 따로 준다(core #323). 그 전에 등록된
/// 내역은 memo 자리가 없어 `reason`에 '사유 · 메모'로 합쳐 저장돼 있다 —
/// 그 행들은 여전히 가운뎃점으로 되나눠야 시안대로 두 줄이 된다.
String? reasonOf(String? raw) => raw?.split(' · ').first;
String? memoOf(LeaveUsage usage) {
  if (usage.memo case final String memo when memo.isNotEmpty) return memo;
  final parts = usage.reason?.split(' · ');
  return (parts != null && parts.length > 1)
      ? parts.sublist(1).join(' · ')
      : null;
}
