import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../data/apple_auth_service.dart';
import '../data/auth_repository.dart';
import '../data/kakao_auth_service.dart';

/// O-01 · 로그인/회원가입
/// 카카오·Apple은 SDK 연동 완료. 서버 인증 도메인 구축 전이라 토큰 교환 실패는
/// 경고만 남기고 온보딩으로 진행한다(서버 배포 후 실패 시 중단으로 변경).
/// 구글은 아직 stub.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _kakaoYellow = Color(0xFFFEE500);
  static const _gray950 = Color(0xFF191B1F);
  static const _textPrimary = Color(0xFF2D3037);
  static const _textSecondary = Color(0xFF686F7E);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _borderMuted = Color(0xFFDCDEE2);
  static const _imagePlaceholder = Color(0xFFF2F3F6);

  final _kakaoAuth = const KakaoAuthService();
  final _appleAuth = const AppleAuthService();
  bool _loading = false;

  /// 소셜 로그인 공통 흐름: 소셜 인증 → 서버 토큰 교환 → 온보딩 이동.
  /// [authenticate]는 서버로 넘길 소셜 토큰을 반환한다.
  Future<void> _runSocialLogin({
    required SocialProvider provider,
    required Future<String> Function() authenticate,
    required bool Function(Object error) isCancelled,
  }) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final socialToken = await authenticate();
      try {
        await ref
            .read(authRepositoryProvider)
            .loginWithSocial(provider, socialToken);
      } catch (e) {
        // TODO(auth): 서버 인증 도메인 배포 후에는 실패 시 진행을 중단할 것
        debugPrint('서버 토큰 교환 실패(서버 미배포 가능성): $e');
      }
      // TODO(auth): 서버 응답의 신규 가입 여부로 온보딩/홈 분기
      if (!mounted) return;
      context.go(AppRoutes.onboardingLeave);
    } catch (e) {
      if (isCancelled(e)) return; // 사용자가 스스로 취소 — 안내 없이 유지
      debugPrint('${provider.name} 로그인 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${provider.label} 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithKakao() {
    return _runSocialLogin(
      provider: SocialProvider.kakao,
      authenticate: _kakaoAuth.login,
      isCancelled: (e) => e is KakaoLoginCancelled,
    );
  }

  Future<void> _loginWithApple() {
    return _runSocialLogin(
      provider: SocialProvider.apple,
      authenticate: () async {
        // 이름·이메일은 최초 로그인 1회만 제공되므로 서버가 이때 저장해야 한다
        final result = await _appleAuth.login();
        return result.identityToken;
      },
      isCancelled: (e) => e is AppleLoginCancelled,
    );
  }

  void _startWithSocial(BuildContext context) {
    // TODO(auth): 구글 로그인 연동
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
                    SvgPicture.asset(
                      'assets/icons/logo_wordmark.svg',
                      height: 40,
                      semanticsLabel: 'OffWay',
                    ),
                    const SizedBox(height: 12),
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
                      onPressed: _loading ? null : _loginWithKakao,
                    ),
                    const SizedBox(height: 16),
                    _SocialLoginButton(
                      label: 'Apple로 시작하기',
                      iconAsset: 'assets/icons/apple_logo.svg',
                      backgroundColor: _gray950,
                      foregroundColor: Colors.white,
                      onPressed: _loading ? null : _loginWithApple,
                    ),
                    const SizedBox(height: 16),
                    _SocialLoginButton(
                      label: '구글 계정으로 시작하기',
                      iconAsset: 'assets/icons/google_logo.svg',
                      backgroundColor: Colors.white,
                      foregroundColor: _textPrimary,
                      borderColor: _borderMuted,
                      onPressed: _loading
                          ? null
                          : () => _startWithSocial(context),
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

  /// null이면 비활성 (로그인 진행 중 중복 탭 방지)
  final VoidCallback? onPressed;

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
