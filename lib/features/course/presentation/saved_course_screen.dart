import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/course_repository.dart';
import 'my_courses_screen.dart';
import 'widgets/course_day_tabs.dart';
import 'widgets/course_map.dart';
import 'widgets/course_place_list.dart';

// TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
const _labelNormal = Color(0xFF171719);
const _durationAccent = Color(0xFF368FFF);
const _textTertiary = Color(0xFFADB1BB);
const _badgeBg = Color(0x293182F6); // rgba(49,130,246,0.16)
const _badgeText = Color(0xFF2272EB);
const _deleteBg = Color(0xFFF7F7F7);
const _deleteText = Color(0xFF3A3A3A);

/// 저장한 코스 하나 (`GET /courses/{id}`) — 카드 정보와 일정을 함께 받는다
final savedCourseDetailProvider = FutureProvider.autoDispose
    .family<
      ({Map<String, dynamic> saved, Map<String, dynamic> course})?,
      String
    >(
      (ref, savedId) =>
          ref.watch(courseRepositoryProvider).savedCourseDetail(savedId),
    );

/// 내 코스에서 선택해 들어온 코스 상세 — 확정/미확정 상태에 따라 날짜 줄이 달라진다
class SavedCourseScreen extends ConsumerStatefulWidget {
  const SavedCourseScreen({super.key, required this.savedId});

  final String savedId;

  @override
  ConsumerState<SavedCourseScreen> createState() => _SavedCourseScreenState();
}

class _SavedCourseScreenState extends ConsumerState<SavedCourseScreen> {
  int _selectedDay = 1;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(savedCourseDetailProvider(widget.savedId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('코스를 불러오지 못했어요\n$e')),
          data: (data) => data == null
              ? const Center(child: Text('저장한 코스를 찾을 수 없어요'))
              : _buildBody(data.saved, data.course),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> saved, Map<String, dynamic> course) {
    final days = (course['days'] as List).cast<Map<String, dynamic>>();
    final durationDays = course['durationDays'] as int;
    final day = days.firstWhere(
      (d) => d['day'] == _selectedDay,
      orElse: () => days.first,
    );
    final places = (day['places'] as List).cast<Map<String, dynamic>>();
    final regionName = saved['regionName'] as String? ?? '';

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(regionName, saved['durationLabel'] as String?),
                    const SizedBox(height: 5),
                    _buildDateLine(saved),
                    const SizedBox(height: 12),
                    _buildLeaveBadge(durationDays),
                  ],
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CourseDayTabs(
                  durationDays: durationDays,
                  selectedDay: _selectedDay,
                  onSelect: (d) => setState(() => _selectedDay = d),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CoursePlaceList(places: places, regionName: regionName),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        _buildDeleteButton(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 22,
              color: _labelNormal,
            ),
          ),
          const Spacer(),
          GestureDetector(
            // TODO(share): 코스 공유 기능 정책 확정 시 연결
            onTap: () => _showPreparing('코스 공유'),
            child: const Icon(Icons.ios_share, size: 24, color: _labelNormal),
          ),
        ],
      ),
    );
  }

  /// `정선 여행 2박 3일` — 기간만 파란색으로 강조한다
  Widget _buildTitle(String regionName, String? durationLabel) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$regionName 여행 '),
          TextSpan(
            text: durationLabel ?? '',
            style: const TextStyle(color: _durationAccent),
          ),
        ],
      ),
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: _labelNormal,
        letterSpacing: -0.6,
        height: 32 / 24,
      ),
    );
  }

  /// 확정이면 날짜 범위, 미확정이면 일정을 정하러 가는 링크
  Widget _buildDateLine(Map<String, dynamic> saved) {
    final start = DateTime.tryParse(saved['startDate'] as String? ?? '');
    if (start == null) {
      return GestureDetector(
        onTap: () => context.push(AppRoutes.courseSchedulePath(widget.savedId)),
        behavior: HitTestBehavior.opaque,
        child: const Text(
          '여행 일정 정하기',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textTertiary,
            letterSpacing: -0.6,
            decoration: TextDecoration.underline,
            decorationColor: _textTertiary,
          ),
        ),
      );
    }
    final end = DateTime.tryParse(saved['endDate'] as String? ?? '');
    final label = end == null || end == start
        ? '${start.year}.${start.month}.${start.day}'
        : '${start.year}.${start.month}.${start.day} - ${end.month}.${end.day}';
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textTertiary,
        letterSpacing: -0.6,
      ),
    );
  }

  /// 2박3일이면 주말을 빼고 실제로 쓰는 연차는 2일이다
  Widget _buildLeaveBadge(int durationDays) {
    final leaveDays = durationDays <= 1 ? 1 : durationDays - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _badgeBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '사용 연차 일수 $leaveDays일',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _badgeText,
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: SizedBox(
        width: double.infinity,
        height: 65,
        child: FilledButton(
          onPressed: _confirmDelete,
          style: FilledButton.styleFrom(
            backgroundColor: _deleteBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            '코스 삭제하기',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _deleteText,
              letterSpacing: -0.6,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('코스를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(courseRepositoryProvider).delete(widget.savedId);
      // 목록이 지워진 코스를 계속 보여주지 않도록 다시 불러오게 한다
      ref.invalidate(savedCoursesProvider);
      if (!mounted) return;
      showAppToast(context, '코스를 삭제했어요', kind: AppToastKind.success);
      context.pop();
    } on ApiException catch (e) {
      // 지워지지 않았는데 화면을 닫으면 지워진 줄 안다 — 머물러 알린다
      if (mounted) showAppToast(context, e.detail);
    }
  }

  void _showPreparing(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature 기능은 준비 중이에요')));
  }
}
