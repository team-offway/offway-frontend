import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/leave_usages_provider.dart';
import '../domain/leave_usage.dart';
import '../../onboarding/data/leave_repository.dart';
import 'my_leave_screen.dart' show reasonOf, memoOf, CourseDetailButton;
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

  /// 체크박스를 띄운 삭제 모드인지
  bool _selecting = false;

  /// 삭제 모드에서 고른 카드들
  final _selected = <int>{};

  void _enterSelecting() {
    setState(() {
      _selecting = true;
      _selected.clear();
      // 펼친 카드는 접어 체크박스가 잘 보이게 한다
      _expanded = null;
    });
  }

  void _exitSelecting() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggle(int i) {
    setState(() {
      if (!_selected.remove(i)) _selected.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveUsagesProvider);
    final usages = async.value ?? const <LeaveUsage>[];

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              // 로딩·오류를 '내역 없음'으로 보여주면 재시도할 길이 사라진다
              child: async.isLoading
                  ? const AppCircularLoadingView()
                  : async.hasError
                  ? AppErrorView(onRetry: () => ref.invalidate(myLeaveProvider))
                  : usages.isEmpty
                  ? const Center(child: LeaveEmptyView())
                  : ListView.separated(
                      // 시안 실측: 헤더에서 첫 카드까지 24
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      itemCount: usages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _UsageCard(
                        usage: usages[i],
                        expanded: _expanded == i,
                        selecting: _selecting,
                        checked: _selected.contains(i),
                        // 삭제 모드에서는 어느 카드든 골라진다 — 옛 상쇄 행(음수)도
                        // 지워 장부를 정리할 수 있어야 한다. 못 지우는 건(코스 확정)은
                        // 서버가 이유와 함께 막는다.
                        // 평소에는 코스 건만 펼쳐진다 — 직접 등록한 건은 더 볼 게 없다
                        onTap: _selecting
                            ? () => _toggle(i)
                            : usages[i].courseName == null
                            ? null
                            : () => setState(
                                () => _expanded = _expanded == i ? null : i,
                              ),
                      ),
                    ),
            ),
            if (_selecting) _buildDeleteActions(usages),
          ],
        ),
      ),
    );
  }

  /// '...' 메뉴 — 지금은 삭제만 있다
  Future<void> _showMenu() async {
    final action = await showAppBottomSheet<String>(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // 제목 바가 시트 전체 폭을 차지해야 닫기 버튼이 오른쪽 끝에 붙는다
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetTitleBar(title: '삭제'),
            // 시안 실측: 상단바 56 + 이 블록 76 = 132, 남는 34는 하단 SafeArea.
            // 항목은 이 76 안에서 수직 중앙에 놓인다
            SizedBox(
              height: 76,
              child: GestureDetector(
                onTap: () => Navigator.of(sheetContext).pop('delete'),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.staticBlack.withValues(
                            alpha: AppOpacity.o5,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Opacity(
                            opacity: AppOpacity.o61,
                            child: SvgPicture.asset(
                              'assets/icons/ic_trash.svg',
                              width: 20,
                              height: 20,
                            ),
                          ),
                        ),
                      ),
                      // 시안 실측: 원 우측 끝에서 글자까지 16
                      const SizedBox(width: 16),
                      Text(
                        '사용 내역 삭제',
                        style: AppTypography.body1NormalMedium.copyWith(
                          color: AppColors.labelNeutral,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action != 'delete') return;
    _enterSelecting();
  }

  /// 삭제 모드 하단 — 취소와 삭제하기
  Widget _buildDeleteActions(List<LeaveUsage> usages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _exitSelecting,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.backgroundElevatedAlternative,
                foregroundColor: AppColors.labelNeutral,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('취소', style: AppTypography.body1NormalBold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              // 하나도 안 골랐으면 지울 게 없다
              onPressed: _selected.isEmpty
                  ? null
                  : () => _confirmDelete(usages),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNormal,
                disabledBackgroundColor: AppColors.interactionDisable,
                foregroundColor: AppColors.staticWhite,
                disabledForegroundColor: AppColors.labelAssistive,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('삭제하기', style: AppTypography.body1NormalBold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(List<LeaveUsage> usages) async {
    // 회원탈퇴·로그아웃과 같은 DS 모달을 쓴다. Material AlertDialog는 폭·여백·
    // 버튼 배치가 시안과 달라 이 화면만 다르게 보였다
    final confirmed = await showAppConfirmDialog(
      context,
      title: '사용 내역을 삭제할까요?',
      message: '삭제하면 차감된 연차가 복구돼요.',
      confirmLabel: '삭제하기',
    );
    if (!mounted || confirmed != true) return;

    final picked = [
      for (final i in _selected)
        if (i < usages.length) usages[i],
    ];
    _exitSelecting();

    // 한 건이 막혀도(코스 확정 건은 409) 나머지는 지운다 —
    // 중간에 멈추면 사용자는 무엇이 지워졌는지 알 수 없다
    final repo = ref.read(leaveRepositoryProvider);
    var deleted = 0;
    String? failure;
    for (final usage in picked) {
      try {
        await repo.deleteUsage(usage.id);
        deleted++;
      } on ApiException catch (e) {
        failure ??= e.detail.isEmpty ? '삭제하지 못했어요' : e.detail;
      }
    }
    if (!mounted) return;
    // 지운 만큼 잔여 연차가 늘었다 — 홈도 함께 다시 읽는다
    if (deleted > 0) invalidateLeaveData(ref);
    // 막힌 게 있으면 그 이유를 알려준다 — 코스 화면으로 갈 수 있게
    if (failure case final String message) {
      showAppToast(context, message);
    } else {
      showAppToast(context, '연차 사용 내역이 삭제됐어요.', kind: AppToastKind.success);
    }
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
          if (!_selecting)
            Positioned(
              right: 6,
              child: IconButton(
                onPressed: _showMenu,
                tooltip: '더 보기',
                // 에셋이 Label/Alternative(61%)를 이미 품고 있어 색을 덧입히지 않는다
                icon: SvgPicture.asset(
                  'assets/icons/ic_more_horizontal.svg',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 삭제 모드에서 카드 왼쪽 위에 뜨는 체크박스.
///
/// 시안 실측: 18×18, 반경 6. 끈 상태는 **속을 비워** 카드 배경이 그대로
/// 비쳐야 한다 — 흰색으로 칠하면 코스 건의 하늘색 카드 위에서 흰 사각형이
/// 도드라진다.
class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: checked ? AppColors.primaryNormal : null,
          borderRadius: BorderRadius.circular(6),
          border: checked
              ? null
              : Border.all(color: AppColors.lineNormalNeutral, width: 1.5),
        ),
        child: checked ? const Center(child: _CheckGlyph(size: 11)) : null,
      ),
    );
  }
}

/// 체크 표시. Material [Icons.check]는 시안보다 획이 얇고 꼬리가 길어
/// 18px 박스 안에서 비뚤어 보이므로 직접 그린다.
class _CheckGlyph extends StatelessWidget {
  const _CheckGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _CheckPainter());
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.52)
      ..lineTo(w * 0.38, h * 0.82)
      ..lineTo(w * 0.94, h * 0.18);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.staticWhite
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}

/// 내역 카드 한 장 — 코스 건은 펼치면 상세로 가는 버튼이 붙는다
class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.usage,
    required this.expanded,
    required this.onTap,
    this.selecting = false,
    this.checked = false,
  });

  final LeaveUsage usage;
  final bool expanded;
  final VoidCallback? onTap;

  /// 삭제 모드라 체크박스를 띄우는지
  final bool selecting;
  final bool checked;

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
            if (selecting) ...[
              _SelectBox(checked: checked),
              const SizedBox(height: 10),
            ],
            Row(
              // 펼쳐도 -N일이 아래로 내려가지 않게 위쪽 줄에 맞춘다
              crossAxisAlignment: CrossAxisAlignment.start,
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
