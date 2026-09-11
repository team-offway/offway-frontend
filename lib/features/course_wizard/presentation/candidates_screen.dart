import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/trip_constants.dart';
import '../../../core/location/origin_locator.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/widgets/data_source_note.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/place_thumbnail.dart';
import '../../policy/domain/region_benefit.dart';
import '../../region/domain/region_visit_metrics.dart';
import '../../policy/presentation/benefit_badge.dart';
import '../../policy/presentation/policy_detail_sheet.dart';
import '../../region/presentation/widgets/rising_chip.dart';
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
final wizardRecommendProvider =
    FutureProvider.autoDispose<
      ({List<Map<String, dynamic>> regions, List<DataSource> sources})
    >((ref) async {
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

/// 후보 지역 카드들. 화면 넷이 이 목록만 보므로 출처와 갈라 둔다 —
/// 함께 묶으면 지역만 필요한 랜덤 지역 화면까지 레코드를 풀어야 한다
final wizardCandidatesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) async => (await ref.watch(wizardRecommendProvider.future)).regions,
    );

/// 후보 지역 응답이 빌려 쓴 공공데이터 (core #417)
final wizardSourcesProvider = FutureProvider.autoDispose<List<DataSource>>(
  (ref) async => (await ref.watch(wizardRecommendProvider.future)).sources,
);

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
                      // 시안: 부제 아래 22 → 랜덤 카드 → 10 → 정렬 칩
                      const SizedBox(height: 22),
                      _RandomEntryCard(
                        onTap: () => context.push(AppRoutes.wizardRandom),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _SortChip(label: _sort.label, onTap: _pickSort),
                      ),
                      const SizedBox(height: 12),
                      for (final region in list) ...[
                        _CandidateCard(region: region),
                        const SizedBox(height: 36),
                      ],
                      // 공공데이터 출처 (core #417) — 목록 끝에 텍스트 한 줄
                      DataSourceNote(
                        sources:
                            ref.watch(wizardSourcesProvider).value ??
                            const <DataSource>[],
                        padding: EdgeInsets.zero,
                      ),
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

/// "어디로 갈지 고민된다면? 핀을 던져 여행지를 정해보세요" — 랜덤 지역 선택 진입.
///
/// 시안: light blue 95 바탕, 반경 14, 안쪽 16. 왼쪽 36 흰 상자에 GPS 아이콘,
/// 오른쪽 끝에 쉐브론.
class _RandomEntryCard extends StatelessWidget {
  const _RandomEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '핀을 던져 여행지를 정해보세요',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.lightBlue95,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.backgroundNormal,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SvgPicture.asset(
                  'assets/icons/ic_gps_bulk.svg',
                  width: 24,
                  height: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '어디로 갈지 고민된다면?',
                      style: AppTypography.body1NormalMedium.copyWith(
                        color: AppColors.labelNormal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '핀을 던져 여행지를 정해보세요',
                      style: AppTypography.label2Medium.copyWith(
                        color: AppColors.labelNeutral,
                      ),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                'assets/icons/ic_chevron_right.svg',
                width: 24,
                height: 24,
              ),
            ],
          ),
        ),
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

