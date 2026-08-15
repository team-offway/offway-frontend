import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_tab_pills.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../home/presentation/home_screen.dart';

/// 마이 — 프로필과 계정 관리 메뉴
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(homeUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '마이',
                style: AppTypography.title3Bold.copyWith(
                  color: AppColors.labelStrong,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildProfile(user),
            // 시안: 프로필과 메뉴 사이 82
            const SizedBox(height: 82),
            // 로그인 화면의 동의 문구와 같은 순서로 둔다
            _MenuRow(
              label: '이용약관',
              onTap: () => _openDocument(context, AppConfig.termsOfServiceUrl),
            ),
            _MenuRow(
              label: '개인정보처리방침',
              onTap: () => _openDocument(context, AppConfig.privacyPolicyUrl),
            ),
            _MenuRow(label: '로그아웃', onTap: () => _confirmSignOut(context, ref)),
            _MenuRow(
              label: '회원탈퇴',
              onTap: () => context.push(AppRoutes.withdraw),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppTabPills(
        current: AppTab.my,
        onTap: (tab) {
          // 탭끼리는 형제 화면이므로 스택을 쌓지 않고 교체한다
          if (tab == AppTab.home) context.go(AppRoutes.home);
          if (tab == AppTab.myCourse) context.go(AppRoutes.myCourses);
        },
      ),
    );
  }

  /// 하늘색 원 안의 사람 아이콘과 인사말 — 시안은 가운데 정렬 한 덩어리다.
  ///
  /// 이메일과 프로필 수정은 시안에서 빠졌다.
  Widget _buildProfile(AsyncValue<Map<String, dynamic>> user) {
    final nickname = user.value?['nickname'] as String?;
    return Column(
      children: [
        Container(
          // 시안 75.838 — 아이콘은 그 안에서 49.192
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: AppPalette.lightBlue95,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          // 에셋이 Light Blue/80을 이미 품고 있어 색을 덧입히지 않는다
          child: SvgPicture.asset(
            'assets/icons/ic_person.svg',
            width: 49,
            height: 49,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          nickname == null ? '반가워요!' : '$nickname님, 반가워요!',
          textAlign: TextAlign.center,
          style: AppTypography.heading2Bold.copyWith(
            color: AppColors.labelNeutral,
          ),
        ),
      ],
    );
  }

  /// 약관·방침 문서를 앱 안에서 띄운다.
  ///
  /// iOS는 SFSafariViewController로 열려 상단에 주소가 그대로 보이고,
  /// 닫으면 이 화면으로 돌아온다 — 읽으려고 앱을 떠날 이유가 없다.
  Future<void> _openDocument(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    // launchUrl은 실패해도 예외 대신 false를 줄 수 있어 반환값까지 본다
    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened && context.mounted) {
      showAppToast(context, '페이지를 열지 못했어요');
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '로그아웃',
      message: '정말 로그아웃 할까요?',
    );
    if (confirmed != true || !context.mounted) return;
    // 토큰이 남은 채 로그인 화면으로 보내면 로그아웃된 줄 알고 넘어가므로,
    // Keychain 삭제가 실패하면 세션을 유지한 채 실패를 알린다
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      if (!context.mounted) return;
      showAppToast(context, '로그아웃에 실패했어요. 잠시 후 다시 시도해 주세요');
      return;
    }
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // 시안: 좌우 20 · 행 높이 26에 위아래 13씩이 붙어 행 간격 26이 된다
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.headline1Medium.copyWith(
                  color: AppColors.labelNeutral,
                ),
              ),
            ),
            // DS 쉐브론(Tight)은 12×24 비율이다 — 24로 두면 가로로 늘어난다.
            // 에셋이 Label/Alternative를 품고 있어 색을 덧입히지 않는다
            SvgPicture.asset(
              'assets/icons/ic_chevron_right.svg',
              width: 12,
              height: 24,
            ),
          ],
        ),
      ),
    );
  }
}
