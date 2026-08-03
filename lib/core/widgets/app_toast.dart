import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 토스트가 알리는 결과의 성격
enum AppToastKind {
  /// 왜 뜻대로 안 됐는지 알릴 때
  warning('assets/icons/ic_warning.svg'),

  /// 방금 한 일이 됐다고 알릴 때
  success('assets/icons/ic_check_circle.svg');

  const AppToastKind(this.iconAsset);

  final String iconAsset;
}

/// 상태 메시지를 잠깐 띄우는 토스트 (DS Toast 컴포넌트).
///
/// 어두운 반투명 배경 위에 흰 글자를 얹고 뒤를 흐린다.
/// 화면 하단 CTA 바로 위에 뜨므로 [showAppToast]로 띄운다.
class AppToast extends StatelessWidget {
  const AppToast({
    super.key,
    required this.message,
    this.kind = AppToastKind.warning,
  });

  final String message;
  final AppToastKind kind;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          // 뒤가 비쳐 보이도록 어두운 면을 52%로 깐다
          decoration: BoxDecoration(
            color: AppColors.inverseBackground.withValues(
              alpha: AppOpacity.o52,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(kind.iconAsset, width: 22, height: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: AppTypography.body2NormalBold.copyWith(
                    color: AppColors.staticWhite.withValues(
                      alpha: AppOpacity.o88,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 화면 하단(액션 영역 위)에 토스트를 띄운다.
///
/// 같은 메시지가 연달아 쌓이지 않도록 떠 있던 토스트는 먼저 지운다.
void showAppToast(
  BuildContext context,
  String message, {
  AppToastKind kind = AppToastKind.warning,
}) {
  final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: AppToast(message: message, kind: kind),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      duration: const Duration(seconds: 2),
    ),
  );
}
