import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/external_link.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../data/policy_repository.dart';

/// 혜택 뱃지를 누르면 올라오는 정책 상세.
///
/// TODO(design): 전용 시안이 없어 DS 시트 패턴을 따랐다. 시안이 나오면 맞춘다.
Future<void> showPolicyDetailSheet(BuildContext context, int policyId) {
  return showAppBottomSheet<void>(
    context,
    // 혜택 설명이 길면 시트가 넘친다 — 화면의 3/4까지만 쓰고 그 안에서 스크롤
    maxHeightRatio: 0.75,
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
    // https가 아니거나 갈 곳이 없는 주소면 버튼째 감춘다 — 눌러도 토스트만
    // 뜨는 버튼은 없느니만 못하다
    final applyUri = safeExternalUri(policy['applyUrl'] as String?);

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
                  child: AppIconButton.close(
                    onTap: () => Navigator.of(context).pop(),
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
          // '해당 지역'은 걷어냈다. 숙박세일 페스타는 85곳이 오는데
          // 이름이 "정선군 · 강원특별자치도" 꼴이라 한 줄로 이으면 시트가
          // 지역명으로만 가득 찬다. 뱃지를 누른 사람은 이미 그 지역을 보고
          // 있어 "여기가 되나"는 이미 답이 나와 있고, 전체 목록이 궁금하면
          // 신청 페이지가 정본이다
          if (applyUri != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _openApplyUrl(context, applyUri.toString()),
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

  /// 지자체 신청 페이지를 앱 안에서 띄운다.
  ///
  /// iOS는 SFSafariViewController로 열려 상단에 주소가 그대로 보이고, 닫으면
  /// 이 시트로 돌아온다 — 혜택을 확인하다 사파리로 튕겨 나가면 보던 정책이
  /// 무엇이었는지부터 다시 찾아야 한다. 약관·큐레이션 링크와 같은 방식이다.
  Future<void> _openApplyUrl(BuildContext context, String url) =>
      openExternalLink(context, url, failureMessage: '신청 페이지를 열지 못했어요');
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
