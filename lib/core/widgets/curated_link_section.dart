import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';
import '../utils/external_link.dart';
import 'place_thumbnail.dart';

/// 서버가 화면마다 내려주는 외부 링크 한 건 (core #350).
///
/// 홈·지역 상세·코스·장소 상세가 **같은 규격**으로 받는다. 어떤 링크를
/// 어디에 놓을지는 서버가 정하므로 앱은 목록을 그대로 그린다 — 앱에
/// 주소를 박아두면 기관 사이트가 바뀔 때마다 심사를 다시 받아야 한다.
///
/// [description]·[thumbnailUrl]은 **비어 올 수 있다**. 서버가 키를 지우지
/// 않기로 했으니 값만 보고 그 줄·그 자리를 접는다.
class CuratedLink {
  const CuratedLink({
    required this.title,
    required this.chipText,
    required this.linkUrl,
    this.description,
    this.thumbnailUrl,
  });

  /// 서버 응답 한 건(`{id, title, chipText, description, linkUrl, thumbnailUrl}`)에서 만든다.
  ///
  /// 제목이 비거나 **열 수 없는 주소**면 누를 데가 없는 줄이 되므로 버린다.
  /// 목록에 남겨 두고 누를 때 막으면, 눌러도 아무 일이 없는 카드가 된다.
  static CuratedLink? tryParse(Map<String, dynamic> json) {
    final title = (json['title'] as String?)?.trim() ?? '';
    // https가 아니거나 갈 곳이 없는 주소는 여기서 끊는다 — 서버도 저장할 때
    // 막지만(core #350), 웹뷰에 주소를 넘기는 것은 앱이다
    final linkUrl = safeExternalUri(json['linkUrl'] as String?)?.toString();
    if (title.isEmpty || linkUrl == null) return null;
    final description = (json['description'] as String?)?.trim();
    final thumbnailUrl = (json['thumbnailUrl'] as String?)?.trim();
    return CuratedLink(
      title: title,
      // 칩 글자가 비면 칩만 빈 알약으로 남는다 — 그때는 칩을 안 그린다
      chipText: (json['chipText'] as String?)?.trim() ?? '',
      linkUrl: linkUrl,
      description: (description?.isEmpty ?? true) ? null : description,
      thumbnailUrl: (thumbnailUrl?.isEmpty ?? true) ? null : thumbnailUrl,
    );
  }

  /// 응답의 `curatedLinks` 배열 → 그릴 수 있는 것만 남긴 목록.
  ///
  /// 키가 아예 없는 옛 서버 응답도 그냥 빈 목록이 된다 — 그러면 섹션째 접힌다.
  /// 배열이 아닌 값이 와도 마찬가지다. 링크는 화면에 덤으로 붙는 자리라,
  /// 이 값 하나 때문에 홈이나 코스가 통째로 못 뜨는 쪽이 훨씬 나쁘다
  static List<CuratedLink> parseList(Object? raw) => [
    if (raw is List)
      for (final item in raw)
        if (item is Map<String, dynamic>) ?tryParse(item),
  ];

  final String title;

  /// 무엇을 하러 가는 링크인지 — '기차표 예매'처럼 행동으로 온다
  final String chipText;
  final String linkUrl;
  final String? description;
  final String? thumbnailUrl;
}

/// 화면 끝에 붙는 '함께 보면 좋아요' — 서버가 고른 외부 링크 목록.
///
/// 링크는 앱 안(iOS SFSafariViewController)에서 연다. 주소가 상단에 그대로
/// 보여 어디로 가는지 알 수 있고, 닫으면 이 화면으로 돌아온다 — 여행 정보를
/// 하나 더 보려고 앱을 떠날 이유가 없다. 약관 화면과 같은 방식이다.
///
/// 링크가 없으면(서버가 안 주거나 빈 배열) **아무것도 그리지 않는다** —
/// 제목만 남은 빈 섹션이 화면 끝에 붙으면 고장난 것처럼 보인다.
class CuratedLinkSection extends StatelessWidget {
  const CuratedLinkSection({
    super.key,
    required this.links,
    this.title = '함께 보면 좋아요',
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<CuratedLink> links;

  /// 섹션 제목 — 화면마다 문구를 달리 하고 싶을 때 연다
  final String title;

  /// 화면마다 좌우 여백이 20·24로 갈려 열어 둔다
  final EdgeInsetsGeometry padding;

  /// 링크 사이 간격 — 카드가 서로 붙어 한 덩어리로 보이지 않을 만큼
  static const _rowGap = 10.0;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headline1Bold.copyWith(
              color: AppColors.labelNormal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '공식 사이트에서 더 자세히 확인해 보세요',
            style: AppTypography.label1NormalMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0) const SizedBox(height: _rowGap),
            _CuratedLinkTile(link: links[i]),
          ],
        ],
      ),
    );
  }
}

/// 링크 한 줄 — 썸네일(있을 때)·칩·제목·설명(있을 때)·바깥으로 나감 표시.
class _CuratedLinkTile extends StatelessWidget {
  const _CuratedLinkTile({required this.link});

  final CuratedLink link;

  /// 썸네일 한 변 — 두 줄(칩+제목) 높이에 맞춘 정사각
  static const _thumbnailSize = 52.0;

  @override
  Widget build(BuildContext context) {
    final description = link.description;

    return Semantics(
      button: true,
      link: true,
      label: '${link.title} 웹사이트 열기',
      // 카드 하나를 한 초점으로 묶는다. container를 빼면 칩·제목·설명이
      // 섹션 제목과 한 덩어리로 읽혀 "무엇을 누르는 것인지"가 흐려진다
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _open(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundNormalAlternative,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일은 대부분 비어 온다 — 없으면 자리째 접어 글이 왼쪽부터
              // 시작하게 둔다. 빈 회색 사각형을 늘 깔면 목록이 무거워진다
              if (link.thumbnailUrl != null) ...[
                PlaceThumbnail(
                  imageUrl: link.thumbnailUrl,
                  size: _thumbnailSize,
                  radius: 10,
                  background: AppColors.fillAlternative,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (link.chipText.isNotEmpty) ...[
                      _ActionChip(text: link.chipText),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      link.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body2NormalMedium.copyWith(
                        color: AppColors.labelStrong,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        // 서버 소개문은 한두 문장이다. 넘치면 줄이고,
                        // 카드가 화면을 다 먹지 않게 두 줄에서 끊는다
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label2Medium.copyWith(
                          color: AppColors.labelAlternative,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 앱 밖(웹)으로 나간다는 표시. 화면 안 이동에 쓰는 쉐브론과
              // 구분해 링크 아이콘을 쓴다
              Padding(
                // 칩 줄 가운데에 오도록 살짝 내린다
                padding: const EdgeInsets.only(top: 2),
                child: SvgPicture.asset(
                  'assets/icons/ic_link.svg',
                  width: 18,
                  height: 18,
                  excludeFromSemantics: true,
                  colorFilter: const ColorFilter.mode(
                    AppColors.labelAssistive,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 앱 안 브라우저로 연다. 못 열면 주의 토스트까지 [openExternalLink]가 맡는다
  Future<void> _open(BuildContext context) =>
      openExternalLink(context, link.linkUrl);
}

/// '기차표 예매'처럼 무엇을 하러 가는지 알리는 칩.
/// 지역 카드의 혜택 뱃지와 같은 브랜드색 8% 배경을 쓴다
class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryNormal.withValues(alpha: AppOpacity.o8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTypography.caption1Medium.copyWith(
          color: AppColors.primaryNormal,
        ),
      ),
    );
  }
}
