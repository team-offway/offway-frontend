import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/current_user_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../notification/application/push_registration.dart';
import '../../home/presentation/home_screen.dart'
    show homeSnapshotProvider, homeUserProvider;

/// 회원탈퇴 — 무엇이 사라지는지 알리고 한 번 더 묻는다.
///
/// 되돌릴 수 없는 행동이라 화면 하나를 통째로 쓰고, 확인 모달까지 거친다.
class WithdrawScreen extends ConsumerWidget {
  const WithdrawScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = ref.watch(homeUserProvider).value?['nickname'] as String?;

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 시안 301 — 3배 해상도 원본을 줄여 쓴다
                    Image.asset(
                      'assets/images/withdraw_hero.png',
                      width: 301,
                      height: 301,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            nickname == null
                                ? '정말 떠나시겠어요?'
                                : '$nickname님, 정말 떠나시겠어요?',
                            textAlign: TextAlign.center,
                            style: AppTypography.heading2Bold.copyWith(
                              color: AppColors.labelStrong,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '저장한 코스와 연차 기록이 모두 사라져요',
                            textAlign: TextAlign.center,
                            style: AppTypography.body1NormalMedium.copyWith(
                              color: AppColors.labelAlternative,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildActions(context, ref),
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
              '회원탈퇴',
              style: AppTypography.headline2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
          ),
          Positioned(
            left: 6,
            child: AppBackButton(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.my),
            ),
          ),
        ],
      ),
    );
  }

  /// 시안: '더 써볼래요'가 왼쪽(회색), '떠날래요'가 오른쪽(브랜드색).
  /// 되돌릴 수 없는 쪽이 오른쪽이지만, 모달을 한 번 더 거치므로 실수로
  /// 끝까지 가지 않는다
  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.my),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.fillNormal,
                foregroundColor: AppColors.labelNeutral,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('더 써볼래요', style: AppTypography.body1NormalMedium),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => _confirmWithdraw(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNormal,
                foregroundColor: AppColors.staticWhite,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('떠날래요', style: AppTypography.body1NormalBold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWithdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '회원탈퇴',
      message: '저장한 코스와 연차 기록이 모두 사라져요\n탈퇴를 진행할까요?',
      confirmLabel: '탈퇴할게요',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      // 계정이 지워지기 전에 푼다 — 지운 뒤에는 이 기기의 토큰이 누구
      // 것이었는지 서버가 알 수 없다
      await ref.read(pushRegistrationProvider).stop();
      await ref.read(authRepositoryProvider).withdraw();
    } on ApiException catch (e) {
      // 서버가 못 지웠는데 로그인 화면으로 보내면 탈퇴된 줄 알고 넘어간다
      if (!context.mounted) return;
      showAppToast(context, e.detail.isEmpty ? '탈퇴하지 못했어요' : e.detail);
      return;
    }
    // 지워진 계정의 이름·연차가 남아 있으면 다음 사람이 그걸로 인사받는다
    ref
      ..invalidate(currentUserProvider)
      ..invalidate(homeSnapshotProvider);

    if (!context.mounted) return;

    // 남은 화면이 지워진 데이터를 다시 읽지 않도록 처음부터 시작한다
    context.go(AppRoutes.login);
    showAppToast(context, '탈퇴가 완료됐어요', kind: AppToastKind.success);
  }
}
