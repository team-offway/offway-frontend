import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';
import '../utils/external_link.dart';
import 'curated_link_section.dart' show CuratedLink;
import 'place_thumbnail.dart';

/// 홈 '지금 유용한 혜택과 정보' 카드 — 사진 한 장 위에 소개와 제목을 얹는다.
///
/// 같은 [CuratedLink]를 쓰지만 목록형([CuratedLinkSection])과 생김새가 다르다.
/// 그쪽은 화면 끝에 붙는 덤이라 한 줄씩 쌓지만, 여기는 홈에서 **보여 주려고
/// 내미는** 자리라 사진을 크게 깔고 가로로 넘긴다.
///
/// 같은 화면의 `LeavePickCard`와 형태가 같다 — 220 높이, 반경 12, 아래쪽만
/// 어둡게. 나란히 놓이는 두 줄이라 결이 어긋나면 남의 화면처럼 보인다.
class CuratedLinkCard extends StatelessWidget {
  const CuratedLinkCard({super.key, required this.link});

  final CuratedLink link;

  /// 시안 실측 — 255×220, 반경 12
  static const width = 255.0;
  static const height = 220.0;

  @override
  Widget build(BuildContext context) {
    final description = link.description;

    return Semantics(
      button: true,
      link: true,
      label: '${link.title} 웹사이트 열기',
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        // 앱 안 브라우저로 연다. 못 열면 주의 토스트까지 openExternalLink가 맡는다
        onTap: () => openExternalLink(context, link.linkUrl),
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          // 사진처럼 대비가 큰 가장자리는 기본 antiAlias 로 자르면
          // 모서리에 계단이 비친다
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 서버가 아직 사진을 안 준다. 그동안은 **회색 면만** 둔다 —
                // 시안이 자리 아이콘 없이 단색으로 그렸다. 흰 글자가 그 위에
                // 바로 얹히는 구조라, 아이콘까지 깔면 글과 겹쳐 지저분해진다
                if (link.thumbnailUrl == null)
                  const ColoredBox(color: AppPalette.coolNeutral95)
                else
                  PlaceThumbnail(
                    imageUrl: link.thumbnailUrl,
                    width: double.infinity,
                    height: double.infinity,
                    radius: 0,
                    // 주소가 죽어 있을 때도 같은 회색으로 되돌아간다
                    background: AppPalette.coolNeutral95,
                    iconSize: 48,
                  ),
                // 글은 사진 위에 그대로 얹는다 — 시안은 어둡게 까는 층을
                // 두지 않는다. 사진이 밝으면 읽기 어려워질 수 있으나,
                // 어떤 사진을 쓸지는 아직 정해지지 않았다
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 바깥으로 나간다는 표시. 글 위에 둬 무엇을 누르는
                      // 카드인지 먼저 읽히게 한다
                      const _LinkBadge(),
                      const SizedBox(height: 9),
                      Text(
                        link.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headline2Bold.copyWith(
                          color: AppColors.staticWhite,
                        ),
                      ),
                      // 서버 소개문은 비어 올 수 있다 — 그때는 제목만 남는다
                      if (description != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption1Medium.copyWith(
                            color: AppColors.staticWhite,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 사진 위에 놓는 링크 아이콘 — 테두리만 있는 둥근 버튼 (DS Button/Icon/Outlined)
class _LinkBadge extends StatelessWidget {
  const _LinkBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 사진 위라 채우지 않는다 — 테두리만으로 눌리는 것임을 알린다
        border: Border.all(color: AppColors.lineNormalNeutral),
      ),
      child: SvgPicture.asset(
        'assets/icons/ic_link.svg',
        width: 18,
        height: 18,
        // 시안 실측 #171719 — 글자와 달리 아이콘은 어둡다.
        // 에셋 원본색이 그 값이라 덮지 않는다
        excludeFromSemantics: true,
      ),
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
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
