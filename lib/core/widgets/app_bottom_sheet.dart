import 'package:flutter/material.dart';

import '../theme/tokens/tokens.dart';
import 'app_icon_button.dart';

/// DS 바텀시트를 띄운다.
///
/// 배경·딤·위쪽 둥근 모서리는 화면마다 같아야 한다. 각 호출부에서 손으로
/// 적으면 한 곳만 값이 어긋나도 눈에 잘 띄지 않는다.
///
/// [maxHeightRatio]를 주면 시트가 화면의 그 비율까지만 차지하고 안에서
/// 스크롤한다 — 운영시간이나 약관처럼 길이를 가늠할 수 없는 내용에 쓴다.
/// (`isScrollControlled`를 함께 켜야 이 상한이 실제로 적용된다. 끄면
/// Flutter 기본값인 화면의 9/16이 먼저 걸린다.)
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? maxHeightRatio,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.backgroundElevated,
    barrierColor: AppColors.materialDimmer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: maxHeightRatio != null,
    constraints: maxHeightRatio == null
        ? null
        : BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * maxHeightRatio,
          ),
    builder: builder,
  );
}

/// 시트 상단 — 가운데 제목과 오른쪽 닫기 버튼.
///
/// 제목은 본문보다 낮은 위계라 헤드라인 17에 옅은 색을 쓴다(가이드).
class AppSheetTitleBar extends StatelessWidget {
  const AppSheetTitleBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: AppTypography.headline2Bold.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
          Positioned(
            // 버튼이 아이콘보다 넓으므로 여백을 줄여 아이콘 위치를 맞춘다
            right: 6,
            child: AppIconButton.close(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
