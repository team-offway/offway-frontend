import 'package:flutter/material.dart';

import '../theme/tokens/tokens.dart';

/// DS 모달 — 제목·설명과 취소/확인 텍스트 버튼.
///
/// Material 기본 `AlertDialog`는 모서리·여백·버튼 색이 시안과 달라 화면마다
/// 따로 맞추게 된다. 확인을 묻는 자리는 모두 이걸 쓴다.
///
/// 확인을 누르면 `true`, 취소·바깥 탭·뒤로가기는 `null`이 온다 —
/// 호출부는 `== true`로만 판단하면 된다.
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = '취소',
  String confirmLabel = '확인',
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: AppColors.materialDimmer,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.backgroundElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        // 시안: 최소 320 · 최대 400
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.heading2Bold.copyWith(
                      color: AppColors.labelNormal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: AppTypography.body2NormalRegular.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogAction(
                    label: cancelLabel,
                    color: AppColors.labelAlternative,
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                  const SizedBox(width: 24),
                  _DialogAction(
                    label: confirmLabel,
                    color: AppColors.primaryNormal,
                    onTap: () => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 시안의 텍스트 버튼 — 위아래 4에 최소 너비 60.
///
/// 폭을 60으로 고정하면 '탈퇴할게요'처럼 긴 문구가 두 줄로 접힌다.
/// 최소값으로만 두고 글자가 길면 그만큼 늘어나게 한다.
class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: AppTypography.body1NormalBold.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}
