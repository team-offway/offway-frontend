import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/policy_repository.dart';

/// 혜택 뱃지를 누르면 올라오는 정책 상세.
///
/// TODO(design): 전용 시안이 없어 DS 시트 패턴을 따랐다. 시안이 나오면 맞춘다.
Future<void> showPolicyDetailSheet(BuildContext context, int policyId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.backgroundElevated,
    barrierColor: AppColors.materialDimmer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    // 혜택 설명이 길면 시트가 넘친다 — 화면의 3/4까지만 쓰고 그 안에서 스크롤
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.75,
    ),
    builder: (_) => _PolicyDetailSheet(policyId: policyId),
  );
}

class _PolicyDetailSheet extends ConsumerWidget {
  const _PolicyDetailSheet({required this.policyId});

  final int policyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(policyDetailProvider(policyId));

    return SafeArea(
      child: policy.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: AppCircularLoading()),
        ),
        error: (e, _) => SizedBox(
          height: 200,
          child: Center(
            child: Text(
              e is ApiException ? e.detail : '혜택 정보를 불러오지 못했어요',
              style: AppTypography.label1NormalMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ),
        ),
        data: (data) => _buildBody(context, data),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> policy) {
    final period = policy['period'] as Map<String, dynamic>?;
    final applyUrl = policy['applyUrl'] as String?;
    final regions = ((policy['regions'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (policy['name'] as String?) ?? '혜택',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headline1Bold.copyWith(
                      color: AppColors.labelNormal,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: AppIconButton(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: '닫기',
                    color: AppColors.labelAlternative,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (policy['benefitDetail'] case final String detail)
            _Row(label: '혜택', value: detail),
          if (period != null)
            _Row(
              label: '기간',
              value: [
                '${period['start']} ~ ${period['end']}',
                if (policy['periodNote'] case final String note) note,
              ].join('\n'),
            ),
          if (policy['target'] case final String target)
            _Row(label: '대상', value: target),
          if (regions.isNotEmpty)
            _Row(
              label: '해당 지역',
              value: regions
                  .map((r) => (r['name'] as String?) ?? '')
                  .where((n) => n.isNotEmpty)
                  .join(', '),
            ),
          if (applyUrl != null && applyUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _openApplyUrl(context, applyUrl),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNormal,
                foregroundColor: AppColors.staticWhite,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('신청하러 가기', style: AppTypography.body1NormalBold),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openApplyUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppToast(context, '신청 페이지를 열지 못했어요');
    }
  }
}

/// 라벨 + 값 한 줄 — 장소 상세 기본정보와 같은 결
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: AppTypography.label1NormalBold.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTypography.label1NormalMedium.copyWith(
                color: AppColors.labelNeutral,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
