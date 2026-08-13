import 'package:flutter/material.dart';

import '../theme/tokens/tokens.dart';

/// 장소 썸네일 — 이미지가 없거나 못 불러오면 회색 자리에 아이콘을 남긴다.
///
/// TourAPI 이미지 URL은 종종 죽어 있어서, 빈 칸으로 두면 목록 오른쪽이
/// 들쭉날쭉해 보인다. 자리와 모양은 늘 유지한다.
class PlaceThumbnail extends StatelessWidget {
  const PlaceThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 70,
    this.radius = 12,
  });

  final String? imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: AppColors.backgroundNormalAlternative,
        child: imageUrl == null
            ? _placeholder
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder,
              ),
      ),
    );
  }

  Widget get _placeholder => Center(
    child: Icon(
      Icons.image_outlined,
      size: size * 0.34,
      color: AppColors.labelDisable,
    ),
  );
}
