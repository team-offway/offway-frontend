import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 장소 썸네일 — 이미지가 없거나 못 불러오면 회색 자리에 아이콘을 남긴다.
///
/// TourAPI 이미지 URL은 종종 죽어 있어서, 빈 칸으로 두면 목록 오른쪽이
/// 들쭉날쭉해 보인다. 자리와 모양은 늘 유지한다.
///
/// 목록의 정사각 썸네일이 기본이고, [width]·[height]를 주면 상세 화면의
/// 가로로 긴 배너로도 쓴다.
class PlaceThumbnail extends StatelessWidget {
  const PlaceThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 70,
    this.radius = 12,
    this.width,
    this.height,
    this.background,
    this.iconSize,
  });

  final String? imageUrl;

  /// 정사각일 때의 한 변. [width]·[height]를 주면 그쪽이 이긴다
  final double size;
  final double radius;

  /// 가로로 긴 배너로 쓸 때 — null이면 [size] 정사각이다
  final double? width;
  final double? height;

  /// 자리 색. 화면마다 쓰는 회색이 달라 열어 둔다
  final Color? background;

  /// 아이콘 한 변. null이면 짧은 쪽의 34%로 잡는다
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: w,
        height: h,
        color: background ?? AppColors.backgroundNormalAlternative,
        child: imageUrl == null
            ? _placeholder(w, h)
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                // 주소가 살아 있어도 서버가 죽어 있을 수 있다 — 빈 칸으로
                // 두면 왜 비었는지 알 수 없으니 자리 아이콘으로 되돌린다
                errorBuilder: (_, _, _) => _placeholder(w, h),
              ),
      ),
    );
  }

  /// DS Icon/Normal/Image — Material 기본(image_outlined)은 모서리 곡률과
  /// 산 모양이 달라 시안과 어긋난다. 에셋에 박힌 검정은 걷어내고 칠한다
  Widget _placeholder(double w, double h) {
    final side = iconSize ?? (w < h ? w : h) * 0.34;
    return Center(
      child: SvgPicture.asset(
        'assets/icons/ic_image.svg',
        width: side,
        height: side,
        colorFilter: const ColorFilter.mode(
          AppColors.labelDisable,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
