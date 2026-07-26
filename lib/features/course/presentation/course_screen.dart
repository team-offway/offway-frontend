import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../mock/mock_data_source.dart';
import '../../course_wizard/application/course_wizard_provider.dart';
import 'widgets/course_day_tabs.dart';
import 'widgets/course_map.dart';
import 'widgets/course_place_list.dart';

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

/// O-09 · 코스확정 (당일치기 / 2박3일, 와이어프레임)
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
  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _textSecondary = Color(0xFF686F7E);
  static const _actionGray = Color(0xFFE9E9ED);
  static const _ctaBlack = Color(0xFF1A1A1A);
  static const _imagePlaceholder = Color(0xFFF2F3F6);

  int _selectedDay = 1;

  void _exitToHome() {
    ref.read(courseWizardProvider.notifier).reset();
    context.go(AppRoutes.home);
  }

  String _durationLabel(int days) => switch (days) {
    1 => '당일치기',
    2 => '1박 2일',
    _ => '2박 3일',
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
      backgroundColor: Colors.white,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: _exitToHome,
                child: const Icon(Icons.close, size: 26, color: _labelNormal),
              ),
              const Spacer(),
              GestureDetector(
                // TODO(share): 코스 공유 기능 정책 확정 시 연결
                onTap: () {},
                child: const Icon(
                  Icons.ios_share,
                  size: 24,
                  color: _labelNormal,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  width: 79,
                  height: 79,
                  color: _imagePlaceholder,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.regionId}, ${_durationLabel(durationDays)}\n추천코스입니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _labelNormal,
                  letterSpacing: -0.6,
                  height: 32 / 24,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '맞춤코스로 연차 여행을 떠나보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textTertiary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: SizedBox(
                    height: 202,
                    child: CourseMap(places: places, dayKey: _selectedDay),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (durationDays > 1) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CourseDayTabs(
                    durationDays: durationDays,
                    selectedDay: _selectedDay,
                    onSelect: (d) => setState(() => _selectedDay = d),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CoursePlaceList(
                  places: places,
                  regionName: widget.regionId,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO(my-course): 내 코스 저장 기능 연결 (내 코스 탭 작업 시)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('내 코스에 담았어요 (준비 중)')),
                    );
                  },
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text(
                    '내 코스에 담기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ctaBlack,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryAction(
                      icon: Icons.repeat,
                      label: '새로운 추천 받기',
                      onTap: () =>
                          context.pushReplacement(AppRoutes.wizardLoading),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SecondaryAction(
                      icon: Icons.home_outlined,
                      label: '홈으로 가기',
                      onTap: _exitToHome,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: _CourseScreenState._textSecondary),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _CourseScreenState._textSecondary,
            letterSpacing: -0.6,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _CourseScreenState._actionGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
