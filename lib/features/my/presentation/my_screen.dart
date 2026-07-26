import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_tab_pills.dart';
import '../../auth/data/auth_repository.dart';
import '../../home/presentation/home_screen.dart';

/// 마이 — 프로필과 계정 관리 메뉴
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _textPrimary = Color(0xFF2D3037);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _cardBg = Color(0xFFF2F3F6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(homeUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            const Text(
              '마이',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _labelNormal,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 24),
            _buildProfileCard(context, user),
            const SizedBox(height: 32),
            _MenuRow(
              label: '개인정보처리방침',
              // TODO(my): 개인정보처리방침 URL 확정 후 웹뷰/외부 브라우저 연결
              onTap: () => _showPreparing(context, '개인정보처리방침'),
            ),
            _MenuRow(label: '로그아웃', onTap: () => _confirmSignOut(context, ref)),
            _MenuRow(
              label: '회원탈퇴',
              // TODO(my): 서버 회원탈퇴 API 연동 후 실제 처리
              onTap: () => _showPreparing(context, '회원탈퇴'),
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

  Widget _buildProfileCard(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> user,
  ) {
    final nickname = user.value?['nickname'] as String?;
    final email = user.value?['email'] as String?;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 프로필 이미지 자리 (업로드 기능 전까지 기본 아바타)
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFDCDEE2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname == null ? '반가워요!' : '$nickname님, 반가워요!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textTertiary,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            // TODO(my): 프로필 수정 화면 작업 시 연결
            onTap: () => _showPreparing(context, '프로필 수정'),
            child: const Icon(
              Icons.edit_outlined,
              size: 24,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showPreparing(BuildContext context, String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature 기능은 준비 중이에요')));
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // 저장된 토큰 제거 후 로그인 화면으로
    await ref.read(authRepositoryProvider).logout();
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: MyScreen._textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: MyScreen._textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
