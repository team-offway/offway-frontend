import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 홈 '연차 쓰기 전, 확인해보세요' 카드의 틀 — 그림 위, 글 아래.
///
/// 시안(18900:72039) 실측: 255×309, 배경 Background/Normal/Alternative,
/// 반경 14. 위 154는 그림 자리(위 모서리만 둥글고 아래로 카드색에 녹아든다),
/// 22 아래에 작은 버튼 · 제목 · 소개 두 줄이 16 안쪽에 쌓인다.
///
/// 무엇을 그리고 어디로 가는지는 쓰는 쪽이 정한다 — 서버 링크는 사진과
/// '웹사이트', 황금연휴는 일러스트와 '자세히'. 눌리는 건 카드 전체다.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.image,
    required this.description,
    required this.title,
    required this.buttonLabel,
    required this.buttonIconAsset,
    required this.semanticsLabel,
    required this.onTap,
    this.fadeImageBottom = true,
  });

  static const width = 255.0;
  static const height = 309.0;
  static const imageHeight = 154.0;
  static const radius = 14.0;

  /// 시안 실측 — 페이드 높이 30
  static const fadeHeight = 30.0;

  /// 곡선을 나누는 단계 — 0에서 1까지 열여섯 칸. 이보다 적으면 띠가 보인다
  static final _fadeSteps = [for (var i = 0; i <= 16; i++) i / 16];

  /// 위 154 자리를 채울 그림 — 카드 폭에 맞춰 잘린다
  final Widget image;
  final String description;
  final String title;

  /// 버튼 문구와 뒤에 붙는 아이콘 — '자세히' + 쉐브론, '웹사이트' + 링크
  final String buttonLabel;
  final String buttonIconAsset;
  final String semanticsLabel;
  final VoidCallback onTap;

  /// 그림 아랫단을 카드색으로 녹일지. 시안의 Gradient/Solid가 **그림에 이미
  /// 박혀 있는** 에셋(황금연휴 일러스트)은 끈다 — 겹치면 두 번 흐려진다
  final bool fadeImageBottom;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      container: true,
      // 하위 제스처의 접근성 정보를 지우므로 탭 동작은 여기서 다시 준다 —
      // 없으면 VoiceOver가 카드를 누를 수 없다
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: width,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.backgroundNormalAlternative,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    // 시안 Gradient/Solid — 그림 아랫단 30이 카드색으로 녹아든다.
                    // 사진과 캡션 사이에 선이 생기지 않게 한다.
                    //
                    // DS 개발 코멘트: "Gradient Ease: 0.25, 0.1, 0.25, 1". 직선으로
                    // 두면 위쪽이 급하게 어두워진다 — 그 베지어가 곧 [Curves.ease]라
                    // 곡선을 따라 잘게 나눈 색 단계로 그린다
                    if (fadeImageBottom)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: fadeHeight,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  for (final t in _fadeSteps)
                                    AppColors.backgroundNormalAlternative
                                        .withValues(
                                          alpha: Curves.ease.transform(t),
                                        ),
                                ],
                                stops: _fadeSteps,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 시안 순서: 버튼 → 제목 → 소개. 무엇을 하는 카드인지
                    // (자세히·웹사이트)를 먼저 읽히게 한다
                    _SmallButton(
                      label: buttonLabel,
                      iconAsset: buttonIconAsset,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body1NormalBold.copyWith(
                        color: AppColors.labelNeutral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 두 줄 자리를 늘 잡아 둔다 — 한 줄짜리 소개가 와도 카드
                    // 높이와 옆 카드의 줄이 흔들리지 않는다
                    SizedBox(
                      height: 32,
                      child: Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption1Medium.copyWith(
                          color: AppColors.labelNeutral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// DS Button(작은 것) — Fill/Normal 8% 배경, 반경 8, 안쪽 14×7, 글자 뒤 아이콘.
/// 카드 전체가 눌리므로 이 위젯은 모양만 맡는다
class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.iconAsset});

  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.fillNormal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.label2Medium.copyWith(
              color: AppColors.labelNeutral,
            ),
          ),
          const SizedBox(width: 4),
          SvgPicture.asset(
            iconAsset,
            width: 16,
            height: 16,
            excludeFromSemantics: true,
            colorFilter: const ColorFilter.mode(
              AppColors.labelNeutral,
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}
