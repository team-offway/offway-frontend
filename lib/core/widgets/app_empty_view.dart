import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 목록에 보여줄 게 없을 때 자리를 채우는 안내.
///
/// 말풍선 위에 주제별 그림을 얹고 제목·부제를 붙이는 DS 빈 상태 구성이다.
/// 화면마다 [illustrationAsset]과 문구만 갈아 끼워 쓴다.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.illustrationAsset,
    required this.title,
    required this.description,
  });

  /// 말풍선 아래에 놓을 48×48 그림
  final String illustrationAsset;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 말풍선이 그림 위에 3px 겹쳐 얹힌다
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/ic_empty_course_bubble.svg',
              width: 29,
              height: 29,
            ),
            Transform.translate(
              offset: const Offset(0, -3),
              child: SvgPicture.asset(illustrationAsset, width: 48, height: 48),
            ),
          ],
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
      ],
    );
  }
}
