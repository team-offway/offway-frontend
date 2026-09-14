import 'package:flutter/material.dart';

import '../../../core/constants/trip_constants.dart';

/// 잠금화면·다이나믹 아일랜드에 띄우는 **여행 D-day** 한 건.
///
/// 앱이 아는 것만으로 만든다 — 코스에는 시각 정보가 없어(장소마다 몇 시인지
/// 서버가 주지 않는다) "몇 시에 어디"는 띄울 수 없다. 날짜로 답할 수 있는
/// 것만 담는다.
@immutable
class TripCountdown {
  const TripCountdown({
    required this.courseId,
    required this.regionName,
    required this.startDate,
    required this.endDate,
    required this.durationLabel,
  });

  final String courseId;

  /// '정선군' — 잠금화면 제목에 쓴다
  final String regionName;

  /// 여행 첫날·마지막날 (둘 다 포함)
  final DateTime startDate;
  final DateTime endDate;

  /// '당일치기' · '1박 2일' · '2박 3일'
  final String durationLabel;

  /// 오늘 기준 남은 날. 여행 첫날이면 0, 지났으면 음수다.
  ///
  /// **[calendarDaysBetween]을 쓴다** — `difference().inDays`는 경과 시간을
  /// 24로 나눠 서머타임이 있는 지역에서 하루가 어긋난다. 내 코스 상세가
  /// 쓰는 것과 같은 규칙이라 두 화면이 다른 숫자를 말하지 않는다
  int daysUntil(DateTime now) => calendarDaysBetween(
    DateUtils.dateOnly(now),
    DateUtils.dateOnly(startDate),
  );

  /// 여행 중인가 — 첫날부터 마지막날까지
  bool isOngoing(DateTime now) {
    final today = DateUtils.dateOnly(now);
    return !today.isBefore(DateUtils.dateOnly(startDate)) &&
        !today.isAfter(DateUtils.dateOnly(endDate));
  }

  /// 이미 끝난 여행인가 — 마지막날이 지났으면
  bool isPast(DateTime now) =>
      DateUtils.dateOnly(endDate).isBefore(DateUtils.dateOnly(now));

  /// 잠금화면에 그대로 띄우는 한 줄.
  ///
  /// 여행 중에는 남은 날이 아니라 **며칠째인지**를 말한다 — 이미 떠나 온
  /// 사람에게 'D-0'은 알려 주는 것이 없다
  String headline(DateTime now) {
    if (isPast(now)) return '$regionName 여행을 마쳤어요';
    if (isOngoing(now)) {
      final nth =
          calendarDaysBetween(
            DateUtils.dateOnly(startDate),
            DateUtils.dateOnly(now),
          ) +
          1;
      return '$regionName 여행 $nth일차';
    }
    final left = daysUntil(now);
    if (left == 1) return '내일 $regionName 여행';
    return '$regionName 여행 D-$left';
  }

  /// `2026.7.26 - 7.28` — 부제로 쓰는 기간 표기
  String get rangeLabel {
    final s = '${startDate.year}.${startDate.month}.${startDate.day}';
    if (DateUtils.isSameDay(startDate, endDate)) return s;
    return '$s - ${endDate.month}.${endDate.day}';
  }

  /// 저장 코스 카드(`_toSavedCardMap`)에서 만든다.
  ///
  /// 날짜가 없는 코스(일정 미확정)는 D-day를 셀 수 없어 **null**이다 —
  /// 억지로 오늘로 치면 엉뚱한 여행이 잠금화면에 뜬다
  static TripCountdown? tryFrom(Map<String, dynamic> card) {
    final start = DateTime.tryParse(card['startDate'] as String? ?? '');
    if (start == null) return null;
    final end = DateTime.tryParse(card['endDate'] as String? ?? '') ?? start;
    final id = card['courseId'] as String? ?? card['id'] as String?;
    if (id == null) return null;
    return TripCountdown(
      courseId: id,
      regionName: card['regionName'] as String? ?? '',
      startDate: start,
      endDate: end,
      durationLabel: card['durationLabel'] as String? ?? '',
    );
  }

  /// 여러 코스 중 **잠금화면에 띄울 하나**를 고른다.
  ///
  /// 여행 중인 것이 가장 급하고, 없으면 가장 가까운 예정이다. 지난 여행은
  /// 고르지 않는다 — 끝난 여행이 잠금화면에 남아 있을 이유가 없다.
  ///
  /// **며칠 뒤까지 띄울지는 [within]이 정한다.** 두 달 뒤 여행에 D-60을
  /// 띄우면 잠금화면만 차지한다
  static TripCountdown? pick(
    List<TripCountdown> trips,
    DateTime now, {
    int within = 7,
  }) {
    final ongoing = trips.where((t) => t.isOngoing(now)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    if (ongoing.isNotEmpty) return ongoing.first;

    final upcoming =
        trips
            .where((t) => !t.isPast(now) && t.daysUntil(now) <= within)
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
