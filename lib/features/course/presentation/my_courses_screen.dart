import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/trip_constants.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_tab_pills.dart';
import '../../../core/widgets/place_thumbnail.dart';
import '../data/course_repository.dart';

/// 내 코스 목록 (`GET /courses?scope=`) — 정렬·범위는 서버가 맡는다.
/// 담기·삭제 후에는 invalidate로 다시 불러온다.
final savedCoursesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, scope) =>
          ref.watch(courseRepositoryProvider).savedCourseCards(scope: scope),
    );

/// 서브탭 — 서버 scope 값과 짝을 이룬다. 빈 상태 문구도 탭마다 다르다
enum _Scope {
  all('전체', 'ALL', '아직 담은 코스가 없어요'),
  upcoming('예정된 여행', 'UPCOMING', '예정된 여행이 없어요'),
  past('다녀온 여행', 'PAST', '다녀온 여행이 없어요');

  const _Scope(this.label, this.serverValue, this.emptyTitle);

  final String label;
  final String serverValue;
  final String emptyTitle;
}

/// 내 코스 — 담아둔 코스를 예정/다녀온 여행으로 나눠 보여준다
class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  _Scope _scope = _Scope.all;

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(savedCoursesProvider(_scope.serverValue));

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
              onSelect: (s) => setState(() => _scope = s),
            ),
            Expanded(
              child: courses.when(
                loading: () => _buildSkeleton(),
                error: (e, _) => Center(
                  child: Text(
                    e is ApiException ? e.detail : '코스를 불러오지 못했어요',
                    textAlign: TextAlign.center,
                    style: AppTypography.label1NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ),
                data: (cards) =>
                    cards.isEmpty ? _buildEmpty() : _buildList(cards),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppTabPills(
        current: AppTab.myCourse,
        onTap: (tab) {
          // 탭끼리는 형제 화면이므로 스택을 쌓지 않고 교체한다
          if (tab == AppTab.home) context.go(AppRoutes.home);
          if (tab == AppTab.my) context.go(AppRoutes.my);
        },
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
              onTap: () => context.push(AppRoutes.wizardDateGate),
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

/// 전체 · 예정된 여행 · 다녀온 여행 — 고른 탭에 검정 밑줄이 붙는다
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
          if (_badge(start, end) case final (String, Color) badge) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: badge.$2.withValues(alpha: AppOpacity.o8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge.$1,
                style: AppTypography.label2Bold.copyWith(color: badge.$2),
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
                : '${start.year}.${start.month}.${start.day} - ${end.month}.${end.day}',
            style: AppTypography.body2NormalMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ],
      ),
    );
  }

  /// 끝난 여행은 초록 '여행완료', 다가오는 여행은 파란 D-day. 날짜 없으면 없음
  (String, Color)? _badge(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    if (end.isBefore(today)) return ('여행완료', AppColors.statusPositive);
    final n = calendarDaysBetween(today, start);
    return (n > 0 ? 'D-$n' : 'D-DAY', AppColors.primaryNormal);
  }
}
