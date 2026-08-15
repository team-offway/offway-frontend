import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../home/presentation/home_screen.dart' show homeSnapshotProvider;
import '../../onboarding/data/leave_repository.dart';
import 'leave_date_picker_screen.dart';

/// 사유 칩 — 서버는 자유 문자열(`reason`)을 받으므로 라벨을 그대로 보낸다
const _reasons = ['여행', '개인 사유', '가족 행사', '병가', '기타'];

/// 상세 사유 글자 수 상한 (시안 `0/50`)
const _memoMaxLength = 50;

/// O-12 · 연차 사용 등록.
///
/// 날짜·사유·차감 일수를 채우면 등록 버튼이 열린다.
/// 세 가지가 모두 정해져야 서버가 받는 값이 완성되기 때문이다.
class LeaveRegisterScreen extends ConsumerStatefulWidget {
  const LeaveRegisterScreen({super.key});

  @override
  ConsumerState<LeaveRegisterScreen> createState() =>
      _LeaveRegisterScreenState();
}

class _LeaveRegisterScreenState extends ConsumerState<LeaveRegisterScreen> {
  DateTimeRange? _range;
  // 가장 흔한 조합을 미리 골라둔다 — 날짜만 정하면 바로 등록할 수 있게
  String? _reason = _reasons.first;
  final _memo = TextEditingController();

  /// 등록 중이면 버튼을 잠가 같은 요청이 두 번 가지 않게 한다
  bool _submitting = false;

  /// 차감 일수 — 날짜를 고르면 서버가 센 값이 채워지고 사용자가 고칠 수 있다
  final _daysInput = TextEditingController();
  final _daysFocus = FocusNode();

  /// 자동 계산값을 사용자가 손댔는지 — 아래 안내 문구가 이 값으로 갈린다
  bool _daysEdited = false;

  @override
  void initState() {
    super.initState();
    // 글자 수 표시(0/50)를 따라 움직이게 한다
    _memo.addListener(() => setState(() {}));
    // 지우기·체크 아이콘이 포커스를 따라 바뀐다.
    // 입력 자체는 TextField의 onChanged가 setState를 부르므로 리스너를 달지
    // 않는다 — 컨트롤러 리스너까지 두면 _pickDate가 text를 채울 때
    // setState가 겹쳐 캘린더의 계산 상태가 초기화된다
    _daysFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _memo.dispose();
    _daysInput.dispose();
    _daysFocus.dispose();
    super.dispose();
  }

