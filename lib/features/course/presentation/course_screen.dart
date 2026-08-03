import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../mock/mock_data_source.dart';
import '../../course_wizard/application/course_wizard_provider.dart';
import 'widgets/course_day_tabs.dart';
import 'widgets/course_map.dart';
import 'widgets/course_place_list.dart';
import 'widgets/course_share_sheet.dart';

/// 지역·희망일수에 맞는 mock 코스 선택 (서버 연동 시 추천 API 응답으로 교체)
final courseProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, ({String regionId, int desiredDays})>((
      ref,
      query,
    ) async {
      final data = await MockDataSource.courses();
      final courses = (data['courses'] as List)
          .cast<Map<String, dynamic>>()
          .where((c) => c['regionId'] == query.regionId)
          .toList();
      if (courses.isEmpty) return null;
      courses.sort(
        (a, b) => ((a['durationDays'] as int) - query.desiredDays)
            .abs()
            .compareTo(((b['durationDays'] as int) - query.desiredDays).abs()),
      );
      return courses.first;
    });

/// O-09 · 코스확정 (당일치기 / 1박 이상)
class CourseScreen extends ConsumerStatefulWidget {
  const CourseScreen({
    super.key,
    required this.regionId,
    required this.desiredDays,
  });

  final String regionId;
  final int desiredDays;

  @override
  ConsumerState<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends ConsumerState<CourseScreen> {
  int _selectedDay = 1;

  void _exitToHome() {
    ref.read(courseWizardProvider.notifier).reset();
    context.go(AppRoutes.home);
  }

  /// 코스를 담고 내 코스 탭으로 이동한다. 위저드는 여기서 끝나므로 조건을 초기화한다.
  ///
  /// TODO(course): 서버 저장 API 연동. 지금은 mock JSON에 쓸 수 없어 실제로 담기지
  /// 않으므로, 담긴 것으로 오해하지 않도록 이동 전에 안내를 띄운다.
  void _saveToMyCourses() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('코스 담기는 준비 중이에요. 내 코스 화면으로 이동할게요')),
    );
    ref.read(courseWizardProvider.notifier).reset();
    context.go(AppRoutes.myCourses);
  }

  String _durationLabel(int days) => switch (days) {
    1 => '당일치기',
    2 => '1박2일',
    _ => '2박3일',
  };

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(
      courseProvider((
        regionId: widget.regionId,
        desiredDays: widget.desiredDays,
      )),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: course.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('코스를 불러오지 못했어요\n$e')),
          data: (data) {
            if (data == null) {
              return const Center(child: Text('해당 지역의 코스가 아직 없어요'));
            }
            return _buildBody(data);
          },
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

    return Column(
      children: [
        Padding(
          // 버튼이 아이콘보다 넓으므로 좌우 여백을 줄여 아이콘 위치를 맞춘다
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              AppIconButton(
                icon: Icons.close,
                onTap: _exitToHome,
                semanticLabel: '닫기',
              ),
              const Spacer(),
              AppIconButton(
                icon: Icons.ios_share,
                onTap: () => CourseShareSheets.showEntry(
                  context,
                  dayCount: durationDays,
                ),
                semanticLabel: '공유하기',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Center(
                child: SvgPicture.asset(
                  'assets/icons/ic_pin_location.svg',
                  width: 48,
                  height: 48,
                ),
              ),
              const SizedBox(height: 20),
              _buildHeadline(durationDays),
              const SizedBox(height: 8),
              Text(
                '맞춤코스로 연차 여행을 떠나보세요.',
                textAlign: TextAlign.center,
                style: AppTypography.body1NormalMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 198,
                  child: CourseMap(places: places, dayKey: _selectedDay),
                ),
              ),
              const SizedBox(height: 20),
              if (durationDays > 1) ...[
                CourseDayTabs(
                  durationDays: durationDays,
                  selectedDay: _selectedDay,
                  onSelect: (d) => setState(() => _selectedDay = d),
                ),
                const SizedBox(height: 12),
              ],
              CoursePlaceList(places: places, regionName: widget.regionId),
            ],
          ),
        ),
        _buildActionArea(),
      ],
    );
  }

  /// "정선, 2박3일 추천코스입니다." — 지역·기간만 브랜드색으로 짚는다
  Widget _buildHeadline(int durationDays) {
    final base = AppTypography.title3Bold.copyWith(
      color: AppColors.labelNormal,
    );
    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '${widget.regionId}, '),
          TextSpan(
            text: _durationLabel(durationDays),
            style: base.copyWith(color: AppColors.primaryNormal),
          ),
          const TextSpan(text: '\n추천코스입니다.'),
        ],
      ),
    );
  }

  Widget _buildActionArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Text(
            '추천 코스를 내 코스에 담으면\n언제든 확인이 가능해요!',
            textAlign: TextAlign.center,
            style: AppTypography.label1ReadingMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveToMyCourses,
              icon: const Icon(Icons.download, size: 20),
              label: Text('내 코스에 담기', style: AppTypography.body1NormalBold),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNormal,
                foregroundColor: AppColors.staticWhite,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.pushReplacement(AppRoutes.wizardLoading),
              icon: const Icon(Icons.refresh, size: 20),
              label: Text('새로운 추천 받기', style: AppTypography.body1NormalBold),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNormal,
                side: const BorderSide(color: AppColors.primaryNormal),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _exitToHome,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '홈으로 가기',
                style: AppTypography.label1ReadingMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
