import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/config/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/apple_auth_service.dart';
import '../../home/presentation/home_screen.dart' show homeSnapshotProvider;
import '../application/current_user_provider.dart';
import '../data/auth_repository.dart';
import '../data/google_auth_service.dart';
import '../data/kakao_auth_service.dart';

/// O-01 · 로그인/회원가입
///
/// 소셜 인증 → 서버 토큰 교환(`POST /auth/callback/{provider}`) → 분기.
/// 교환이 실패하면 진행하지 않는다 — JWT 없이 들어가면 읽기만 되고 쓰기가
/// 전부 403이다. 서버가 준 `isNewUser`로 온보딩과 홈을 가른다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // 소셜 브랜드 색은 DS 토큰이 아니라 각 플랫폼 가이드 값이다
  static const _kakaoYellow = Color(0xFFFEE500);
  static const _gray950 = Color(0xFF191B1F);
  static const _textPrimary = Color(0xFF2D3037);
  static const _borderMuted = Color(0xFFDCDEE2);

  final _kakaoAuth = const KakaoAuthService();
  final _appleAuth = const AppleAuthService();

  /// 약관·방침 링크의 탭 인식기. 위젯이 사라질 때 함께 정리해야 해서 모아 둔다
  final _legalRecognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _legalRecognizers) {
      r.dispose();
    }
    super.dispose();
  }

  /// 눌러서 문서를 여는 밑줄 링크.
  ///
  /// 동의를 받는다고 적어 둔 문서는 실제로 읽을 수 있어야 한다 — 앱 안에서
  /// 띄우므로 읽고 닫으면 로그인 화면으로 돌아온다.
  TextSpan _legalLink(String label, String url) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    _legalRecognizers.add(recognizer);
    return TextSpan(
      text: label,
      recognizer: recognizer,
      style: const TextStyle(
        decoration: TextDecoration.underline,
        // 지정하지 않으면 밑줄이 글자와 다른 색으로 그려진다
        decorationColor: AppColors.labelAssistive,
      ),
    );
  }

  bool _loading = false;

  /// 소셜 로그인 공통 흐름: 소셜 인증 → 서버 토큰 교환 → 온보딩 이동.
  ///
  /// [authenticate]는 서버로 넘길 소셜 토큰과, 최초 로그인 시에만 얻을 수 있는
  /// 프로필(Apple의 이름·이메일)을 함께 반환한다.
  ///
  /// `authorizationCode`는 **Apple만** 채운다 — 탈퇴할 때 Apple 연결을
  /// 해제하는 데 쓰인다. 카카오·구글은 null이다.
  Future<void> _runSocialLogin({
    required SocialProvider provider,
    required Future<
      ({String token, String? authorizationCode, SocialProfile? profile})
    >
    Function()
    authenticate,
    required bool Function(Object error) isCancelled,
  }) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await authenticate();
      // 토큰 교환이 실패하면 여기서 멈춘다 — JWT 없이 들어가면 읽기만 되고
      // 연차 등록·코스 담기가 전부 403이라 앱이 고장난 것처럼 보인다
      final tokens = await ref
          .read(authRepositoryProvider)
          .loginWithSocial(
            provider,
            result.token,
            profile: result.profile,
            authorizationCode: result.authorizationCode,
          );
      // 이제 우리 토큰이 있다 — 로그인 전에 읽어 둔 '게스트' 값을 비워야
      // 홈·마이가 진짜 이름을 다시 묻는다
      ref
        ..invalidate(currentUserProvider)
        ..invalidate(homeSnapshotProvider);

      if (!mounted) return;
      // 이번에 계정이 만들어졌으면 잔여 연차를 받아야 홈이 채워진다.
      // 돌아온 사용자는 그 값이 이미 있어 홈으로 곧장 보낸다
      context.go(tokens.isNewUser ? AppRoutes.onboardingLeave : AppRoutes.home);
    } catch (e) {
      if (isCancelled(e)) return; // 사용자가 스스로 취소 — 안내 없이 유지
      debugPrint('${provider.name} 로그인 실패: $e');
      if (!mounted) return;
      // 서버 detail은 사용자에게 보여줄 문구다 — 원인을 감추면 재시도만 반복한다
      showAppToast(
        context,
        e is ApiException && e.detail.isNotEmpty
            ? e.detail
            : '${provider.label} 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithKakao() {
    return _runSocialLogin(
      provider: SocialProvider.kakao,
      authenticate: () async {
        // 카카오는 프로필을 서버가 액세스 토큰으로 조회한다
        return (
          token: await _kakaoAuth.login(),
          authorizationCode: null,
          profile: null,
        );
      },
      isCancelled: (e) => e is KakaoLoginCancelled,
    );
  }

  Future<void> _loginWithApple() {
    return _runSocialLogin(
      provider: SocialProvider.apple,
      authenticate: () async {
        final result = await _appleAuth.login();
        // 이름·이메일은 최초 로그인 1회만 제공되므로 이때 서버로 함께 넘긴다
        final profile = SocialProfile(
          email: result.email,
          fullName: result.fullName,
          providerUserId: result.userIdentifier.isEmpty
              ? null
              : result.userIdentifier,
        );
        return (
          token: result.identityToken,
          // 1회용·5분 만료라 로그인하는 지금 함께 넘겨야 한다
          authorizationCode: result.authorizationCode,
          profile: profile.isEmpty ? null : profile,
        );
      },
      isCancelled: (e) => e is AppleLoginCancelled,
    );
  }

  Future<void> _loginWithGoogle() {
    return _runSocialLogin(
      provider: SocialProvider.google,
      authenticate: () async {
        final result = await ref.read(googleAuthServiceProvider).login();
        // 구글은 ID 토큰 안에 이메일·이름이 서명돼 들어 있지만, 카카오·Apple과
        // 같은 형태로 넘겨 서버가 provider별로 분기하지 않아도 되게 한다
        return (
          token: result.idToken,
          authorizationCode: null,
          profile: SocialProfile(
            email: result.email,
            fullName: result.displayName,
            providerUserId: result.userId,
          ),
        );
      },
      isCancelled: (e) => e is GoogleLoginCancelled,
    );
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
                    // 가이드는 부제~첫 버튼 사이가 192로 고정이다. 비율로 나누면
                    // 화면이 길수록 로고가 위로 떠 위치가 어긋난다
                    const Spacer(),
                    SvgPicture.asset(
                      'assets/icons/logo_wordmark_blue.svg',
                      height: 38,
                      semanticsLabel: 'OffWay',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '연차로 떠나는 로컬 여행',
                      style: AppTypography.headline1Bold.copyWith(
                        color: AppColors.labelNeutral,
                      ),
                    ),
                    const SizedBox(height: 192),
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
                      label: 'Google로 시작하기',
                      iconAsset: 'assets/icons/google_logo.svg',
                      backgroundColor: Colors.white,
                      foregroundColor: _textPrimary,
                      borderColor: _borderMuted,
                      onPressed: _loading ? null : _loginWithGoogle,
                    ),
                    // 시안: 버튼 그룹 아래 40 띄우고 바로 약관 문구
                    const SizedBox(height: 40),
                    Text.rich(
                      TextSpan(
                        style: AppTypography.caption1Medium.copyWith(
                          color: AppColors.labelAssistive,
                        ),
                        children: [
                          const TextSpan(text: '가입 시 '),
                          _legalLink('이용약관', AppConfig.termsOfServiceUrl),
                          const TextSpan(text: ' 및 '),
                          _legalLink('개인정보 처리방침', AppConfig.privacyPolicyUrl),
                          const TextSpan(text: '에 동의하게 됩니다.'),
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
