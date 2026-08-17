import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/trip_constants.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/trip_date_range_picker.dart';
import '../../onboarding/data/leave_repository.dart';

/// 고른 기간이 연차를 며칠 깎는지 — 서버가 평일−공휴일로 계산한다.
/// 서버가 안 되면 주말만 빼는 로컬 근사로 폴백한다.
final _consumedLeaveProvider = FutureProvider.autoDispose
    .family<double, ({DateTime start, DateTime end})>((ref, range) async {
      try {
        final result = await ref
            .read(leaveRepositoryProvider)
            .availableTime(
              transport: 'CAR',
              startDate: range.start,
              endDate: range.end,
            );
        return result.consumedLeaveDays;
      } on ApiException {
        return leaveDaysBetween(range.start, range.end).toDouble();
      }
    });

/// 연차 사용일 선택 — 등록 화면의 날짜 칸에서 올라온다.
///
/// 여행 코스와 달리 2박3일 상한이 없다. 쉬는 날은 며칠이든 등록할 수 있어야
/// 하기 때문이다. 고른 범위가 연차를 며칠 깎는지는 서버에 물어 보여준다.
class LeaveDatePickerScreen extends ConsumerStatefulWidget {
  const LeaveDatePickerScreen({super.key, this.initialRange});

  /// 다시 열었을 때 이전 선택을 이어받는다
  final DateTimeRange? initialRange;

  @override
  ConsumerState<LeaveDatePickerScreen> createState() =>
      _LeaveDatePickerScreenState();
}

class _LeaveDatePickerScreenState extends ConsumerState<LeaveDatePickerScreen> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange?.start;
    _end = widget.initialRange?.end;
  }

  bool get _hasRange => _start != null && _end != null;

  /// 캘린더 탭 규칙.
  ///
  /// 하루만 쓰는 경우가 가장 흔하므로 **첫 탭에 하루짜리 범위가 완성된다** —
  /// 여행 위저드처럼 두 번 눌러야 열리면, 하루를 고른 사람은 버튼이 잠긴
  /// 이유를 알 수 없다. 이어서 다른 날을 누르면 그 날까지 범위가 늘어난다.
  void _select(DateTime day) {
    setState(() {
      final start = _start;
      final end = _end;
      // 아직 아무것도 없거나, 이미 여러 날을 고른 뒤라면 그 날 하루로 새로 시작
      if (start == null || (end != null && end != start)) {
        _start = day;
        _end = day;
        return;
      }
      // 하루가 골라진 상태 — 다른 날을 누르면 그 사이가 범위가 된다
      if (day.isBefore(start)) {
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final consumedAsync = _hasRange
        ? ref.watch(_consumedLeaveProvider((start: _start!, end: _end!)))
        : null;
    final consumed = consumedAsync?.value;
    // 계산이 끝나기 전에 확정하면 등록 화면이 채우는 기본값과 어긋난다
    final calculating = consumedAsync?.isLoading ?? false;

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
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '연차 사용일 선택',
                    style: AppTypography.title3Bold.copyWith(
                      color: AppColors.labelNormal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '사용한 연차 날짜를 선택해 주세요.',
                    style: AppTypography.body1NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TripDateRangePicker(
                today: today,
                startDate: _start,
                endDate: _end,
                onSelect: _select,
                // 연차는 여행과 달리 며칠이든 등록할 수 있다
                maxSpanDays: null,
                // 여행이 아니라 연차 쓴 날이라 '가는날/오는날'이 맞지 않는다
                showTripLabels: false,
              ),
            ),
            _buildActionArea(consumed, calculating),
          ],
        ),
      ),
    );
  }

  /// 하단 — 고른 범위가 연차를 며칠 쓰는지 먼저 알리고 CTA를 둔다
  Widget _buildActionArea(double? consumed, bool calculating) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 자리를 늘 차지해 날짜를 고를 때 버튼이 아래위로 움직이지 않게 한다
          SizedBox(
            height: 22,
            child: (calculating || consumed != null)
                ? Text(
                    calculating
                        ? '차감 연차 일수 계산 중이에요'
                        : '차감 연차 일수 ${formatLeaveDays(consumed!)}일',
                    style: AppTypography.body2NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _hasRange && !calculating
                  ? () => Navigator.of(context).pop((
                      range: DateTimeRange(start: _start!, end: _end!),
                      consumed: consumed,
                    ))
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNormal,
                disabledBackgroundColor: AppColors.interactionDisable,
                foregroundColor: AppColors.staticWhite,
                disabledForegroundColor: AppColors.labelAssistive,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('선택 완료', style: AppTypography.body1NormalBold),
            ),
          ),
        ],
      ),
    );
  }
}
