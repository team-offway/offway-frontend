import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_toast.dart';

/// O-02 · 잔여연차 입력 (온보딩)
/// 입력값 저장은 사용자 상태 확정 후 연결한다. 시작하기를 누르면 홈으로 이동.
class LeaveInputScreen extends StatefulWidget {
  const LeaveInputScreen({super.key});

  @override
  State<LeaveInputScreen> createState() => _LeaveInputScreenState();
}

class _LeaveInputScreenState extends State<LeaveInputScreen> {
  static const _minDays = 0.0;
  static const _maxDays = 99.0;

  /// 반차 단위(0.5일)로 증감한다
  static const _step = 0.5;

  double _days = 15;

  /// 숫자 필드를 눌러 직접 입력하는 중인지
  bool _editing = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _commitInput();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 0.5 단위 표기: 정수는 '15일', 소수는 '15.5일'
  String _format(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text일';
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _controller.text = _days == _days.roundToDouble()
          ? _days.toStringAsFixed(0)
          : _days.toStringAsFixed(1);
    });
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  /// 입력값을 0.5 단위로 반올림하고 허용 범위로 맞춘다. 빈 값·오입력은 이전 값 유지
  void _commitInput() {
    final parsed = double.tryParse(_controller.text.trim());
    String? clampMessage;
    setState(() {
      if (parsed != null) {
        final snapped = (parsed / _step).round() * _step;
        // 범위를 벗어난 값은 조용히 깎지 않고 왜 바뀌었는지 알려준다
        if (snapped > _maxDays) {
          clampMessage = '최대 ${_maxDays.toStringAsFixed(0)}일까지 입력할 수 있어요.';
        } else if (snapped < _minDays) {
          clampMessage = '0일보다 적게 입력할 수 없어요.';
        }
        _days = snapped.clamp(_minDays, _maxDays);
      }
      _editing = false;
    });
    _focusNode.unfocus();
    if (clampMessage != null) showAppToast(context, clampMessage!);
  }

  void _changeBy(double delta) {
    setState(() {
      _days = (_days + delta).clamp(_minDays, _maxDays);
    });
  }

  void _complete() {
    if (_editing) _commitInput();
    // TODO(user): 잔여연차 저장(서버/로컬) 연결
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: GestureDetector(
          // 빈 곳을 탭하면 입력 확정 (opaque: 자식 없는 여백도 히트 테스트 대상)
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_editing) _commitInput();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 108),
              SvgPicture.asset(
                'assets/icons/ic_calendar_edit.svg',
                width: 49,
                height: 49,
              ),
              const SizedBox(height: 16),
              Text(
                '남은 연차를 입력해 주세요',
                textAlign: TextAlign.center,
                style: AppTypography.heading1Bold.copyWith(
                  color: AppColors.labelStrong,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '언제든 연차 일수를 변경할 수 있어요.',
                textAlign: TextAlign.center,
                style: AppTypography.headline1Medium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
              const SizedBox(height: 48),
              Center(child: _buildSpinner()),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FilledButton(
                  onPressed: _complete,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryNormal,
                    foregroundColor: AppColors.staticWhite,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('시작하기', style: AppTypography.body1NormalBold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpinner() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: AppColors.fillNormal,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SpinnerButton(
            icon: Icons.remove,
            enabled: _days > _minDays,
            onTap: () => _changeBy(-_step),
            onBlockedTap: () => showAppToast(context, '0일보다 적게 입력할 수 없어요.'),
          ),
          Container(
            width: 64,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.backgroundNormal,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 1),
                  blurRadius: 1.5,
                ),
              ],
            ),
            child: _editing ? _buildInputField() : _buildValueText(),
          ),
          _SpinnerButton(
            icon: Icons.add,
            enabled: _days < _maxDays,
            onTap: () => _changeBy(_step),
            onBlockedTap: () => showAppToast(
              context,
              '최대 ${_maxDays.toStringAsFixed(0)}일까지 입력할 수 있어요.',
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _numberStyle =>
      AppTypography.headline2Bold.copyWith(color: AppColors.labelNeutral);

  Widget _buildValueText() {
    return GestureDetector(
      onTap: _startEditing,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Center(child: Text(_format(_days), style: _numberStyle)),
      ),
    );
  }

  Widget _buildInputField() {
    // 입력 중에도 '숫자 + 일'이 가운데 붙어 보이도록 폭을 내용에 맞춘다
    // (suffixText는 필드 오른쪽 끝에 붙어 숫자와 벌어짐)
    final textWidth = _measureTextWidth(_controller.text, _numberStyle);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: textWidth.clamp(12.0, 42.0),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              // 숫자와 소수점 한 자리까지만 허용
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d?)?')),
            ],
            style: _numberStyle,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}), // 폭 갱신
            onSubmitted: (_) => _commitInput(),
          ),
        ),
        Text('일', style: _numberStyle),
      ],
    );
  }

  double _measureTextWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + 2; // 캐럿 여유
  }
}

class _SpinnerButton extends StatelessWidget {
  const _SpinnerButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.onBlockedTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  /// 한계에 도달해 눌러도 값이 바뀌지 않을 때. 비활성으로 보이지만 탭은 받아
  /// 왜 더 못 누르는지 알려준다(그냥 막으면 고장으로 오해한다).
  final VoidCallback onBlockedTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: enabled ? onTap : onBlockedTap,
        icon: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.labelNeutral : AppColors.labelDisable,
        ),
      ),
    );
  }
}
