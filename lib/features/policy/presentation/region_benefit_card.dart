import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/external_link.dart';
import '../data/policy_repository.dart';
import '../domain/region_benefit.dart';

/// 지역 상세의 **혜택 카드** (시안 18761:72093).
///
/// 뱃지 + 정책 이름 + 한 줄 설명, 오른쪽 위에 링크 아이콘. 누르면 신청
/// 페이지가 앱 안 브라우저로 열린다.
///
/// **이름과 설명은 정책 상세를 한 번 더 불러 받는다.** 지역 상세의 `benefit`은
/// 뱃지 문구(`text`)와 `policyId`만 주는데, 카드에 그릴 이름(`name`)과
/// 설명(`benefitDetail`)이 거기 없다. 아직 안 온 동안에는 뱃지와 이름 자리를
/// 비워 두지 않고 뱃지만 먼저 그린다 — 이미 아는 값이라 기다릴 이유가 없다.
class RegionBenefitCard extends ConsumerWidget {
  const RegionBenefitCard({super.key, required this.benefit});

  final RegionBenefit benefit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyId = benefit.policyId;
    final policy = policyId == null
        ? null
        : ref.watch(policyDetailProvider(policyId)).value;

    // 신청 주소는 지역 상세에 실려 오는 값이 먼저다(core #418). 아직 안 적은
    // 정책이 있어 null일 수 있고, 그때는 정책 상세의 값으로 물러난다
    final applyUri = safeExternalUri(
      benefit.applyUrl ?? policy?['applyUrl'] as String?,
    );
    final name = policy?['name'] as String?;
    final detail = policy?['benefitDetail'] as String?;

    final card = Container(
      width: double.infinity,
      // 시안 실측 — 좌우 36/43은 카드 안쪽 여백이 아니라 그 안의 프레임까지
      // 합친 값이다. 카드 자체는 20.5·16으로 두고 글이 넘치게 둔다
      padding: const EdgeInsets.symmetric(horizontal: 20.5, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevatedAlternative,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Badge(text: benefit.text),
              const Spacer(),
              // 바깥으로 나간다는 표시. 갈 곳이 없으면 아이콘째 접는다 —
              // 눌러도 아무 일도 안 일어나는 자리를 남기지 않는다
              if (applyUri != null)
                SvgPicture.asset(
                  'assets/icons/ic_link.svg',
                  width: 24,
                  height: 24,
                  excludeFromSemantics: true,
                  colorFilter: const ColorFilter.mode(
                    AppColors.labelAlternative,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
          // 시안 실측: 뱃지 줄 아래 4
          const SizedBox(height: 4),
          if (name != null) ...[
            Text(
              name,
              style: AppTypography.body1NormalMedium.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (detail != null)
            Text(
              detail,
              // 시안은 한 줄이지만 실제 문구가 길다(반값여행은 세 줄).
              // 두 줄에서 자른다 — 카드가 화면 절반을 먹으면 아래 안내가
              // 밀리고, 자세한 내용은 뱃지를 눌러 여는 시트가 정본이다
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label1NormalMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
        ],
      ),
    );

    if (applyUri == null) return card;
    return Semantics(
      button: true,
      link: true,
      label: '${name ?? benefit.text} 신청 페이지 열기',
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        // 앱 안 브라우저로 연다 — 혜택을 보다 사파리로 튕겨 나가면 보던
        // 지역이 무엇이었는지부터 다시 찾아야 한다. 정책 시트와 같은 방식이다
        onTap: () => openExternalLink(
          context,
          applyUri.toString(),
          failureMessage: '신청 페이지를 열지 못했어요',
        ),
        behavior: HitTestBehavior.opaque,
        child: card,
      ),
    );
  }
}

/// 혜택 뱃지 — 카드 안쪽이라 [BenefitBadge]보다 크다(시안 8·5, 반경 8)
class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryNormal.withValues(alpha: AppOpacity.o8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTypography.label2Medium.copyWith(
          color: AppColors.primaryNormal,
        ),
      ),
    );
  }
}