/// 후보 지역 카드 — 16:9 썸네일 + 혜택 뱃지 + 지역명 + 설명
class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({required this.region});

  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = region['imageUrl'] as String?;
    // 추천 응답은 혜택을 목록으로 준다 — 대표가 맨 앞. 옛 값(`benefit`)만
    // 있어도 그린다
    final served = RegionBenefit.parseList(region['benefits']);
    final benefit =
        served.firstOrNull ?? RegionBenefit.tryParse(region['benefit']);
    // 목록이 안 오는 옛 서버에서는 대표 하나가 곧 전부다
    final benefits = served.isNotEmpty ? served : [?benefit];
    // 리포지토리가 파싱해 넘기지만, 캐스팅으로 두면 모양이 다를 때 카드가
    // 통째로 죽는다 — 지표는 덤이라 그렇게까지 할 값이 아니다
    final metrics = region['visitMetrics'];
    final trend = metrics is RegionVisitMetrics ? metrics.trend : null;

    return GestureDetector(
      onTap: () {
        final desiredDays = ref.read(courseWizardProvider).desiredTripDays;
        context.push(
          AppRoutes.coursePath(
            region['id'] as String,
            desiredDays: desiredDays,
            // 코스가 오기 전 로딩 문구에 지역 이름을 쓴다
            regionName: region['name'] as String?,
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
          // 혜택 칩과 인기 상승 칩이 나란히 놓인다(시안) — 둘 다 없으면
          // 줄째 사라져 사진과 지역명이 붙는다.
          //
          // **여기서는 혜택을 전부 편다**(QA 9/9). 홈은 카드가 좁아 `+2`로
          // 접지만 이 화면은 카드가 넓어 줄바꿈으로 다 보인다.
          //
          // 한 줄에 최대 셋까지만 둔다(시안) — `Wrap`은 폭이 남으면 넷도
          // 밀어 넣는데, 시안은 줄당 셋을 넘지 않는다
          if (benefit != null || trend?.rising == true) ...[
            _ChipRows(
              chips: [
                for (final b in benefits)
                  BenefitBadge(
                    benefit: b,
                    size: BenefitBadgeSize.candidate,
                    leadingIcon: true,
                    // 칩 하나가 곧 혜택 하나다 — 고르는 시트를 거치지 않고
                    // 그 혜택 상세를 바로 연다
                    onTap: b.policyId == null
                        ? null
                        : () => showPolicyDetailSheet(context, b.policyId!),
                  ),
                if (trend?.rising == true)
                  const RisingChip(size: BenefitBadgeSize.candidate),
              ],
            ),
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

/// 칩을 놓되 **한 줄에 셋을 넘기지 않는다**.
///
/// 폭이 남으면 `Wrap`이 알아서 접어 주고(시안은 칩이 길어 2+2로 떨어진다),
/// 칩이 짧아 넷이 들어갈 때만 이 규칙이 개입해 셋에서 끊는다.
/// `Wrap`에 그런 옵션이 없어, 줄을 직접 재어 셋째 뒤에 줄바꿈을 끼운다.
class _ChipRows extends StatelessWidget {
  const _ChipRows({required this.chips});

  final List<Widget> chips;

  /// 한 줄에 놓을 수 있는 칩 수 (시안)
  static const _perRow = 3;

  /// 칩 사이·줄 사이 간격 (시안)
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    return _MaxPerRowWrap(
      spacing: _gap,
      runSpacing: _gap,
      maxPerRow: _perRow,
      children: chips,
    );
  }
}

/// 폭이 모자랄 때뿐 아니라 **줄당 개수가 찼을 때도** 줄을 바꾸는 `Wrap`.
///
/// `Wrap`을 그대로 두면 폭이 남는 만큼 넷째까지 밀어 넣는다. 여기서는
/// 자식 수를 같이 세어, 둘 중 먼저 걸리는 쪽에서 줄을 바꾼다.
class _MaxPerRowWrap extends MultiChildRenderObjectWidget {
  const _MaxPerRowWrap({
    required this.spacing,
    required this.runSpacing,
    required this.maxPerRow,
    required super.children,
  });

  final double spacing;
  final double runSpacing;
  final int maxPerRow;

  @override
  _RenderMaxPerRowWrap createRenderObject(BuildContext context) {
    return _RenderMaxPerRowWrap(
      spacing: spacing,
      runSpacing: runSpacing,
      maxPerRow: maxPerRow,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMaxPerRowWrap renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..maxPerRow = maxPerRow;
  }
}

class _WrapParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMaxPerRowWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _WrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _WrapParentData> {
  _RenderMaxPerRowWrap({
    required double spacing,
    required double runSpacing,
    required int maxPerRow,
  }) : _spacing = spacing,
       _runSpacing = runSpacing,
       _maxPerRow = maxPerRow;

  double _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  int _maxPerRow;
  set maxPerRow(int value) {
    if (_maxPerRow == value) return;
    _maxPerRow = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _WrapParentData) {
      child.parentData = _WrapParentData();
    }
  }

  /// 줄을 나눠 놓고 크기를 낸다. [place]가 참이면 자식 위치도 적는다
  Size _run(BoxConstraints constraints, {required bool place}) {
    final maxWidth = constraints.maxWidth;
    var rowWidth = 0.0; // 지금 줄에 쌓인 폭(간격 포함)
    var rowHeight = 0.0;
    var rowCount = 0;
    var y = 0.0;
    var widest = 0.0;

    // 지금 줄을 닫고 다음 줄로 넘어간다
    void newRow() {
      widest = math.max(widest, rowWidth);
      y += rowHeight + _runSpacing;
      rowWidth = 0;
      rowHeight = 0;
      rowCount = 0;
    }

    var child = firstChild;
    while (child != null) {
      final size = place
          ? (child..layout(const BoxConstraints(), parentUsesSize: true)).size
          : child.getDryLayout(const BoxConstraints());
      final lead = rowCount == 0 ? 0.0 : _spacing;
      // 폭이 모자라거나 줄당 개수가 찼으면 줄을 바꾼다
      final overflows = rowCount > 0 && rowWidth + lead + size.width > maxWidth;
      if (overflows || rowCount >= _maxPerRow) newRow();

      if (place) {
        (child.parentData! as _WrapParentData).offset = Offset(
          rowCount == 0 ? 0 : rowWidth + _spacing,
          y,
        );
      }
      rowWidth += (rowCount == 0 ? 0 : _spacing) + size.width;
      rowHeight = math.max(rowHeight, size.height);
      rowCount += 1;
      child = (child.parentData! as _WrapParentData).nextSibling;
    }
    widest = math.max(widest, rowWidth);
    return Size(
      math.min(widest, maxWidth),
      firstChild == null ? 0 : y + rowHeight,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _run(constraints, place: false);

  @override
  void performLayout() {
    size = constraints.constrain(_run(constraints, place: true));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
