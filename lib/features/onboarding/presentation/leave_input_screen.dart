import 'package:flutter/material.dart';
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

  static const _minDays = 0;
  static const _maxDays = 30;

  int _days = 15;

  void _complete() {
    // TODO(user): 잔여연차 저장(서버/로컬) 연결
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
    );
  }

  Widget _buildSpinner() {
    final canDecrease = _days > _minDays;
    final canIncrease = _days < _maxDays;
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
            enabled: canDecrease,
            onTap: () => setState(() => _days--),
          ),
          Container(
            width: 61,
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
            child: Text(
              '$_days일',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _spinnerText,
              ),
            ),
          ),
          _SpinnerButton(
            icon: Icons.add,
            enabled: canIncrease,
            onTap: () => setState(() => _days++),
          ),
        ],
      ),
    );
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
