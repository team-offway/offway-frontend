import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/trip_constants.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/place_thumbnail.dart';
import '../../course_wizard/presentation/wizard_entry.dart';
import '../application/course_providers.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/async_retry.dart';

/// 서브탭 — 서버 scope 값과 짝을 이룬다. 빈 상태 문구도 탭마다 다르다
enum _Scope {
  all('전체', 'ALL', '아직 담은 코스가 없어요'),
  upcoming('예정된 여행', 'UPCOMING', '예정된 여행이 없어요'),
  past('지난 여행', 'PAST', '지난 여행이 없어요');

  const _Scope(this.label, this.serverValue, this.emptyTitle);

  final String label;
  final String serverValue;
  final String emptyTitle;
}

/// 내 코스 — 담아둔 코스를 예정/지난 여행으로 나눠 보여준다
class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  _Scope _scope = _Scope.all;

  @override
  void initState() {
    super.initState();
    // 탭에 들어올 때마다 보고 있는 칩을 새로 받는다 — 다른 기기에서 담거나
    // 지운 것이 보이게.
    // **옛 목록은 보이는 채로** 받는다(기본 invalidate 는 이전 값을 들고
    // 있다) — 스켈레톤이 뜨지 않는다. 그리는 도중에는 바꿀 수 없어 첫 프레임
    // 뒤에 한다
    //
    // **이미 받는 중이면 건드리지 않는다.** 계정이 바뀐 직후(로그인·로그아웃은
    // `asReload` 로 비운다)에 여기서 또 무효화하면 '옛 값을 보이는 새로고침'
    // 이 되어, 앞사람의 목록이 다시 보인다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(_scope);
    });
  }

  /// 보고 있는 칩의 목록만 새로 받는다 — 옛 목록을 보이는 채로.
  ///
  /// **family 전체를 무효화하지 않는다.** 예정 목록(UPCOMING)은 잠금화면
  /// 컨트롤러가 구독하고 있어, 그것까지 다시 받으면 탭에 들어올 때마다
  /// 잠금화면·위젯 맞추기가 한 번씩 돌았다. 예정 목록은 그 칩을 볼 때만
  /// 새로 받는다(앱 복귀 때는 컨트롤러가 따로 받는다)
  ///
  /// **오류 상태인 칩은 건드리지 않는다** — 오류 화면의 '다시 시도' 에 맡긴다.
  /// 여기서 다시 받다 또 실패하면, 누르지도 않은 '다시 시도' 의 실패로 보고
  /// "아직 불러올 수 없어요" 토스트가 떴다
  void _refresh(_Scope scope) {
    final provider = savedCoursesProvider(scope.serverValue);
    final state = ref.read(provider);
    if (state.isLoading || state.hasError) return;
    ref.invalidate(provider);
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(savedCoursesProvider(_scope.serverValue));
    // 다시 시도가 또 실패하면 알린다
    ref.listen(
      savedCoursesProvider(_scope.serverValue),
      retryFailureToast(context),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                '내 코스',
                style: AppTypography.title3Bold.copyWith(
                  color: AppColors.labelStrong,
                ),
              ),
            ),
            _ScopeTabs(
              scope: _scope,
              onSelect: (s) {
                setState(() => _scope = s);
                // 한동안 안 본 칩이면 받아 둔 목록이 오래됐을 수 있다
                _refresh(s);
              },
            ),
            Expanded(
              child: courses.whenRetryable(
                loading: () => _buildSkeleton(),
                error: (e, _) => AppErrorView(
                  description: e is ApiException ? e.detail : '코스를 불러오지 못했어요',
                  onRetry: () =>
                      ref.invalidate(savedCoursesProvider(_scope.serverValue)),
                ),
                data: (cards) =>
                    cards.isEmpty ? _buildEmpty() : _buildList(cards),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> cards) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        for (final card in cards) ...[
          _CourseCard(course: card),
          const SizedBox(height: 28),
        ],
      ],
    );
  }

  /// 불러오는 동안 카드 두 장 자리를 미리 그려둔다 (DS Skeleton 스펙)
  Widget _buildSkeleton() {
    Widget block(
      double? width,
      double height, {
      double radius = 3,
      Color color = AppColors.fillNormal,
    }) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < 2; i++) ...[
          // 썸네일 자리는 더 옅게, 글줄 자리는 살짝 진하게 — 디자인 그대로
          block(
            double.infinity,
            198,
            radius: 12,
            color: AppColors.fillAlternative,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(48, 20, color: AppColors.fillAlternative),
                const SizedBox(height: 6),
                block(double.infinity, 20),
                const SizedBox(height: 4),
                FractionallySizedBox(widthFactor: 0.75, child: block(null, 14)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 120),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 말풍선이 지도책 위에 살짝 겹쳐 얹힌다
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icons/ic_empty_course_bubble.svg',
                  width: 29,
                  height: 29,
                ),
                Transform.translate(
                  offset: const Offset(0, -3),
                  child: SvgPicture.asset(
                    'assets/icons/ic_empty_course_map.svg',
                    width: 48,
                    height: 48,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _scope.emptyTitle,
              style: AppTypography.heading2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '새로운 코스를 담아보세요',
              style: AppTypography.body1NormalMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              // 지난번 고르다 만 값을 비우고 처음부터
              onTap: () => startCourseWizard(context, ref),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.coolNeutral20,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '코스 추천받기',
                  style: AppTypography.body2NormalMedium.copyWith(
                    color: AppColors.inverseLabel,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 전체 · 예정된 여행 · 지난 여행 — 고른 탭에 검정 밑줄이 붙는다
class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({required this.scope, required this.onSelect});

  final _Scope scope;
  final ValueChanged<_Scope> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.lineNormalAlternative),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final s in _Scope.values) ...[
            if (s != _Scope.values.first) const SizedBox(width: 24),
            GestureDetector(
              onTap: () => onSelect(s),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: scope == s
                          ? AppColors.labelStrong
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  s.label,
                  style: AppTypography.headline2Bold.copyWith(
                    color: scope == s
                        ? AppColors.labelStrong
                        : AppColors.labelAssistive,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 코스 카드 — 썸네일 + 상태 뱃지 + 지역·기간 + 날짜
class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Map<String, dynamic> course;

  @override
  Widget build(BuildContext context) {
    final regionName = course['regionName'] as String? ?? '';
    final duration = ((course['durationLabel'] as String?) ?? '').replaceAll(
      ' ',
      '',
    );
    final imageUrl = course['thumbnailUrl'] as String?;
    final start = DateTime.tryParse(course['startDate'] as String? ?? '');
    final end = DateTime.tryParse(course['endDate'] as String? ?? '');

    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.savedCoursePath(course['id'] as String)),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlaceThumbnail(
            imageUrl: imageUrl,
            width: double.infinity,
            height: 198,
            background: AppColors.fillNormal,
            iconSize: 48,
          ),
          const SizedBox(height: 12),
          if (_badge(
                start,
                end,
                visited: course['leaveDeducted'] as bool? ?? false,
              )
              case final badge?) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: badge.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge.label,
                style: AppTypography.label2Bold.copyWith(color: badge.fg),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '$regionName · $duration',
            style: AppTypography.headline2Bold.copyWith(
              color: AppColors.labelNormal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            start == null || end == null
                ? '날짜 미정'
                : tripDateRangeLabel(start, end),
            style: AppTypography.body2NormalMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ],
      ),
    );
  }

  ({String label, Color fg, Color bg})? _badge(
    DateTime? start,
    DateTime? end, {
    required bool visited,
  }) => courseCardBadge(
    start,
    end,
    visited: visited,
    today: DateUtils.dateOnly(DateTime.now()),
  );
}

/// 내 코스 카드의 상태 뱃지. 다가오는 여행은 파란 D-day, 날짜 없으면 없음.
///
/// 끝난 여행은 날짜만으로 '여행완료'라 부르지 않는다 — **모달에서
/// 다녀왔다고 답해 연차가 차감된 여행만**([visited]) 초록 '여행완료'고,
/// 아직 답하지 않았거나(모달 무시) 안 갔다고 한 여행은 '미방문'이다.
/// 미방문 코스라도 날짜를 미래로 옮기면 이 분기가 다시 D-day를 낸다.
///
/// 미방문만 배경이 글자색 8%가 아니다 — 시안(1207-39864)이 글자
/// Label/Alternative에 배경 Fill/Normal(#70737C 8%)을 쓴다.
({String label, Color fg, Color bg})? courseCardBadge(
  DateTime? start,
  DateTime? end, {
  required bool visited,
  required DateTime today,
}) {
  if (start == null || end == null) return null;
  // 날짜만 견준다 — 시각이 섞이면 아래 [tripDDayLabel]과 판정이 갈린다
  if (DateUtils.dateOnly(end).isBefore(DateUtils.dateOnly(today))) {
    if (visited) {
      return (
        label: '여행완료',
        fg: AppColors.statusPositive,
        bg: AppColors.statusPositive.withValues(alpha: AppOpacity.o8),
      );
    }
    return (
      label: '미방문',
      fg: AppColors.labelAlternative,
      bg: AppColors.fillNormal,
    );
  }
  return (
    label: tripDDayLabel(start, end, today: today) ?? 'D-DAY',
    fg: AppColors.primaryNormal,
    bg: AppColors.primaryNormal.withValues(alpha: AppOpacity.o8),
  );
}

/// 다가오는·진행 중인 여행의 D-day 글자. 끝난 여행은 null.
///
/// 지난 여행인지는 **종료일**로 가른다 — 출발일로 가르면 2박3일의 둘째 날부터
/// 끝난 여행이 된다. 여행 중(출발일 ≤ 오늘 ≤ 종료일)은 'D-DAY'다.
/// 목록 카드·내 코스 상세·공유 코스가 같은 규칙을 쓴다.
String? tripDDayLabel(DateTime start, DateTime end, {required DateTime today}) {
  if (DateUtils.dateOnly(end).isBefore(DateUtils.dateOnly(today))) return null;
  final n = calendarDaysBetween(today, start);
  return n > 0 ? 'D-$n' : 'D-DAY';
}
