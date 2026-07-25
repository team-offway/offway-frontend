import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

/// O-02 · 잔여연차 입력 (온보딩, 와이어프레임)
/// 입력값 저장은 사용자 상태 확정 후 연결한다. 건너뛰기/시작하기 모두 홈으로 이동.
class LeaveInputScreen extends StatefulWidget {
  const LeaveInputScreen({super.key});

  @override
  State<LeaveInputScreen> createState() => _LeaveInputScreenState();
}

class _LeaveInputScreenState extends State<LeaveInputScreen> {
  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _textSkip = Color(0xFF545A66);
  static const _fillNeutralWeak = Color(0x0D07194C); // rgba(7,25,76,0.05)
  static const _stepperBar = Color(0xFFE5E8EB);
  static const _spinnerText = Color(0xFF333D4B);
  static const _ctaDisabled = Color(0xFFC5C8CE);

  static const _minDays = 0.0;
  static const _maxDays = 30.0;

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
    setState(() {
      if (parsed != null) {
        final snapped = (parsed / _step).round() * _step;
        _days = snapped.clamp(_minDays, _maxDays);
      }
      _editing = false;
    });
    _focusNode.unfocus();
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
      backgroundColor: Colors.white,
      // 키보드가 올라와도 하단 CTA가 가려지지 않도록 스크롤 대응
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
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 24),
                  child: GestureDetector(
                    onTap: _complete,
                    child: const Text(
                      '건너뛰기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: _textSkip,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 64),
              const Text(
                '남은 연차를 입력해 주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _labelNormal,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '언제든 마이 탭에서 변경할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _textTertiary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 32),
              Center(child: _buildSpinner()),
              const Spacer(),
              _StepGuideRow(number: 1, lines: const ['취향에 맞는 여행만 추천해요']),
              _StepGuideRow(
                number: 2,
                lines: const ['남은 연차로 갈 수 있는', '여행을 찾아드려요'],
              ),
              _StepGuideRow(
                number: 3,
                lines: const ['연차를 더 알차게 쓸 수 있도록', '도와드려요'],
                showBar: false,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _complete,
                    style: FilledButton.styleFrom(
                      // TODO(디자인시스템): CTA 활성/비활성 스타일 확정 후 교체
                      backgroundColor: _ctaDisabled,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '시작하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
        color: _fillNeutralWeak,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SpinnerButton(
            icon: Icons.remove,
            enabled: _days > _minDays,
            onTap: () => _changeBy(-_step),
          ),
          Container(
            width: 78,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A001B37),
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
          ),
        ],
      ),
    );
  }

  Widget _buildValueText() {
    return GestureDetector(
      onTap: _startEditing,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Center(
          child: Text(
            _format(_days),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _spinnerText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField() {
    const textStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: _spinnerText,
    );
    // 입력 중에도 '숫자 + 일'이 가운데 붙어 보이도록 폭을 내용에 맞춘다
    // (suffixText는 필드 오른쪽 끝에 붙어 숫자와 벌어짐)
    final textWidth = _measureTextWidth(_controller.text, textStyle);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: textWidth.clamp(12.0, 46.0),
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
            style: textStyle,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}), // 폭 갱신
            onSubmitted: (_) => _commitInput(),
          ),
        ),
        const Text('일', style: textStyle),
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
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF333D4B) : const Color(0xFFC5C8CE),
        ),
      ),
    );
  }
}

class _StepGuideRow extends StatelessWidget {
  const _StepGuideRow({
    required this.number,
    required this.lines,
    this.showBar = true,
  });

  final int number;
  final List<String> lines;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _LeaveInputScreenState._fillNeutralWeak,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF545A66),
                  ),
                ),
              ),
              if (showBar)
                Container(
                  width: 2,
                  height: 22 + (lines.length - 1) * 25.0,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: _LeaveInputScreenState._stepperBar,
                    borderRadius: BorderRadius.circular(41),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                lines.join('\n'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                  color: Color(0xCC000C1E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
