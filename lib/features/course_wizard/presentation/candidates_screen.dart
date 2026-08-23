import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/trip_constants.dart';
import '../../../core/location/origin_locator.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/place_thumbnail.dart';
import '../application/available_time_provider.dart';
import '../application/course_wizard_provider.dart';
import '../data/region_recommend_repository.dart';

/// 위저드 조건(이동수단·기간)과 현재 위치로 후보지역을 추천받는다.
///
/// 도달 한계는 가용시간 계산이 정한다 — 당일치기는 반나절 거리만, 2박3일은
/// 멀리까지. 계산에 실패하면 기본값(420분)으로 폴백해 추천은 계속된다.
///
/// 위치 권한은 이 시점에 처음 묻는다 — "여행지를 찾는 중"이라는 맥락이 있어야
/// 왜 위치가 필요한지 납득된다. 거부하면 서울 출발로 가정하고 계속 간다.
final wizardCandidatesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final transport = ref.watch(
        courseWizardProvider.select((draft) => draft.transportMode),
      );
      final availableTime = await ref.watch(availableTimeProvider.future);
      final origin = await ref.read(originLocatorProvider).resolve();
      return ref
          .read(regionRecommendRepositoryProvider)
          .recommend(
            origin: origin,
            transport: transport == TransportMode.publicTransit
                ? 'TRANSIT'
                : 'CAR',
            maxReachMinutes: availableTime?.maxReachMinutes ?? kMaxReachMinutes,
          );
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
      final x = a['reachMinutes'] as int? ?? 1 << 30;
      final y = b['reachMinutes'] as int? ?? 1 << 30;
      return x.compareTo(y);
    });
    return sorted;
  }

  Future<void> _pickSort() async {
    final picked = await showAppBottomSheet<CandidateSort>(
      context,
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
            // 시트 공통 규칙 — 아래 여백을 넉넉히 둔다
            const SizedBox(height: 24),
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
                child: AppIconButton.close(
                  onTap: () {
                    // 위저드 종료: 조건 초기화 후 홈으로
                    ref.read(courseWizardProvider.notifier).reset();
                    context.go(AppRoutes.home);
                  },
                ),
              ),
            ),
            Expanded(
              child: candidates.when(
                // O-07 로딩 화면에서 넘어온 직후라 같은 표시로 이어지게 한다
                loading: () =>
                    const AppLoadingView(title: '조건에 맞는\n여행지를 찾고 있어요..'),
                // 서버 detail이 사용자 문구라 그대로 보여준다. 그 외에는 원인을 감춘다
                error: (e, _) => Center(
                  child: Text(
                    e is ApiException ? e.detail : '후보지역을 불러오지 못했어요',
                    textAlign: TextAlign.center,
                    style: AppTypography.label1NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ),
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
                // 기간·날짜는 유지하고 이동수단(O-05)부터 다시 고른다.
                // 스택은 이동수단 → 밀도 → 후보지역이라 두 번 걷어낸다
                onPressed: () {
                  ref
                      .read(courseWizardProvider.notifier)
                      .restartFromTransport();
                  if (context.canPop()) context.pop();
                  if (context.canPop()) context.pop();
                },
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
        // DS Chip 규격 — 알약이 아니라 radius 10, 세로 패딩 7
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          // 5%(fill/alternative)는 흰 배경에서 배경이 없는 것처럼 보인다
          color: AppColors.fillNormal,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.body2NormalMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
            const SizedBox(width: 3),
            // DS Caret Down — Material 기본 삼각형(arrow_drop_down)은 더 크고
            // 뭉툭해 시안과 다르다. 에셋이 Label/Alternative를 품고 있다
            SvgPicture.asset(
              'assets/icons/ic_caret_down.svg',
              width: 14,
              height: 14,
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lineNormalAlternative),
              ),
              clipBehavior: Clip.antiAlias,
              // 사진이 없거나 죽어 있으면 시안처럼 자리 아이콘을 남긴다
              child: PlaceThumbnail(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                radius: 12,
                iconSize: 64,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        // DS 뱃지 규칙 — Accent/Background 토큰을 8%로 깐다 (무채색은 안 보인다)
        color: AppAccentColors.backgroundCyan.withValues(alpha: AppOpacity.o8),
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
