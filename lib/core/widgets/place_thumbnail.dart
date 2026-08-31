import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../network/image_cache.dart';
import '../network/image_url.dart';
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
    this.decodeToFit = true,
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

  /// 그리는 폭까지만 디코드할지(기본). 화면에서는 켜 두는 게 맞다.
  ///
  /// **캡처(공유 이미지)에서는 끈다.** 축소 디코드는 이미지 캐시 키에 폭이
  /// 붙어(`ResizeImage`), 캡처 전에 `precacheImage`로 받아 둔 원본 키와
  /// 달라진다. 그러면 캐시를 못 찾고 다시 디코드하는 사이에 찍혀 사진이
  /// 빈 자리로 남는다(#155). 끄면 프리캐시와 같은 키라 바로 그려진다
  final bool decodeToFit;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final content = Container(
      width: w,
      height: h,
      color: background ?? AppColors.backgroundNormalAlternative,
      child: imageUrl == null
          ? _placeholder(w, h)
          : LayoutBuilder(
              builder: (context, constraints) => CachedNetworkImage(
                // TourAPI가 http로 주는데 iOS가 평문을 막는다 — 같은 파일을
                // 주는 https로 올려 받는다
                imageUrl: httpsImageUrl(imageUrl)!,
                cacheManager: appImageCacheManager,
                fit: BoxFit.cover,
                // TourAPI 원본은 장당 100~500KB에 800px가 넘는다. 디스크에
                // 캐시해 다음 실행부터 다시 받지 않고, 그리는 폭(픽셀)까지만
                // 디코드해 메모리·디코드 시간을 줄인다 — 152pt 카드에
                // 원본 해상도 그대로 올릴 이유가 없다
                memCacheWidth: decodeToFit
                    ? decodeWidthFor(context, constraints.maxWidth)
                    : null,
                // 기본 0.5초 페이드인을 끈다 — 디스크 캐시에서 바로 왔는데도
                // 스르륵 나타나 오히려 느려 보인다. 예전처럼 준비되는 즉시 뜬다
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholderFadeInDuration: Duration.zero,
                // 주소가 살아 있어도 서버가 죽어 있을 수 있다 — 빈 칸으로
                // 두면 왜 비었는지 알 수 없으니 자리 아이콘으로 되돌린다
                errorWidget: (_, _, _) => _placeholder(w, h),
                // 받는 동안은 자리색만 — 아이콘까지 띄우면 실패로 보인다
                placeholder: (_, _) => const SizedBox.expand(),
              ),
            ),
    );
    // radius 0이면 자를 것이 없다. 그래도 ClipRRect를 두면 바깥에서 둥글게
    // 자르는 카드와 겹쳐 안티앨리어싱이 두 번 걸리고, 모서리에 계단이 남는다
    if (radius == 0) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: content,
    );
  }

  /// 이 폭(논리 px)으로 그릴 이미지를 몇 픽셀까지 디코드할지.
  ///
  /// 기기 배율을 곱해 화면에서 흐려지지 않는 최소 크기로 잡는다. 폭이
  /// 정해지지 않은 자리(무한 제약)는 화면 폭 기준이다.
  static int decodeWidthFor(BuildContext context, double logicalWidth) {
    final media = MediaQuery.of(context);
    final width = logicalWidth.isFinite ? logicalWidth : media.size.width;
    return (width * media.devicePixelRatio).ceil();
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
