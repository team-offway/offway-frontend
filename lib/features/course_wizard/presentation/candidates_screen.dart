import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../mock/mock_data_source.dart';
import '../application/course_wizard_provider.dart';

/// 후보지역 mock (서버 연동 시 추천 API 응답으로 교체)
final wizardCandidatesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final data = await MockDataSource.regions();
  return (data['candidates'] as List).cast<Map<String, dynamic>>();
});

/// 후보지역 정렬 기준
enum CandidateSort {
  recommended('추천순'),
  travelTime('이동시간순');

  const CandidateSort(this.label);

  final String label;
}

/// O-08 · 후보지역
class CandidatesScreen extends ConsumerStatefulWidget {
  const CandidatesScreen({super.key});

  @override
  ConsumerState<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends ConsumerState<CandidatesScreen> {
  CandidateSort _sort = CandidateSort.recommended;

  /// 추천순은 서버가 준 순서를 그대로 쓰고, 이동시간순만 다시 정렬한다
  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    if (_sort == CandidateSort.recommended) return list;
    final sorted = [...list];
    sorted.sort((a, b) {
      final x = a['travelMinutesByCar'] as int? ?? 1 << 30;
      final y = b['travelMinutesByCar'] as int? ?? 1 << 30;
      return x.compareTo(y);
    });
    return sorted;
  }

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<CandidateSort>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      barrierColor: AppColors.materialDimmer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final option in CandidateSort.values)
              ListTile(
                title: Text(
                  option.label,
                  style: AppTypography.body1NormalMedium.copyWith(
                    color: option == _sort
                        ? AppColors.primaryNormal
                        : AppColors.labelNormal,
                  ),
                ),
                trailing: option == _sort
                    ? const Icon(Icons.check, color: AppColors.primaryNormal)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(wizardCandidatesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // 버튼이 아이콘보다 넓으므로 좌측 여백을 줄여 아이콘 위치를 맞춘다
              padding: const EdgeInsets.fromLTRB(10, 0, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppIconButton(
                  icon: Icons.close,
                  onTap: () {
                    // 위저드 종료: 조건 초기화 후 홈으로
                    ref.read(courseWizardProvider.notifier).reset();
                    context.go(AppRoutes.home);
                  },
                  semanticLabel: '닫기',
                ),
              ),
            ),
            Expanded(
              child: candidates.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('후보지역을 불러오지 못했어요\n$e')),
                data: (all) {
                  if (all.isEmpty) return _buildEmpty();
                  final list = _sorted(all);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                    children: [
                      _buildHeadline(list.length),
                      const SizedBox(height: 8),
                      Text(
                        '지역을 눌러서 코스를 확인해보세요.',
                        style: AppTypography.body1NormalMedium.copyWith(
                          color: AppColors.labelAlternative,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _SortChip(label: _sort.label, onTap: _pickSort),
                      ),
                      const SizedBox(height: 12),
                      for (final region in list) ...[
                        _CandidateCard(region: region),
                        const SizedBox(height: 36),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 조건에 걸리는 지역이 하나도 없을 때.
  /// 헤드라인·정렬은 보여줄 게 없으니 걷어내고 다음에 뭘 하면 되는지만 남긴다.
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/ic_empty_result.svg',
              width: 48,
              height: 48,
            ),
            const SizedBox(height: 32),
            Text(
              '조건에 맞는 여행지가 없어요',
              textAlign: TextAlign.center,
              style: AppTypography.title3Bold.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '이동수단이나 여행 기간을 변경하면\n새로운 여행지를 찾을 수 있어요.',
              textAlign: TextAlign.center,
              style: AppTypography.body1NormalMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 150,
              child: FilledButton(
                // TODO(wizard): 어느 단계로 되돌릴지 정해지면 연결한다.
                // 그때까지는 비활성 — 눌리는데 아무 일도 없으면 고장으로 보인다
                onPressed: null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.fillNormal,
                  foregroundColor: AppColors.labelNormal,
                  disabledBackgroundColor: AppColors.interactionDisable,
                  disabledForegroundColor: AppColors.labelAssistive,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('다시 설정하기', style: AppTypography.body1NormalBold),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                ref.read(courseWizardProvider.notifier).reset();
                context.go(AppRoutes.home);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '홈으로 돌아가기',
                  style: AppTypography.label1NormalMedium.copyWith(
                    color: AppColors.labelAlternative,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "조건에 맞는 여행지 N곳을 찾았어요" — 개수만 브랜드색으로 강조한다
  Widget _buildHeadline(int count) {
    final base = AppTypography.title3Bold.copyWith(
      color: AppColors.labelNormal,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: '조건에 맞는 여행지\n'),
          TextSpan(
            text: '$count곳',
            style: base.copyWith(color: AppColors.primaryNormal),
          ),
          const TextSpan(text: '을 찾았어요'),
        ],
      ),
    );
  }
}

/// 정렬 기준을 고르는 칩
class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.fillAlternative,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.label2Medium.copyWith(
                color: AppColors.labelNormal,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: AppColors.labelAlternative,
            ),
          ],
        ),
      ),
    );
  }
}

/// 후보 지역 카드 — 16:9 썸네일 + 뱃지 + 지역명 + 설명
class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({required this.region});

  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = region['imageUrl'] as String?;
    final badge = region['badge'] as String?;

    return GestureDetector(
      onTap: () {
        final desiredDays = ref.read(courseWizardProvider).desiredTripDays;
        context.push(
          AppRoutes.coursePath(
            region['id'] as String,
            desiredDays: desiredDays,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundNormalAlternative,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lineNormalAlternative),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl == null
                  ? null
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (badge != null) ...[
            _AccentBadge(label: badge),
            const SizedBox(height: 6),
          ],
          Text(
            '${region['name']} · ${region['sido']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body1NormalBold.copyWith(
              color: AppColors.labelNormal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (region['description'] as String?) ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label2Medium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ],
      ),
    );
  }
}

/// 지역 성격을 한 단어로 짚는 뱃지 (예: 인기)
class _AccentBadge extends StatelessWidget {
  const _AccentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.fillAlternative,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.caption1Medium.copyWith(
          color: AppAccentColors.foregroundCyan,
        ),
      ),
    );
  }
}
