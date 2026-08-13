import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens/tokens.dart';

/// 장소 썸네일 — 이미지가 없거나 못 불러오면 회색 자리에 아이콘을 남긴다.
///
/// TourAPI 이미지 URL은 종종 죽어 있어서, 빈 칸으로 두면 목록 오른쪽이
/// 들쭉날쭉해 보인다. 자리와 모양은 늘 유지한다.
///
/// 사진이 없는 장소에는 서버가 [mapSearchUrl]을 대신 준다 — 그때는 눌러서
/// 지도에서 찾아볼 수 있게 한다(숙박처럼 사진이 비는 곳이 많다).
class PlaceThumbnail extends StatelessWidget {
  const PlaceThumbnail({
    super.key,
    required this.imageUrl,
    this.mapSearchUrl,
    this.size = 70,
    this.radius = 12,
  });

  final String? imageUrl;
  final String? mapSearchUrl;
  final double size;
  final double radius;

  bool get _canOpenMap =>
      (imageUrl == null || imageUrl!.isEmpty) &&
      mapSearchUrl != null &&
      mapSearchUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final thumb = ClipRRect(
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

    if (!_canOpenMap) return thumb;

    return Semantics(
      button: true,
      label: '지도에서 찾기',
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse(mapSearchUrl!),
          mode: LaunchMode.externalApplication,
        ),
        behavior: HitTestBehavior.opaque,
        child: thumb,
      ),
    );
  }

  /// 사진이 없을 때의 자리. 지도로 갈 수 있으면 그렇다는 걸 아이콘으로 알린다
  Widget get _placeholder => Center(
    child: Icon(
      _canOpenMap ? Icons.map_outlined : Icons.image_outlined,
      size: size * 0.34,
      color: _canOpenMap ? AppColors.labelAlternative : AppColors.labelDisable,
    ),
  );
}
