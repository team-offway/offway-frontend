import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  double? _days = 0.5;
  final _memo = TextEditingController();

  /// '직접 입력하기'를 골라 입력 칸이 열려 있는지
  bool _customDays = false;

  /// 등록 중이면 버튼을 잠가 같은 요청이 두 번 가지 않게 한다
  bool _submitting = false;
  final _daysInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 글자 수 표시(0/50)를 따라 움직이게 한다
    _memo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _memo.dispose();
    _daysInput.dispose();
    super.dispose();
  }

  bool get _canSubmit => _range != null && _reason != null && _days != null;

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
      // 서버가 센 차감 일수(평일−공휴일)를 기본값으로 채운다.
      // 못 받았으면 고른 날 수를 그대로 쓴다
      _days = picked.consumed ?? _rangeDayCount.toDouble();
    });
  }

  /// 칩에서 고른 값 — 직접 입력 칸은 닫는다
  void _selectPreset(double value) {
    setState(() {
      _days = value;
      _customDays = false;
      _daysInput.clear();
    });
  }

  /// '직접 입력하기' — 칩 아래에 입력 칸을 연다
  void _openCustomDays() {
    setState(() {
      _customDays = true;
      // 입력 전에는 값이 없는 상태로 둬 등록 버튼이 열리지 않게 한다
      _days = null;
      _daysInput.clear();
    });
  }

  /// 직접 입력한 값이 왜 못 쓰는지 — 없으면 정상
  String? _customDaysError(num? remaining) {
    final text = _daysInput.text;
    if (!_customDays || text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) return '지원하지 않는 단위입니다.';
    // 서버가 0.5 단위만 받는다
    if ((parsed * 2) % 1 != 0) return '지원하지 않는 단위입니다.';
    if (remaining != null && parsed > remaining) {
      return '남은 연차보다 많이 입력했어요.';
    }
    return null;
  }

  /// 입력값은 0.5 단위만 받는다 (서버 제약과 같다).
  /// 어긋나면 값을 비워 등록을 막되, 입력 자체는 막지 않는다
  void _onCustomDaysChanged(String text) {
    final parsed = double.tryParse(text);
    setState(() {
      _days = (parsed != null && parsed > 0 && (parsed * 2) % 1 == 0)
          ? parsed
          : null;
    });
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
    final daysError = _customDaysError(remaining);

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
                  const SizedBox(height: 28),
                  _FieldLabel('차감 일수'),
                  const SizedBox(height: 8),
                  _DaysChips(
                    selected: _days,
                    custom: _customDays,
                    onSelect: _selectPreset,
                    onCustom: _openCustomDays,
                  ),
                  if (_customDays) ...[
                    const SizedBox(height: 8),
                    _CustomDaysField(
                      controller: _daysInput,
                      onChanged: _onCustomDaysChanged,
                      error: daysError,
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
class _DaysChips extends StatelessWidget {
  const _DaysChips({
    required this.selected,
    required this.custom,
    required this.onSelect,
    required this.onCustom,
  });

  final double? selected;

  /// '직접 입력하기'가 골라져 입력 칸이 열려 있는지
  final bool custom;
  final ValueChanged<double> onSelect;
  final VoidCallback onCustom;

  /// 시안이 제시하는 빠른 선택값
  static const _presets = [0.5, 1.0];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in _presets) ...[
            LeaveChip(
              label: '${formatLeaveDays(preset)}일',
              selected: !custom && selected == preset,
              onTap: () => onSelect(preset),
              large: true,
            ),
            const SizedBox(width: 10),
          ],
          LeaveChip(
            label: '직접 입력하기',
            selected: custom,
            onTap: onCustom,
            large: true,
          ),
        ],
      ),
    );
  }
}

/// 차감 일수 직접 입력 칸 — 칩 아래에 펼쳐진다.
///
/// 숫자만 받되 '일'을 값에 붙여 보여준다. Flutter의 `suffixText`는 칸 오른쪽
/// 끝에 붙어 시안과 다르므로, 입력 글자를 감추고 그 자리에 값+단위를 겹쳐 그린다.
class _CustomDaysField extends StatelessWidget {
  const _CustomDaysField({
    required this.controller,
    required this.onChanged,
    required this.error,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// 왜 못 쓰는 값인지 — null이면 정상
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final hasError = error != null;
    final filled = text.isNotEmpty;
    final style = AppTypography.body1NormalRegular.copyWith(
      color: AppColors.labelNormal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? AppColors.statusNegative
                  : AppColors.lineNormalNeutral,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // 값과 단위를 한 덩어리로 그려 '일'이 숫자에 붙게 한다
                      if (filled) Text('$text일', style: style),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        onChanged: onChanged,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        // 겹쳐 그린 글자와 이중으로 보이지 않게 원본은 감춘다.
                        // 커서와 선택 영역은 그대로 살아 있다
                        style: style.copyWith(
                          color: filled ? Colors.transparent : null,
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: '차감 일수를 입력해주세요.',
                          hintStyle: AppTypography.body1NormalRegular.copyWith(
                            color: AppColors.labelAssistive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (filled) ...[
                const SizedBox(width: 8),
                SvgPicture.asset(
                  // 기본 에셋은 28% 투명도가 박혀 있어 색을 입혀도 옅다 —
                  // 채워진 원으로 보여야 하므로 불투명 사본을 쓴다
                  hasError
                      ? 'assets/icons/ic_circle_exclamation_solid.svg'
                      : 'assets/icons/ic_check_circle.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    hasError
                        ? AppColors.statusNegative
                        : AppColors.primaryNormal,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (error case final String message) ...[
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.label1NormalMedium.copyWith(
              color: AppColors.statusNegative,
            ),
          ),
        ],
      ],
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
