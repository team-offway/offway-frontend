import 'dart:ui' show ImageFilter;

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
                else ...[
                  // **배경** — 같은 사진을 꽉 채워 깔고 흐리게 만든다.
                  //
                  // 배너 원본은 가로가 세로의 두 배인데(261×131) 카드는 1.16이라
                  // 비율이 크게 어긋난다. 통째로 넣으면 위아래가 비는데, 그 자리를
                  // 회색으로 두면 큰 띠가 남는다 — 사진의 연장처럼 보이도록
                  // 흐린 같은 그림으로 메운다
                  ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: PlaceThumbnail(
                        imageUrl: link.thumbnailUrl,
                        width: double.infinity,
                        height: double.infinity,
                        radius: 0,
                        background: AppPalette.coolNeutral95,
                        // 자리 아이콘은 아래 본 그림이 그린다 — 여기서 또 그리면
                        // 흐려진 아이콘이 겹쳐 얼룩처럼 보인다
                        iconSize: 0,
                      ),
                    ),
                  ),
                  // **본 그림** — 잘라 채우지 않는다. 여기 오는 것은 장소 사진이
                  // 아니라 글씨가 들어간 홍보 배너다. 카드에 맞춰 자르면 가운데
                  // 글씨만 1.7배로 확대돼 무엇인지 못 읽는다
                  PlaceThumbnail(
                    imageUrl: link.thumbnailUrl,
                    width: double.infinity,
                    height: double.infinity,
                    radius: 0,
                    // 배경이 이미 깔려 있어 자리 색을 덮지 않는다
                    background: Colors.transparent,
                    iconSize: 48,
                    fit: BoxFit.contain,
                  ),
                ],
                // 사진이 밝아도 글자가 읽히게 아래쪽만 어둡게 깐다.
                //
                // 예전에는 글을 사진 위에 그대로 얹었다 — 서버가 사진을 안
                // 줘 배경이 늘 회색이던 시절의 판단이다. 실제 사진이 오기
                // 시작하자 밝은 사진 위에서 흰 글자가 묻혔다.
                //
                // 값은 나란히 놓이는 `LeavePickCard`와 같게 맞춘다 — 한 화면에
                // 두 줄로 붙는 카드라 어두워지는 정도가 다르면 결이 어긋난다
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.staticBlack.withValues(alpha: 0.8),
                          AppColors.staticBlack.withValues(alpha: 0),
                        ],
                      ),
                    ),
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
