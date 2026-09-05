import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../domain/region_visit_metrics.dart';

/// `화요일에 가장 한산해요` — 언제 가면 덜 붐비는지 (core #438 · 시안 18860:76644).
///
/// **여러 화면이 같은 컴포넌트로 그린다.** 시안이 "이 모달은 여러 화면에서
/// 동일하게 재사용됨"이라고 못박았고, 서버도 응답 조각을 하나로 두었다 —
/// 지역 상세·코스 확정·내 코스 상세가 이 위젯 하나를 쓴다.
///
/// 값이 없으면 **그 줄을 지운다.** 서버는 재료가 모자라면 지어내지 않고
/// 비운다(요일당 40일 미만·격차 10% 미만). 없는 숫자를 채워 보였다가 틀리면
/// 우리가 내리는 모든 숫자를 안 믿게 된다.
class QuietestDayBanner extends StatelessWidget {
  const QuietestDayBanner({super.key, required this.quietestDay});

  final QuietestDay? quietestDay;

  @override
  Widget build(BuildContext context) {
    final day = quietestDay;
    if (day == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      // 시안 실측 — 좌우 15, 위아래 15 (프레임 54 안에 24짜리 줄)
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevatedAlternative,
        borderRadius: BorderRadius.circular(14),
      ),
      // 줄 높이를 24로 못박는다 — i 버튼은 손가락 몫으로 44×44를 차지하는데,
      // 그대로 두면 카드가 시안(54)보다 20 높아진다. 탭 영역은 그대로 두고
      // 넘치는 만큼만 위아래로 흘려보낸다
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            // 시안이 쓰는 bulk 변형 — 기존 ic_clock은 회색 외곽선이라 다르다.
            // 에셋에 색이 박혀 있어 덮지 않는다
            SvgPicture.asset(
              'assets/icons/ic_clock_bulk.svg',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 6),
            Expanded(child: _headline(day)),
            // 이 숫자가 어디서 왔는지 묻는 자리 — 출처까지 여기서 밝힌다.
            // OverflowBox로 44 탭 영역을 24 줄 안에서 유지한다
            SizedBox(
              width: 24,
              child: OverflowBox(
                maxHeight: 44,
                maxWidth: 44,
                // 시안 Label/Assistive는 28%다. 에셋이 이미 61%를 품고
                // 있어 색으로는 못 맞추고, 여기서 한 번만 곱한다
                child: Opacity(
                  opacity: 0.28,
                  child: AppIconButton(
                    icon: Icons.info_outline,
                    // 시안은 속이 빈 원형 i — ic_circle_info는 속이 찬 변형이다
                    // (랜덤 지역 화면과 같은 에셋)
                    asset: 'assets/icons/ic_circle_info_outline.svg',
                    size: 24,
                    // 에셋은 Label/Alternative(61%)를 품고 있는데 이 시안은
                    // **Assistive(28%)** 다. 에셋을 고치면 같은 파일을 쓰는
                    // 랜덤 지역 화면까지 옅어져, 여기서만 덮는다.
                    //
                    // **알파를 1로 준다.** srcIn은 원본 알파를 남기므로
                    // 반투명 색을 씌우면 에셋의 61%에 다시 곱해져 17%가 된다
                    // (시안보다 훨씬 옅다). 투명도는 아래 Opacity가 정한다
                    tintAsset: true,
                    color: const Color(0xFF37383C),
                    onTap: () => showQuietestDaySheet(context, day),
                    semanticLabel: '한산한 요일 안내',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 요일만 브랜드색 — 시안이 '화요일'에만 색을 준다
  Widget _headline(QuietestDay day) {
    return Text.rich(
      TextSpan(
        style: AppTypography.body2NormalMedium.copyWith(
          color: AppColors.labelNormal,
        ),
        children: [
          TextSpan(
            text: day.label,
            style: const TextStyle(color: AppColors.primaryStrong),
          ),
          const TextSpan(text: '에 가장 한산해요'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// i를 누르면 올라오는 안내 — 숫자의 근거와 출처를 밝힌다.
///
/// **출처를 함께 적는다.** 관광빅데이터에서 온 값이고, 근거 없이 숫자만
/// 보이면 어디까지 믿을지 판단할 수 없다.
Future<void> showQuietestDaySheet(BuildContext context, QuietestDay day) {
  return showAppBottomSheet<void>(
    context,
    builder: (sheetContext) => Padding(
      // 시안 실측 — 좌우 23, 위아래 28
      padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/ic_clock_bulk.svg',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          style: AppTypography.headline2Bold.copyWith(
                            color: AppColors.labelNormal,
                          ),
                          children: [
                            TextSpan(
                              text: day.label,
                              style: const TextStyle(
                                color: AppColors.primaryStrong,
                              ),
                            ),
                            const TextSpan(text: '에 가장 한산해요'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // 시안 실측: 제목 아래 12
                const SizedBox(height: 12),
                Text(
                  '최근 1년간 방문객 데이터를 보면,\n'
                  '${day.label} 방문객이 다른 요일보다 '
                  '약 ${day.percentLessThanOtherDays}% 적어요.',
                  style: AppTypography.label1NormalMedium.copyWith(
                    color: AppColors.labelAlternative,
                  ),
                ),
                // 시안 실측: 본문 아래 24
                const SizedBox(height: 24),
                Text(
                  '출처 · 관광빅데이터',
                  style: AppTypography.caption1Medium.copyWith(
                    color: AppColors.labelAssistive,
                  ),
                ),
              ],
            ),
          ),
          // 시안은 닫기를 제목 줄이 아니라 **시트 오른쪽 위**에 따로 둔다 —
          // 제목이 두 줄이 되어도 자리가 안 밀린다
          const SizedBox(width: 12),
          AppIconButton.close(onTap: () => Navigator.of(sheetContext).pop()),
        ],
      ),
    ),
  );
}
