import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/trip_date_range_picker.dart';
import '../../../core/constants/trip_constants.dart';
import 'my_courses_screen.dart';
import 'saved_course_screen.dart';

// TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
const _labelNormal = Color(0xFF171719);
const _ctaDisabled = Color(0xFFC5C8CE);
const _ctaEnabled = Color(0xFF191B1F);

/// 저장한 코스의 여행 일정 지정 — 미확정 코스에서 '여행 일정 정하기'로 진입한다.
/// 캘린더는 위저드와 같은 컴포넌트를 쓰고, 고른 날짜를 그 코스에 저장한다.
class CourseScheduleScreen extends ConsumerStatefulWidget {
  const CourseScheduleScreen({super.key, required this.savedId});

  final String savedId;

  @override
  ConsumerState<CourseScheduleScreen> createState() =>
      _CourseScheduleScreenState();
}

class _CourseScheduleScreenState extends ConsumerState<CourseScheduleScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool get _hasRange => _startDate != null && _endDate != null;

  void _onSelectDate(DateTime day) {
    final range = resolveTripDateTap(
      day: day,
      start: _startDate,
      end: _endDate,
    );
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.close, size: 26, color: _labelNormal),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(23, 20, 23, 0),
              child: Text(
                '여행 날짜 선택',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _labelNormal,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const TripDateLimitBanner(),
            Expanded(
              child: TripDateRangePicker(
                today: today,
                startDate: _startDate,
                endDate: _endDate,
                onSelect: _onSelectDate,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _hasRange ? _saveSchedule : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _ctaEnabled,
                    disabledBackgroundColor: _ctaDisabled,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '선택 완료',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSchedule() {
    // TODO(course): 서버 일정 확정 API 연동. mock JSON은 쓰기가 불가해
    // 지금은 프로바이더만 무효화하고 코스 상세로 돌아간다
    ref.invalidate(savedCourseDetailProvider(widget.savedId));
    ref.invalidate(savedCoursesProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('일정 저장은 서버 연동 후 반영돼요')));
    context.pop();
  }
}
