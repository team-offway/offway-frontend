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
        // 시안 폭은 320 고정. 최대를 열어두면 넓은 기기에서 늘어나 글줄이
        // 시안보다 길어진다. 좁은 기기에서만 insetPadding만큼 줄어든다
        constraints: const BoxConstraints(maxWidth: 320),
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
              // 위 여백 없음 — 본문 블록의 아래 28이 곧 버튼과의 간격이다.
              // 우측 20 = 시안 28 − 버튼이 자체로 가진 좌우 여백 8
              padding: const EdgeInsets.fromLTRB(28, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogAction(
                    label: cancelLabel,
                    color: AppColors.labelAlternative,
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                  // 시안 간격 24 − 양쪽 버튼 여백 8+8
                  const SizedBox(width: 8),
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

/// 시안의 텍스트 버튼 — 글자 폭에 맞춰 줄어든다.
///
/// 시안의 버튼 박스는 글자를 감싸는 크기다('취소' 28, '삭제하기' 56).
/// 폭을 60으로 잡으면 짧은 '취소'가 부풀어 두 버튼 사이가 시안보다 벌어진다.
///
/// 대신 눌리는 범위는 좌우 여백으로 넓힌다. 시안의 `w-[60px]`은 보이는
/// 크기가 아니라 탭 영역이고, 짧은 글자를 억지로 늘리라는 뜻이 아니다.
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
      child: Padding(
        // 시안 버튼 높이 32 = 글자 24 + 위아래 4.
        // 좌우로도 8을 둬 손가락이 빗나가지 않게 한다 — 글자 사이 간격은
        // 이 여백을 뺀 값으로 맞춘다
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(
          label,
          maxLines: 1,
          style: AppTypography.body1NormalBold.copyWith(color: color),
        ),
      ),
    );
  }
}
