import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_tab_pills.dart';
import '../../../mock/mock_data_source.dart';

/// 저장한 코스 목록 mock (서버 연동 시 내 코스 목록 API로 교체)
final savedCoursesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final data = await MockDataSource.courses();
  return (data['savedCourses'] as List? ?? const [])
      .cast<Map<String, dynamic>>();
});

// TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
const _labelNormal = Color(0xFF171719);
const _textMuted = Color(0xFF6F767E);
const _chipBg = Color(0xFFE9E9ED);
const _thumbPlaceholder = Color(0xFFC5C8CE);
const _confirmedDot = Color(0xFF2272EB);
const _pendingDot = Color(0xFF9EA4AA);

/// 정렬 기준. 지금은 mock이라 저장 순서를 그대로 쓰고, 서버 연동 시 쿼리로 넘긴다
enum _SortOrder {
  latest('최신순'),
  oldest('오래된순');

  const _SortOrder(this.label);

  final String label;
}

/// 내 코스 — 저장한 코스를 확정/미확정 상태와 함께 보여준다
class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  _SortOrder _sort = _SortOrder.latest;

  /// 최신순은 저장 순서의 역순(mock은 오래된 것부터 담겨 있다)
  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> all) {
    return _sort == _SortOrder.latest ? all.reversed.toList() : all;
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(savedCoursesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: courses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('코스를 불러오지 못했어요\n$e')),
          data: (all) => _buildBody(_sorted(all)),
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

  Widget _buildBody(List<Map<String, dynamic>> courses) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
      children: [
        const Text(
          '내 코스',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _labelNormal,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 16),
        _buildSortChip(),
        const SizedBox(height: 24),
        if (courses.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: Text(
                '저장한 코스가 아직 없어요',
                style: TextStyle(fontSize: 14, color: _textMuted),
              ),
            ),
          )
        else
          for (final course in courses) ...[
            _CourseCard(course: course),
            const SizedBox(height: 24),
          ],
        if (courses.isNotEmpty) _buildLegend(),
      ],
    );
  }

  Widget _buildSortChip() {
    // Row로 감싸 칩이 목록 폭 전체로 늘어나지 않게 한다
    return Row(
      children: [
        GestureDetector(
          // 정렬 기준이 둘뿐이라 탭할 때마다 번갈아 바꾼다
          onTap: () => setState(() {
            _sort = _sort == _SortOrder.latest
                ? _SortOrder.oldest
                : _SortOrder.latest;
          }),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _chipBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _sort.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textMuted,
                letterSpacing: -0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 카드의 점 색이 무엇을 뜻하는지 알려주는 범례
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (color, label) in const [
          (_confirmedDot, '일정 확정'),
          (_pendingDot, '일정 미확정'),
        ]) ...[
          if (label != '일정 확정') const SizedBox(width: 16),
          _Dot(color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textMuted,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// 코스 카드 — 지도 썸네일 + 지역·기간 + 날짜 상태
class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Map<String, dynamic> course;

  /// 확정된 코스는 `7/20(금) – 7/22(일)`, 미확정은 `날짜 미정 · 8월경`
  String _dateLabel() {
    final start = DateTime.tryParse(course['startDate'] as String? ?? '');
    if (start == null) {
      final note = course['plannedNote'] as String?;
      return note == null ? '날짜 미정' : '날짜 미정 · $note';
    }
    final end = DateTime.tryParse(course['endDate'] as String? ?? '');
    if (end == null || end == start) return _formatDate(start);
    return '${_formatDate(start)} – ${_formatDate(end)}';
  }

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day}(${_weekdays[d.weekday - 1]})';

  @override
  Widget build(BuildContext context) {
    final confirmed = course['confirmed'] as bool? ?? false;
    final regionName = course['regionName'] as String? ?? '';
    final duration = course['durationLabel'] as String? ?? '';

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.coursePath(
          course['regionId'] as String,
          desiredDays: duration == '당일치기' ? 1 : 3,
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO(course): 서버에서 코스 지도 썸네일 내려주면 이미지로 교체
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 173,
              width: double.infinity,
              color: _thumbPlaceholder,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$regionName · $duration',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _labelNormal,
              letterSpacing: -0.76,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Dot(color: confirmed ? _confirmedDot : _pendingDot),
              const SizedBox(width: 6),
              Text(
                _dateLabel(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: confirmed ? _confirmedDot : _textMuted,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
