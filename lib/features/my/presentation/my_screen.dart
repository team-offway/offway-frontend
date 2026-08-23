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
import '../../notification/application/push_registration.dart';
import '../../auth/application/current_user_provider.dart';
import '../../home/presentation/home_screen.dart' show homeSnapshotProvider;

/// 마이 — 프로필과 계정 관리 메뉴
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

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
              // 시안 Bar는 높이 44 — 위아래 10을 뺀 24가 제목 몫이다.
              // 24pt 글자를 줄높이 1.334로 그리면 32가 되어 8이 더 밀린다
              child: SizedBox(
                height: 24,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '마이',
                    style: AppTypography.title3Bold.copyWith(
                      color: AppColors.labelStrong,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildProfile(user),
            // 시안: 인사말 끝에서 메뉴 첫 행까지 82.
            // 행 간격 26은 _MenuRow가 아래쪽에만 달고 있어 여기서 겹치지 않는다
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

  /// 프로필 사진이 없거나 못 불러왔을 때 쓰는 아이콘.
  /// 에셋이 Light Blue/80을 이미 품고 있어 색을 덧입히지 않는다
  static Widget get _defaultAvatar =>
      SvgPicture.asset('assets/icons/ic_person.svg', width: 49, height: 49);

  /// 하늘색 원 안의 프로필 사진(없으면 아이콘)과 인사말 —
  /// 시안은 가운데 정렬 한 덩어리다. 이메일과 프로필 수정은 시안에서 빠졌다.
  Widget _buildProfile(AsyncValue<Map<String, dynamic>> user) {
    final nickname = user.value?['nickname'] as String?;
    final photoUrl = user.value?['profileImageUrl'] as String?;
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
          clipBehavior: Clip.antiAlias,
          // 소셜 프로필 사진이 있으면 그걸, 없으면 기본 아이콘을 쓴다.
          // 사진 주소가 죽어 있을 수도 있어 실패하면 아이콘으로 되돌린다
          child: photoUrl == null || photoUrl.isEmpty
              ? _defaultAvatar
              : Image.network(
                  photoUrl,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _defaultAvatar,
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
      // 문서를 못 연 것은 되돌릴 수 있는 일이라 주의(삼각형)로 알린다 —
      // 시안도 Triangle Exclamation이다
      showAppToast(context, '페이지를 열지 못했어요.', kind: AppToastKind.cautionary);
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
      // 이 기기로 더는 알림이 가지 않게 한다 — 로그아웃했는데 푸시가
      // 계속 오면 계정이 남아 있는 것처럼 보인다
      await ref.read(pushRegistrationProvider).stop();
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      if (!context.mounted) return;
      showAppToast(context, '로그아웃에 실패했어요. 잠시 후 다시 시도해 주세요');
      return;
    }
    // 다음 사람이 옛 이름으로 인사받지 않게 비운다 — autoDispose가 아니라
    // 두면 그대로 남는다
    ref
      ..invalidate(currentUserProvider)
      ..invalidate(homeSnapshotProvider);

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
        // 시안: 좌우 20 · 행 높이 26 · 행 사이 26.
        // 간격을 아래에만 두어 첫 행이 프로필과의 82를 밀어내지 않게 한다
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        // Pretendard 글리프가 줄높이 26보다 조금 커서 그냥 두면 행마다
        // 1pt 남짓 새고, 네 행을 지나며 시안과 눈에 띄게 벌어진다
        child: SizedBox(
          height: 26,
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
      ),
    );
  }
}
