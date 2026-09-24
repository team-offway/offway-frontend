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
/// **이름과 설명은 이미 받아 둔 값을 쓴다.** 지역별 혜택 색인
/// ([RegionPolicyIndex])이 정책 상세를 모을 때 이름·설명을 함께 싣는다.
///
/// 색인을 거치지 않고 온 혜택(서버가 `benefits[]`를 직접 준 경우)만 이름이
/// 비는데, 그때만 정책 상세를 따로 부른다. 아직 안 온 동안에는 이름 자리를
/// 비워 두지 않고 뱃지만 먼저 그린다 — 이미 아는 값이라 기다릴 이유가 없다.
class RegionBenefitCard extends ConsumerWidget {
  const RegionBenefitCard({super.key, required this.benefit});

  final RegionBenefit benefit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyId = benefit.policyId;
    // **이름이 실려 왔으면 그것으로 끝이다.** 색인이 정책 상세에서 이름·설명·
    // 신청 주소를 모두 담아 오므로 같은 정책을 다시 부를 이유가 없다 —
    // 예전에는 카드마다 `GET /policies/{id}` 가 한 건씩 더 나갔다(#313)
    //
    // 이름이 안 실려 오는 곳(코스 확정의 서버 혜택 목록 등)은 **앱을 켤 때
    // 받아 둔 정책**을 먼저 쓴다 — 카드마다 서버를 부르면 이름·설명이 늦게
    // 떠 카드 높이가 한 번 뛴다. 받아 둔 게 없을 때만 서버에 묻는다
    final needsDetail = benefit.policyName == null && policyId != null;
    final known = needsDetail ? ref.watch(knownPolicyProvider(policyId)) : null;
    final policy = needsDetail && known == null
        ? ref.watch(policyDetailProvider(policyId)).value
        : known;

    // 신청 주소는 지역 상세에 실려 오는 값이 먼저다(core #418). 아직 안 적은
    // 정책이 있어 null일 수 있고, 그때는 정책 상세의 값으로 물러난다
    final applyUri = safeExternalUri(
      benefit.applyUrl ?? policy?['applyUrl'] as String?,
    );
    final name = benefit.policyName ?? policy?['name'] as String?;
    final detail = benefit.benefitDetail ?? policy?['benefitDetail'] as String?;

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
                  'assets/icons/ic_link_disable.svg',
                  width: 24,
                  height: 24,
                  excludeFromSemantics: true,
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

/// 혜택 뱃지 — 시안 실측 6·4, 반경 6, 12pt (58×24)
class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
