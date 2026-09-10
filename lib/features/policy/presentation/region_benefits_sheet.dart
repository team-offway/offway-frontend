import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../domain/region_benefit.dart';
import 'policy_detail_sheet.dart';

/// 혜택이 여럿인 지역의 뱃지(`… +1`)를 누르면 올라오는 **고르는 시트**.
///
/// 한 줄에 정책 하나 — 이름과 뱃지 문구. 누르면 이 시트를 닫고 그 정책의
/// 상세 시트([showPolicyDetailSheet])를 연다. 시트 위에 시트를 쌓지 않는다.
///
/// TODO(design): 전용 시안이 없어 DS 시트 패턴과 편집 시트의 행을 따랐다.
Future<void> showRegionBenefitsSheet(
  BuildContext context, {
  required String regionLabel,
  required List<RegionBenefit> benefits,
}) async {
  final picked = await showAppBottomSheet<RegionBenefit>(
    context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetTitleBar(title: '$regionLabel 혜택'),
          const SizedBox(height: 8),
          for (final benefit in benefits)
            _BenefitRow(
              benefit: benefit,
              onTap: () => Navigator.of(sheetContext).pop(benefit),
            ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
  final policyId = picked?.policyId;
  if (policyId == null || !context.mounted) return;
  await showPolicyDetailSheet(context, policyId);
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit, required this.onTap});

  final RegionBenefit benefit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 열 상세가 없는 혜택(옛 문자열 계약 · policyId 없음)은 누를 수 없다 —
    // 눌러서 시트만 닫히고 아무것도 안 열리는 행을 남기지 않는다
    final openable = benefit.policyId != null;
    return Semantics(
      button: openable,
      label: benefit.policyName ?? benefit.text,
      child: GestureDetector(
        onTap: openable ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 시안 실측: 좌우 24 · 행 높이 24 · 행 사이 24
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/icons/ic_link.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.labelAlternative,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                // 이름을 모르는 혜택(서버 대표 값)은 뱃지 문구가 이름이다
                child: Text(
                  benefit.policyName ?? benefit.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body1NormalMedium.copyWith(
                    color: AppColors.labelNeutral,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                'assets/icons/ic_chevron_right.svg',
                width: 12,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.labelAlternative,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
