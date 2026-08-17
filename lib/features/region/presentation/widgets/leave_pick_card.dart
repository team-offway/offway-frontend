import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens/tokens.dart';

/// 홈 '이번 연차엔 여기 어때요?' 카드 — 사진 한 장에 지역명만 얹는다.
///
/// 같은 화면의 [RegionCard]와 달리 설명·혜택 뱃지가 없다. 위에서 이미 조건을
/// 붙여 고른 목록이라, 여기서는 "어디"만 보여주고 고르게 하는 자리다.
/// 그래서 글자를 **아래쪽**에 두고 그 뒤로만 어둡게 깐다.
class LeavePickCard extends StatelessWidget {
  const LeavePickCard({super.key, required this.region});

  final Map<String, dynamic> region;

  /// 시안 실측 — 190×220, 반경 12
  static const width = 190.0;
  static const height = 220.0;

  @override
  Widget build(BuildContext context) {
    final imageUrl = region['imageUrl'] as String?;
    final id = region['id']?.toString();

    return GestureDetector(
      onTap: id == null
          ? null
          : () => context.push(AppRoutes.regionDetailPath(id)),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: AppColors.backgroundNormalAlternative,
                child: imageUrl == null
                    ? null
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.expand(),
                      ),
              ),
              // 사진이 밝아도 글자가 읽히게 아래쪽만 어둡게 깐다.
              // 위가 아니라 아래인 건 글자가 아래에 놓이기 때문
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
                  child: Text(
                    _label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body2NormalBold.copyWith(
                      color: AppColors.staticWhite,
                      shadows: const [
                        Shadow(blurRadius: 12, color: Color(0x29000000)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 서버는 name에 '동구 · 부산광역시'까지 담아 준다. sido가 따로 오면 이어붙인다
  String get _label {
    final name = region['name'] as String? ?? '';
    final sido = region['sido'] as String?;
    if (sido == null || sido.isEmpty || name.contains(sido)) return name;
    return '$name · $sido';
  }
}

/// 로딩 중 [LeavePickCard] 자리에 놓는 회색 블록
class LeavePickCardSkeleton extends StatelessWidget {
  const LeavePickCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: LeavePickCard.width,
      height: LeavePickCard.height,
      decoration: BoxDecoration(
        color: AppColors.backgroundNormalAlternative,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
