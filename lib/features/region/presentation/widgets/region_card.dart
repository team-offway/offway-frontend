import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens/tokens.dart';

/// 지역 카드 표시 형태
enum RegionCardStyle {
  /// 홈 가로 리스트 — 폭 152 고정
  boxed,

  /// 목록 그리드 — 폭은 그리드가 결정
  plain,
}

/// 지역 카드 (홈 가로 리스트 · 추천 여행지 목록 공용).
/// DS Card 컴포넌트 기준: 4:3 썸네일(radius 12) + 제목 + 설명 + 회색 뱃지.
class RegionCard extends StatelessWidget {
  const RegionCard({
    super.key,
    required this.region,
    this.style = RegionCardStyle.boxed,
  });

  final Map<String, dynamic> region;
  final RegionCardStyle style;

  /// 텍스트·뱃지 영역의 기본 높이 (제목·설명 각 1줄 + 뱃지 + 간격)
  static const _textAreaHeight = 84.0;

  /// 그리드가 이 카드를 담을 때 필요한 셀 높이.
  /// 카드 구성이 바뀌면 이 공식만 고치면 되도록 카드 옆에 둔다.
  /// 텍스트는 시스템 글자 크기 배율을 따르므로 그 배율만큼 여유를 준다.
  static double mainAxisExtentFor(BuildContext context, double columnWidth) {
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return columnWidth * 3 / 4 + _textAreaHeight * textScale + 8;
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // DS Thumbnail: 4:3 고정비, radius 12, 헤어라인 보더
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lineNormalAlternative),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildImage(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${region['name']} · ${region['sido']}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body2NormalBold.copyWith(
            color: AppColors.labelNormal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          (region['description'] as String?) ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label2Medium.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
        if (region['benefitBadge'] case final String badge) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.fillNormal,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: AppTypography.caption2Medium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ),
        ],
      ],
    );

    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.regionDetailPath(region['id'] as String)),
      child: style == RegionCardStyle.boxed
          ? SizedBox(width: 152, child: content)
          : content,
    );
  }

  Widget _buildImage() {
    final imageUrl = region['imageUrl'] as String?;
    return Container(
      color: AppColors.backgroundNormalAlternative,
      child: imageUrl == null
          ? null
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    );
  }
}
