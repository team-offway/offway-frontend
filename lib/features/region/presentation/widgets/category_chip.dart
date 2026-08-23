import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 카테고리 키별 아이콘 — 구성·순서·라벨은 서버(filters)가 정하고 그림만 앱이 가진다
const categoryIcons = <String, String>{
  'ALL': 'assets/icons/ic_cat_all.svg',
  'SIGHT': 'assets/icons/ic_cat_sight.svg',
  'STAY': 'assets/icons/ic_cat_stay.svg',
  'EXPERIENCE': 'assets/icons/ic_cat_experience.svg',
  'FOOD': 'assets/icons/ic_cat_food.svg',
};

/// 서버 응답이 오기 전에도 칩 자리가 비지 않도록 쓰는 기본 구성
const defaultCategoryFilters = [
  {'key': 'ALL', 'label': '전체'},
  {'key': 'SIGHT', 'label': '관광지'},
  {'key': 'STAY', 'label': '숙박'},
  {'key': 'EXPERIENCE', 'label': '체험'},
  {'key': 'FOOD', 'label': '맛집'},
];

/// 카테고리 칩 — 홈과 추천 여행지 목록이 함께 쓴다.
/// 고르면 테두리와 라벨이 브랜드색으로 묶인다.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              // 고른 칩은 배경을 비우고 테두리로만 표시한다(시안). 회색을
              // 깔면 안 고른 칩과 바탕이 같아 무엇이 켜졌는지 흐려진다
              color: selected
                  ? AppColors.backgroundNormal
                  : AppColors.backgroundNormalAlternative,
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: AppColors.primaryNormal, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(iconAsset, width: 29, height: 29),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style:
                (selected
                        ? AppTypography.caption2Bold
                        : AppTypography.caption2Regular)
                    .copyWith(
                      // 고른 칩은 테두리와 같은 브랜드색으로 묶어 보여준다
                      color: selected
                          ? AppColors.primaryNormal
                          : AppColors.labelAlternative,
                    ),
          ),
        ],
      ),
    );
  }
}
