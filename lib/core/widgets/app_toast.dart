import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 토스트가 알리는 결과의 성격 (DS Toast의 variant).
///
/// 아이콘이 없는 [normal] 말고는 모두 채워진 원·삼각형 아이콘을 앞에 둔다.
enum AppToastKind {
  /// 상태를 가리지 않는 단순 안내 — 아이콘 없이 문구만
  normal(null),

  /// 방금 한 일이 됐다고 알릴 때
  success('assets/icons/ic_check_circle.svg'),

  /// 주의가 필요할 때
  cautionary('assets/icons/ic_warning.svg'),

  /// 왜 뜻대로 안 됐는지 알릴 때
  negative('assets/icons/ic_circle_exclamation.svg');

  const AppToastKind(this.iconAsset);

  /// null이면 아이콘 없이 문구만 보여준다
  final String? iconAsset;
}

/// 상태 메시지를 잠깐 띄우는 토스트 (DS Toast 컴포넌트).
///
/// 어두운 면(52%) 위에 브랜드색을 5% 덧씌우고 뒤를 흐린다. 아이콘은 가운데가
/// 뚫려 있어 흰 원을 깔아야 어두운 배경이 비쳐 보이지 않는다.
///
/// 화면 하단에 띄울 때는 [showAppToast]를 쓴다.
class AppToast extends StatelessWidget {
  const AppToast({
    super.key,
    required this.message,
    this.kind = AppToastKind.negative,
  });

  final String message;
  final AppToastKind kind;

  @override
  Widget build(BuildContext context) {
    final iconAsset = kind.iconAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.inverseBackground.withValues(
              alpha: AppOpacity.o52,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primaryNormal.withValues(alpha: AppOpacity.o5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              // 문구가 짧아도 폭을 채운다 — 가이드는 화면 폭에 맞춘 막대다
              constraints: const BoxConstraints(minHeight: 54),
              child: Row(
                children: [
                  if (iconAsset != null) ...[
                    _StatusIcon(asset: iconAsset),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        message,
                        style: AppTypography.body2NormalBold.copyWith(
                          color: AppColors.staticWhite.withValues(
                            alpha: AppOpacity.o88,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 상태 아이콘 — 뚫린 가운데로 어두운 배경이 비치지 않게 흰 원을 깔고 얹는다
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 가이드의 Filler — 아이콘 크기의 절반짜리 흰 원
          Container(
            width: 11,
            height: 11,
            decoration: const BoxDecoration(
              color: AppColors.staticWhite,
              shape: BoxShape.circle,
            ),
          ),
          SvgPicture.asset(asset, width: 22, height: 22),
        ],
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
  AppToastKind kind = AppToastKind.negative,
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