  /// 입력 칸의 현재 값 — '2.5일'처럼 단위가 붙어 있어도 숫자만 읽는다
  double? get _days {
    final text = _daysInput.text.replaceAll('일', '').trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  bool get _canSubmit =>
      _range != null && _reason != null && _days != null && _daysError == null;

  /// 빌드가 채워 두는 현재 오류 — `_canSubmit`이 이 값을 본다
  String? _daysError;

  /// 고른 기간의 날 수 — 차감 일수 기본값을 여기서 잡는다
  int get _rangeDayCount =>
      _range == null ? 0 : _range!.end.difference(_range!.start).inDays + 1;

  Future<void> _pickDate() async {
    final picked = await Navigator.of(context)
        .push<({DateTimeRange range, double? consumed})>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => LeaveDatePickerScreen(initialRange: _range),
          ),
        );
    if (picked == null) return;
    setState(() {
      _range = picked.range;
      // 서버가 센 차감 일수(평일−공휴일)를 자동으로 채운다.
      // 못 받았으면 고른 날 수를 그대로 쓴다
      final auto = picked.consumed ?? _rangeDayCount.toDouble();
      _daysInput.text = '${formatLeaveDays(auto)}일';
      // 날짜를 다시 고르면 자동 계산으로 되돌아간다
      _daysEdited = false;
    });
  }

  /// 입력값이 왜 못 쓰는지 — 없으면 정상.
  /// 남은 연차는 빌드 시점에만 알 수 있어 화면이 넘겨준다
  String? _daysErrorFor(num? remaining) {
    final text = _daysInput.text.replaceAll('일', '').trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) return '지원하지 않는 단위입니다.';
    // 서버가 0.25(반반차) 단위까지 받는다
    if ((parsed * 4) % 1 != 0) return '지원하지 않는 단위입니다.';
    if (remaining != null && parsed > remaining) {
      return '남은 연차보다 많이 입력했어요.';
    }
    return null;
  }

  Future<void> _submit() async {
    final range = _range;
    final days = _days;
    if (range == null || days == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      // TODO(server): 여러 날을 고르면 날짜별로 나눠 보내야 하는지 확인 필요.
      // 지금은 시작일에 전체 차감 일수를 한 번에 기록한다
      //
      // TODO(server): 서버 요청에 memo 필드가 없다(usedOn·days·reason·courseId만).
      // 상세 사유를 버리지 않도록 reason 뒤에 붙여 보낸다 — 필드가 생기면 분리한다
      final memo = _memo.text.trim();
      await ref
          .read(leaveRepositoryProvider)
          .addUsage(
            usedOn: range.start,
            days: days,
            reason: memo.isEmpty ? _reason : '$_reason · $memo',
          );
      if (!mounted) return;
      // 잔여 연차가 줄었으니 홈·내 연차가 새 값을 읽게 한다
      ref.invalidate(homeSnapshotProvider);
      // 이 화면이 사라진 뒤에도 토스트가 남도록 부모 화면에 띄운다.
      // pop 뒤에는 이 위젯의 context가 죽으므로 부모를 미리 잡아둔다
      final parent = Navigator.of(context).context;
      Navigator.of(context).pop();
      if (!parent.mounted) return;
      showAppToast(parent, '등록 완료! 남은 연차를 확인해보세요.', kind: AppToastKind.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 서버 문구가 사용자용이면 그대로, 아니면 시안 문구로 알린다
      showAppToast(
        context,
        e.detail.isEmpty ? '등록에 실패했어요. 다시 시도해 주세요' : e.detail,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 남은 연차보다 많이 쓸 수 없으므로 상한으로 쓴다
    final remaining =
        ref.watch(homeSnapshotProvider).value?.user['remainingLeaveDays']
            as num?;
    final daysError = _daysErrorFor(remaining);
    // 빌드 중에는 setState를 부를 수 없어 필드에만 담아 둔다
    _daysError = daysError;

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                children: [
                  _FieldLabel('날짜'),
                  const SizedBox(height: 8),
                  _DateField(range: _range, onTap: _pickDate),
                  const SizedBox(height: 28),
                  _FieldLabel('사유'),
                  const SizedBox(height: 8),
                  _ChipRow(
                    labels: _reasons,
                    selected: _reason,
                    onSelect: (v) => setState(() => _reason = v),
                  ),
                  const SizedBox(height: 8),
                  _MemoField(controller: _memo),
                  // 차감 일수는 날짜에서 계산된 값이라 날짜를 고르기 전에는
                  // 보여줄 것이 없다 — 섹션을 통째로 감춘다
                  if (_range != null) ...[
                    const SizedBox(height: 28),
                    _FieldLabel('차감 일수'),
                    const SizedBox(height: 8),
                    _DaysField(
                      controller: _daysInput,
                      focusNode: _daysFocus,
                      error: daysError,
                      edited: _daysEdited,
                      onChanged: (_) => setState(() => _daysEdited = true),
                      onClear: () => setState(_daysInput.clear),
                    ),
                  ],
                ],
              ),
            ),
            _SubmitBar(
              enabled: _canSubmit && daysError == null && !_submitting,
              onTap: _submit,
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
              '연차 사용 등록',
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
        ],
      ),
    );
  }
}

/// 입력 묶음 위의 제목 ('날짜' · '사유' · '차감 일수')
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.body1NormalMedium.copyWith(
        color: AppColors.labelNeutral,
      ),
    );
  }
}

/// 날짜 입력 칸 — 누르면 달력이 뜬다
class _DateField extends StatelessWidget {
  const _DateField({required this.range, required this.onTap});

  final DateTimeRange? range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = range;
    final label = r == null ? '날짜를 선택해 주세요' : _format(r);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lineNormalNeutral),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body1NormalRegular.copyWith(
                    color: r == null
                        ? AppColors.labelAssistive
                        : AppColors.labelNormal,
                  ),
                ),
              ),
            ),
            SvgPicture.asset(
              'assets/icons/ic_calendar.svg',
              width: 22,
              height: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// `2026.07.20 ~ 07.22 · 3일` — 하루면 날짜 하나만 보여준다
  String _format(DateTimeRange r) {
    String two(int v) => v.toString().padLeft(2, '0');
    final start = '${r.start.year}.${two(r.start.month)}.${two(r.start.day)}';
    if (r.start == r.end) return start;
    final days = r.end.difference(r.start).inDays + 1;
    return '$start ~ ${two(r.end.month)}.${two(r.end.day)} · $days일';
  }
}

/// 사유 칩 줄 — 가로로 넘치면 스크롤된다
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, label) in labels.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            LeaveChip(
              label: label,
              selected: label == selected,
              onTap: () => onSelect(label),
            ),
          ],
        ],
      ),
    );
  }
}

