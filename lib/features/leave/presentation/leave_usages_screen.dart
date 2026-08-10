import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_toast.dart';
import 'my_leave_screen.dart' show LeaveUsage, leaveUsagesProvider;
import 'widgets/leave_empty_view.dart';

/// O-13 · 연차 사용 내역 전체.
///
/// 코스에서 차감된 건은 눌러 펼치면 '코스 자세히 보기'가 나온다 —
/// 어떤 여행 때문에 줄었는지 되짚어볼 수 있게.
class LeaveUsagesScreen extends ConsumerStatefulWidget {
  const LeaveUsagesScreen({super.key});

  @override
  ConsumerState<LeaveUsagesScreen> createState() => _LeaveUsagesScreenState();
}

class _LeaveUsagesScreenState extends ConsumerState<LeaveUsagesScreen> {
  /// 펼쳐 둔 카드의 인덱스 — 한 번에 하나만 펼친다
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    final usages = ref.watch(leaveUsagesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: usages.isEmpty
                  ? const Center(child: LeaveEmptyView())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: usages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _UsageCard(
                        usage: usages[i],
                        expanded: _expanded == i,
                        // 코스 건만 펼쳐진다 — 직접 등록한 건은 더 볼 게 없다
                        onTap: usages[i].courseName == null
                            ? null
                            : () => setState(
                                () => _expanded = _expanded == i ? null : i,
                              ),
                      ),
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
              '연차 사용 내역',
              style: AppTypography.headline2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
          ),
          Positioned(
            left: 6,
            child: AppBackButton(
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.myLeave),
            ),
          ),
          Positioned(
            right: 6,
            child: IconButton(
              // TODO(design): 선택·삭제 모드(18305:124971)는 다음 작업
              onPressed: () => showAppToast(context, '내역 편집은 준비 중이에요'),
              tooltip: '더 보기',
              icon: Icon(Icons.more_horiz, color: AppColors.labelNormal),
            ),
          ),
        ],
      ),
    );
  }
}

/// 내역 카드 한 장 — 코스 건은 펼치면 상세로 가는 버튼이 붙는다
class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.usage,
    required this.expanded,
    required this.onTap,
  });

  final LeaveUsage usage;
  final bool expanded;
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: fromCourse
              ? AppPalette.lightBlue95
              : AppColors.backgroundElevatedAlternative,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                                usage.courseName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label1NormalMedium
                                    .copyWith(color: AppColors.primaryNormal),
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
            if (expanded) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  // TODO(server): 내역에 courseId가 실리면 그 코스 상세로 보낸다
                  onTap: () => showAppToast(context, '코스 연결은 서버 연동 후 동작해요'),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundNormal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '코스 자세히 보기',
                      style: AppTypography.label2Medium.copyWith(
                        color: AppColors.labelNeutral,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
