import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

/// O-01 · 로그인/회원가입 (와이어프레임)
/// 소셜 로그인은 서버·SDK 연동 전이므로 버튼 탭 시 홈으로 이동만 한다.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _kakaoYellow = Color(0xFFFEE500);
  static const _gray950 = Color(0xFF191B1F);
  static const _textPrimary = Color(0xFF2D3037);
  static const _textSecondary = Color(0xFF686F7E);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _borderMuted = Color(0xFFDCDEE2);
  static const _imagePlaceholder = Color(0xFFF2F3F6);

  void _startWithSocial(BuildContext context) {
    // TODO(auth): 소셜 로그인 연동 후 신규/기존 회원 분기
    context.go(AppRoutes.onboardingLeave);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    // 로고 일러스트 자리 (디자인 확정 전 플레이스홀더)
                    Container(
                      width: 190,
                      height: 190,
                      color: _imagePlaceholder,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'offway',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '연차로 떠나는 로컬 여행',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF171719),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const Spacer(flex: 2),
                    _SocialLoginButton(
                      label: '카카오로 시작하기',
                      iconAsset: 'assets/icons/kakao_logo.svg',
                      backgroundColor: _kakaoYellow,
                      foregroundColor: _textPrimary,
                      onPressed: () => _startWithSocial(context),
                    ),
                    const SizedBox(height: 16),
                    _SocialLoginButton(
                      label: 'Apple로 시작하기',
                      iconAsset: 'assets/icons/apple_logo.svg',
                      backgroundColor: _gray950,
                      foregroundColor: Colors.white,
                      onPressed: () => _startWithSocial(context),
                    ),
                    const SizedBox(height: 16),
                    _SocialLoginButton(
                      label: '구글 계정으로 시작하기',
                      iconAsset: 'assets/icons/google_logo.svg',
                      backgroundColor: Colors.white,
                      foregroundColor: _textPrimary,
                      borderColor: _borderMuted,
                      onPressed: () => _startWithSocial(context),
                    ),
                    const SizedBox(height: 20),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _textSecondary,
                          letterSpacing: -0.6,
                        ),
                        children: [
                          const TextSpan(text: '이미 계정이 있으신가요? '),
                          TextSpan(
                            text: '로그인',
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                            // TODO(auth): 로그인/회원가입 분기 정책 확정 시 연결
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textTertiary,
                          letterSpacing: -0.4,
                        ),
                        children: [
                          TextSpan(text: '가입 시 '),
                          TextSpan(
                            text: '이용약관',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: ' 및 '),
                          TextSpan(
                            text: '개인정보 처리방침',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: '에 동의하게 됩니다.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.label,
    required this.iconAsset,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final String iconAsset;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: borderColor != null
                  ? Border.all(color: borderColor!)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(iconAsset, width: 20, height: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
