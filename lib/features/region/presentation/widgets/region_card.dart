import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

/// 지역 카드 표시 형태
enum RegionCardStyle {
  /// 홈 가로 리스트 — 회색 박스로 감싸고 폭 고정
  boxed,

  /// 목록 그리드 — 배경 없이 이미지만, 폭은 그리드가 결정
  plain,
}

/// 지역 카드 (홈 가로 리스트 · 추천 여행지 목록 공용)
// TODO(디자인시스템): 공통 컴포넌트 확정 시 이 위젯을 대체/이관
class RegionCard extends StatelessWidget {
  const RegionCard({
    super.key,
    required this.region,
    this.style = RegionCardStyle.boxed,
  });

  final Map<String, dynamic> region;
  final RegionCardStyle style;

  static const _labelNormal = Color(0xFF171719);
  static const _textMuted = Color(0xFF707070);
  static const _chipGray = Color(0xFFF2F3F6);
  static const _imagePlaceholder = Color(0xFFC5C8CE);
  static const _badgeBg = Color(0x293182F6); // rgba(49,130,246,0.16)
  static const _badgeText = Color(0xFF2272EB);

  @override
  Widget build(BuildContext context) {
    final boxed = style == RegionCardStyle.boxed;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(boxed ? 15 : 10),
          child: _buildImage(boxed ? 123 : 177),
        ),
        SizedBox(height: boxed ? 4 : 7),
        Text(
          '${region['name']} · ${region['sido']}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _labelNormal,
            letterSpacing: -0.6,
          ),
        ),
        Text(
          (region['description'] as String?) ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _textMuted,
            letterSpacing: -0.6,
          ),
        ),
        if (region['benefitBadge'] case final String badge) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _badgeBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _badgeText,
              ),
            ),
          ),
        ],
      ],
    );

    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.regionDetailPath(region['id'] as String)),
      child: boxed
          ? Container(
              width: 177,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _chipGray,
                borderRadius: BorderRadius.circular(20),
              ),
              child: content,
            )
          : content,
    );
  }

  Widget _buildImage(double height) {
    final imageUrl = region['imageUrl'] as String?;
    return Container(
      height: height,
      width: double.infinity,
      color: _imagePlaceholder,
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
