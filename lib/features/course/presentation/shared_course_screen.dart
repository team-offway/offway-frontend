import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../course_wizard/presentation/calendar_screen.dart'
    show tripConsumedLeaveProvider;
import '../data/course_repository.dart';
import 'widgets/course_day_tabs.dart';
import 'widgets/course_map.dart';

/// 공유 링크로 받은 코스 (`GET /public/courses/{shareToken}`)
final sharedCourseProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, shareToken) =>
          ref.watch(courseRepositoryProvider).sharedCourse(shareToken),
    );

/// 남이 공유한 코스 — 카카오톡 '앱으로 보기'로 들어온다.
///
/// 내 코스가 아니므로 편집·삭제·다시 공유는 없다. 대신 마음에 들면
/// 내 코스로 담을 수 있게 한다.
class SharedCourseScreen extends ConsumerStatefulWidget {
  const SharedCourseScreen({super.key, required this.shareToken, this.kind});

  final String shareToken;

  /// 'saved'면 내 코스 형태(날짜·연차 뱃지), 그 외에는 추천코스 형태.
  /// 웹 공유 페이지(/m, /r)와 같은 분기다.
  final String? kind;

  @override
  ConsumerState<SharedCourseScreen> createState() => _SharedCourseScreenState();
}

class _SharedCourseScreenState extends ConsumerState<SharedCourseScreen> {
  int _selectedDay = 1;

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(sharedCourseProvider(widget.shareToken));

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      // 히어로가 상태바까지 올라오도록 위쪽 SafeArea는 쓰지 않는다
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: course.when(
                loading: () => const AppCircularLoadingView(),
                error: (e, _) => AppErrorView(
                  description: switch (e) {
                    ApiException(status: 404) => '링크가 잘못되었거나 삭제된 코스예요',
                    ApiException(status: 410) => '만료된 링크예요',
                    ApiException(:final detail) when detail.isNotEmpty =>
                      detail,
                    _ => '잠시 후 다시 시도해 주세요',
                  },
                  onRetry: () =>
                      ref.invalidate(sharedCourseProvider(widget.shareToken)),
                ),
                data: _buildBody,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> course) {
    final days = (course['days'] as List).cast<Map<String, dynamic>>();
    final durationDays = course['durationDays'] as int;
    final day = days.firstWhere(
      (d) => d['day'] == _selectedDay,
      orElse: () => days.first,
    );
    final places = (day['places'] as List).cast<Map<String, dynamic>>();
    final regionName = _regionNameOf(days);

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // 웹 공유 페이지와 같은 히어로
        Image.asset(
          'assets/images/share_hero.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
        ),
        // 시안: 뒤로가기는 사진 위가 아니라 그 아래 줄에 놓인다
        Padding(
          padding: const EdgeInsets.only(left: 6, top: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppBackButton(
              // 링크로 바로 들어오면 되돌아갈 화면이 없다 — 홈으로 보낸다
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildTitle(regionName, durationDays),
              const SizedBox(height: 8),
              _buildSubtitle(days),
              if (_isSaved) _buildBadges(days),
              const SizedBox(height: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 198,
                  child: CourseMap(places: places, dayKey: _selectedDay),
                ),
              ),
            ],
          ),
        ),
        // 하루짜리 코스에는 고를 것이 없어 탭을 그리지 않는다
        if (durationDays > 1) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CourseDayTabs(
              durationDays: durationDays,
              selectedDay: _selectedDay,
              onSelect: (d) => setState(() => _selectedDay = d),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildDayHeader(day),
        ),
        const SizedBox(height: 12),
        for (final (i, place) in places.indexed)
          _SharedPlaceRow(order: i + 1, place: place),
        const SizedBox(height: 46),
        _buildFooter(),
      ],
    );
  }

  /// 'Day 1  7.26 월' — 날짜는 내 코스에서 공유된 경우에만 붙는다
  Widget _buildDayHeader(Map<String, dynamic> day) {
    final date = DateTime.tryParse(day['date'] as String? ?? '');
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      children: [
        Text(
          'Day ${day['day']}',
          style: AppTypography.headline2Bold.copyWith(
            color: AppColors.labelNormal,
          ),
        ),
        if (_isSaved && date != null) ...[
          const SizedBox(width: 12),
          Text(
            '${date.month}.${date.day} ${weekdays[date.weekday - 1]}',
            style: AppTypography.headline2Bold.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          '연차로 떠나는 로컬 여행',
          style: AppTypography.label1NormalMedium.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'offway',
          style: AppTypography.title3Bold.copyWith(
            color: AppColors.primaryNormal,
          ),
        ),
      ],
    );
  }

  /// 내 코스에서 공유된 것인지 — 웹 /m 과 같은 화면을 띄운다
  bool get _isSaved => widget.kind == 'saved';

  /// 시안: 내 코스는 '정선여행, 1박2일', 추천은 '정선, 1박2일 추천코스입니다.'
  Widget _buildTitle(String regionName, int durationDays) {
    final duration = _durationLabel(durationDays);
    final base = AppTypography.title1Bold.copyWith(
      color: AppColors.labelNormal,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: _isSaved
            ? [
                TextSpan(text: '$regionName여행, '),
                TextSpan(
                  text: duration,
                  style: base.copyWith(color: AppColors.primaryNormal),
                ),
              ]
            : [
                TextSpan(text: '$regionName, '),
                TextSpan(
                  text: duration,
                  style: base.copyWith(color: AppColors.primaryNormal),
                ),
                const TextSpan(text: '\n추천코스입니다.'),
              ],
      ),
    );
  }

  /// 내 코스는 여행 날짜를, 추천코스는 안내 문구를 낸다
  Widget _buildSubtitle(List<Map<String, dynamic>> days) {
    final style = AppTypography.body1NormalMedium.copyWith(
      color: AppColors.labelAlternative,
    );
    if (!_isSaved) {
      return Text('맞춤코스로 연차 여행을 떠나보세요.', style: style);
    }
    final start = DateTime.tryParse(days.first['date'] as String? ?? '');
    final end = DateTime.tryParse(days.last['date'] as String? ?? '');
    if (start == null) return Text('공유받은 코스예요', style: style);
    final text = end == null || end == start
        ? '${start.year}.${start.month}.${start.day}'
        : '${start.year}.${start.month}.${start.day} - ${end.month}.${end.day}';
    return Text(text, style: style);
  }

  /// 사용 연차·D-DAY — 내 코스에서 공유된 경우에만.
  ///
  /// 연차는 응답에 없어 여행 날짜로 서버에 계산을 맡긴다(웹 공유 페이지와 같다).
  Widget _buildBadges(List<Map<String, dynamic>> days) {
    final start = DateTime.tryParse(days.first['date'] as String? ?? '');
    final end = DateTime.tryParse(days.last['date'] as String? ?? '');
    if (start == null || end == null) return const SizedBox.shrink();

    final consumed = ref
        .watch(tripConsumedLeaveProvider((start: start, end: end)))
        .value;
    final dDay = _dDayLabel(start);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (consumed != null)
            _SharedBadge(
              iconAsset: 'assets/icons/ic_clock.svg',
              label: '사용 연차 일수 ${formatLeaveDays(consumed)}일',
            ),
          if (dDay.isNotEmpty) _SharedBadge(label: dDay),
        ],
      ),
    );
  }

  /// 지난 여행에는 D-DAY를 붙이지 않는다
  String _dDayLabel(DateTime start) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = DateUtils.dateOnly(start).difference(today).inDays;
    if (diff == 0) return 'D-DAY';
    return diff > 0 ? 'D-$diff' : '';
  }

  /// 코스 응답에는 지역 이름이 없어 첫 장소에서 가져온다
  String _regionNameOf(List<Map<String, dynamic>> days) {
    for (final day in days) {
      for (final p in (day['places'] as List).cast<Map<String, dynamic>>()) {
        if (p['regionName'] case final String name) return name;
      }
    }
    return '';
  }

  String _durationLabel(int days) => switch (days) {
    1 => '당일치기',
    2 => '1박2일',
    _ => '2박3일',
  };
}