/// 차감 일수 칩 — 자주 쓰는 값과 직접 입력
/// 차감 일수 입력 칸 — 날짜를 고르면 자동 계산값이 채워지고 사용자가 고칠 수 있다.
///
/// 오른쪽 아이콘과 아래 안내가 상태를 알린다.
/// 기본 연필 · 입력 중 지우기 · 고친 뒤 체크 · 잘못된 값 느낌표
class _DaysField extends StatelessWidget {
  const _DaysField({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.edited,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// 왜 못 쓰는 값인지 — null이면 정상
  final String? error;

  /// 자동 계산값을 사용자가 손댔는지 — 안내 문구가 이 값으로 갈린다
  final bool edited;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final focused = focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundNormal,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? AppColors.statusNegative
                  : focused
                  ? AppColors.primaryNormal
                  : AppColors.lineNormalNeutral,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: AppTypography.body1NormalRegular.copyWith(
                      color: AppColors.labelNormal,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TrailingIcon(
                hasError: hasError,
                focused: focused,
                edited: edited,
                onClear: onClear,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 오류가 있으면 그 이유를, 없으면 값이 어디서 왔는지 알린다
        Text(
          error ??
              (edited
                  ? '차감 일수가 직접 입력한 값으로 수정됐어요.'
                  : '자동 계산된 값이에요. 다르게 썼다면 직접 수정할 수 있어요.'),
          style: AppTypography.caption1Regular.copyWith(
            color: hasError
                ? AppColors.statusNegative
                : AppColors.labelAlternative,
          ),
        ),
      ],
    );
  }
}

/// 입력 칸 오른쪽 아이콘 — 상태마다 다른 것이 붙는다
class _TrailingIcon extends StatelessWidget {
  const _TrailingIcon({
    required this.hasError,
    required this.focused,
    required this.edited,
    required this.onClear,
  });

  final bool hasError;
  final bool focused;
  final bool edited;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      // 에셋이 회색이라 오류 색을 입힌다
      return SvgPicture.asset(
        'assets/icons/ic_circle_exclamation_solid.svg',
        width: 22,
        height: 22,
        colorFilter: const ColorFilter.mode(
          AppColors.statusNegative,
          BlendMode.srcIn,
        ),
      );
    }
    if (focused) {
      return GestureDetector(
        onTap: onClear,
        behavior: HitTestBehavior.opaque,
        child: Icon(Icons.cancel, size: 22, color: AppColors.labelAssistive),
      );
    }
    // 에셋이 각자 제 색(체크는 브랜드색, 연필은 Label/Alternative)을 품고 있다
    return SvgPicture.asset(
      edited
          ? 'assets/icons/ic_check_circle_fill.svg'
          : 'assets/icons/ic_write.svg',
      width: 22,
      height: 22,
    );
  }
}

/// DS Category 칩 (Alternative) — 고르면 브랜드색 테두리와 옅은 배경
class LeaveChip extends StatelessWidget {
  const LeaveChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.large = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 차감 일수 줄은 사유 줄보다 한 단계 큰 칩을 쓴다
  final bool large;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: large
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
            : const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryNormal.withValues(alpha: AppOpacity.o5)
              : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primaryNormal.withValues(alpha: AppOpacity.o43)
                : AppColors.lineNormalNeutral,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.body2NormalMedium.copyWith(
            color: selected
                ? AppColors.primaryNormal
                : AppColors.labelAlternative,
          ),
        ),
      ),
    );
  }
}

/// 상세 사유 입력 — 오른쪽 아래에 글자 수를 센다
class _MemoField extends StatelessWidget {
  const _MemoField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lineNormalNeutral),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: controller,
              maxLines: 2,
              maxLength: _memoMaxLength,
              // 글자 수는 아래에서 직접 그리므로 기본 카운터는 감춘다
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              style: AppTypography.body1NormalRegular.copyWith(
                color: AppColors.labelNormal,
              ),
              decoration: InputDecoration.collapsed(
                hintText: '상세 사유를 입력할 수 있어요.',
                hintStyle: AppTypography.body1NormalRegular.copyWith(
                  color: AppColors.labelAssistive,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: AppOpacity.o74,
            child: Text(
              '${controller.text.characters.length}/$_memoMaxLength',
              style: AppTypography.label2Medium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 아래 고정 등록 버튼 (DS Action Area)
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? onTap : null,
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
          child: Text('등록하기', style: AppTypography.body1NormalBold),
        ),
      ),
    );
  }
}
