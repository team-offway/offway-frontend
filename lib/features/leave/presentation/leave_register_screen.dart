import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_toast.dart';

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
  String? _reason;
  double? _days;
  final _memo = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 글자 수 표시(0/50)를 따라 움직이게 한다
    _memo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  bool get _canSubmit => _range != null && _reason != null && _days != null;

  /// 고른 기간의 날 수 — 차감 일수 기본값을 여기서 잡는다
  int get _rangeDayCount =>
      _range == null ? 0 : _range!.end.difference(_range!.start).inDays + 1;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range,
      helpText: '연차 사용일 선택',
      saveText: '선택 완료',
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      // 하루짜리면 1일, 여러 날이면 그만큼을 기본 차감으로 채워준다
      _days = _rangeDayCount.toDouble();
    });
  }

  void _submit() {
    // TODO(server): `POST /api/v1/leaves/me/usages`에 붙인다.
    // 기간을 고르면 날짜별로 나눠 보내야 하는지 백엔드와 정할 것
    showAppToast(context, '연차 등록은 서버 연동 후 동작해요');
  }

  @override
  Widget build(BuildContext context) {
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
                    onSelect: (v) => setState(() => _days = v),
                    onCustom: _pickCustomDays,
                  ),
                ],
              ),
            ),
            _SubmitBar(enabled: _canSubmit, onTap: _submit),
          ],
        ),
      ),
    );
  }

  /// '직접 입력하기' — 0.5 단위로만 받는다 (서버 제약과 같다)
  Future<void> _pickCustomDays() async {
    final controller = TextEditingController(
      text: _days == null ? '' : formatLeaveDays(_days!),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundNormal,
        title: Text(
          '차감 일수 입력',
          style: AppTypography.headline2Bold.copyWith(
            color: AppColors.labelNormal,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(hintText: '0.5 단위로 입력해 주세요'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    // 0.5로 나눠떨어지지 않으면 서버가 거절하므로 여기서 막는다
    if (value <= 0 || (value * 2) % 1 != 0) {
      showAppToast(context, '차감 일수는 0.5일 단위로 입력해 주세요');
      return;
    }
    setState(() => _days = value);
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
    required this.onSelect,
    required this.onCustom,
  });

  final double? selected;
  final ValueChanged<double> onSelect;
  final VoidCallback onCustom;

  /// 시안이 제시하는 빠른 선택값
  static const _presets = [0.5, 1.0];

  @override
  Widget build(BuildContext context) {
    // 프리셋에 없는 값을 직접 넣었으면 그 칩이 골라진 것으로 본다
    final isCustom = selected != null && !_presets.contains(selected);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in _presets) ...[
            LeaveChip(
              label: '${formatLeaveDays(preset)}일',
              selected: selected == preset,
              onTap: () => onSelect(preset),
              large: true,
            ),
            const SizedBox(width: 10),
          ],
          LeaveChip(
            label: isCustom ? '${formatLeaveDays(selected!)}일' : '직접 입력하기',
            selected: isCustom,
            onTap: onCustom,
            large: true,
          ),
        ],
      ),
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
