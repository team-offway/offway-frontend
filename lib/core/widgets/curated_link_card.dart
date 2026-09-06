import 'package:flutter/material.dart';

import '../theme/tokens/tokens.dart';
import '../utils/external_link.dart';
import 'curated_link_section.dart' show CuratedLink;
import 'info_card.dart';
import 'place_thumbnail.dart';

/// 홈 '연차 쓰기 전, 확인해보세요'의 서버 링크 카드 — 사진 위, 소개·제목·'웹사이트' 아래.
///
/// 같은 [CuratedLink]를 쓰지만 목록형([CuratedLinkSection])과 생김새가 다르다.
/// 그쪽은 화면 끝에 붙는 덤이라 한 줄씩 쌓지만, 여기는 홈에서 **보여 주려고
/// 내미는** 자리라 사진을 크게 깔고 가로로 넘긴다. 틀은 [InfoCard]다 —
/// 옆에 놓이는 황금연휴 카드와 같은 틀이라 한 줄로 읽힌다.
class CuratedLinkCard extends StatelessWidget {
  const CuratedLinkCard({super.key, required this.link});

  final CuratedLink link;

  static const width = InfoCard.width;
  static const height = InfoCard.height;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      // 사진은 시안대로 잘라 채운다(308×154를 가운데 맞춤). 서버가 아직
      // 사진을 안 준 링크는 회색 면만 둔다 — 시안이 자리 아이콘 없이 단색이다
      image: link.thumbnailUrl == null
          ? const ColoredBox(color: AppPalette.coolNeutral95)
          : PlaceThumbnail(
              imageUrl: link.thumbnailUrl,
              width: double.infinity,
              height: double.infinity,
              radius: 0,
              background: AppPalette.coolNeutral95,
              iconSize: 0,
            ),
      // 서버 소개문은 비어 올 수 있다 — 그때는 줄만 비운다(자리는 지킨다)
      description: link.description ?? '',
      title: link.title,
      buttonLabel: '웹사이트',
      buttonIconAsset: 'assets/icons/ic_link.svg',
      semanticsLabel: '${link.title} 웹사이트 열기',
      // 앱 안 브라우저로 연다. 못 열면 주의 토스트까지 openExternalLink가 맡는다
      onTap: () => openExternalLink(context, link.linkUrl),
    );
  }
}

/// 로딩 중 [CuratedLinkCard] 자리에 놓는 회색 블록
class CuratedLinkCardSkeleton extends StatelessWidget {
  const CuratedLinkCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: CuratedLinkCard.width,
    height: CuratedLinkCard.height,
    decoration: BoxDecoration(
      color: AppColors.fillAlternative,
      borderRadius: BorderRadius.circular(InfoCard.radius),
    ),
  );
}
