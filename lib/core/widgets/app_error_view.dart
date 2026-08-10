import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/tokens/tokens.dart';

/// 서버 오류(500 등)로 화면을 못 그릴 때 대신 보여주는 안내.
///
/// 다시 시도할 길과 홈으로 빠져나갈 길을 함께 준다 —
/// 재시도가 계속 실패해도 사용자가 갇히지 않아야 한다.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    this.title = '오류가 발생했어요',
    this.description = '잠시 후 다시 시도해 주세요',
    this.onRetry,
  });

  final String title;
  final String description;

  /// null이면 '다시 시도' 버튼을 숨긴다
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            // 기본 에셋은 28% 투명도가 박혀 있어 색을 입혀도 옅다
            'assets/icons/ic_circle_exclamation_solid.svg',
            width: 32,
            height: 32,
            colorFilter: const ColorFilter.mode(
              AppColors.primaryNormal,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.heading2Bold.copyWith(
              color: AppColors.labelStrong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.body1NormalMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRetry != null) ...[
                _ActionChip(
                  label: '다시 시도',
                  onTap: onRetry!,
                  background: AppColors.backgroundElevatedAlternative,
                  foreground: AppColors.labelAlternative,
                ),
                const SizedBox(width: 8),
              ],
              _ActionChip(
                label: '홈으로 가기',
                onTap: () => context.go(AppRoutes.home),
                background: AppPalette.coolNeutral20,
                foreground: AppColors.inverseLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// DS Chip — 에러 화면의 두 갈래 행동
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
  });

  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: AppTypography.body2NormalMedium.copyWith(color: foreground),
        ),
      ),
    );
  }
}