/// 옅은 Primary 면 위의 정보 뱃지 — 내 코스 상세와 같은 모양
class _SharedBadge extends StatelessWidget {
  const _SharedBadge({required this.label, this.iconAsset});

  final String label;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryNormal.withValues(alpha: AppOpacity.o8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset case final asset?) ...[
            SvgPicture.asset(
              asset,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.primaryNormal,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.label1NormalBold.copyWith(
              color: AppColors.primaryNormal,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공유 코스의 장소 한 줄 — 보기 전용이라 탭 동작이 없다
class _SharedPlaceRow extends StatelessWidget {
  const _SharedPlaceRow({required this.order, required this.place});

  final int order;
  final Map<String, dynamic> place;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.primaryNormal,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$order',
              style: AppTypography.label1NormalBold.copyWith(
                color: AppColors.staticWhite,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (place['name'] as String?) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body1NormalBold.copyWith(
                    color: AppColors.labelNormal,
                  ),
                ),
                if (place['catchphrase'] case final String phrase) ...[
                  const SizedBox(height: 2),
                  Text(
                    phrase,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label1ReadingMedium.copyWith(
                      color: AppColors.labelNeutral,
                    ),
                  ),
                ],
                if (place['category'] case final String category) ...[
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: AppTypography.label2Regular.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
