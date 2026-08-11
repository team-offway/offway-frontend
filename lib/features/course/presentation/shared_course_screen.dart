import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_error_view.dart';
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
  const SharedCourseScreen({super.key, required this.shareToken});

  final String shareToken;

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
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
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
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$regionName 여행, ${_durationLabel(durationDays)}',
                style: AppTypography.title1Bold.copyWith(
                  color: AppColors.labelNormal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '공유받은 코스예요',
                style: AppTypography.body1NormalMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
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
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CourseDayTabs(
            durationDays: durationDays,
            selectedDay: _selectedDay,
            onSelect: (d) => setState(() => _selectedDay = d),
          ),
        ),
        const SizedBox(height: 20),
        for (final (i, place) in places.indexed)
          _SharedPlaceRow(order: i + 1, place: place),
      ],
    );
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

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        // 없으면 Stack이 제목 크기로 줄어 Positioned가 화면 기준이 아니게 된다
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              '공유받은 코스',
              style: AppTypography.headline2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
          ),
          Positioned(
            left: 6,
            child: AppBackButton(
              // 링크로 바로 들어오면 되돌아갈 화면이 없다 — 홈으로 보낸다
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
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
