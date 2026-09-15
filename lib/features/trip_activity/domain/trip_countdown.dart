import 'package:flutter/material.dart';

import '../../../core/constants/trip_constants.dart';

/// 잠금화면·다이나믹 아일랜드에 띄우는 **여행 D-day** 한 건.
///
/// 앱이 아는 것만으로 만든다 — 코스에는 시각 정보가 없어(장소마다 몇 시인지
/// 서버가 주지 않는다) "몇 시에 어디"는 띄울 수 없다. 날짜로 답할 수 있는
/// 것만 담는다.
///
/// **문구는 여기서 만들지 않는다.** 네이티브 `ContentState` 가 재료(남은 날·
/// 며칠째·날짜)에서 조립한다(core #577 B안). 서버가 자정에 보내는 것과 같은
/// 재료라, 앱이 띄운 카드와 서버가 갱신한 카드가 다른 말을 하지 않는다.
@immutable
class TripCountdown {
  const TripCountdown({
    required this.courseId,
    required this.regionName,
    required this.startDate,
    required this.endDate,
  });

  final String courseId;

  /// '정선군' — 잠금화면 제목에 쓴다
  final String regionName;

  /// 여행 첫날·마지막날 (둘 다 포함)
  final DateTime startDate;
  final DateTime endDate;

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

  /// 남은 날 — **출발 전에만 값이 있다.** 여행 중이면 null.
  ///
  /// 서버 `TripProgress`(core #577)와 같은 계약이다. [dayNth]와 **둘 중 하나만**
  /// 값이 있다 — 비어 있다는 것 자체가 뜻이라(출발 전이냐 여행 중이냐) 네이티브에
  /// null 도 그대로 넘긴다
  int? daysLeft(DateTime now) => isOngoing(now) ? null : daysUntil(now);

  /// 여행 며칠째 — **여행 중에만 값이 있다.** 출발 당일이 1이고 0일차는 없다.
  ///
  /// 이미 떠나 온 사람에게 'D-0'은 알려 주는 것이 없다 — 첫날부터 며칠째로 센다
  int? dayNth(DateTime now) {
    if (!isOngoing(now)) return null;
    return calendarDaysBetween(
          DateUtils.dateOnly(startDate),
          DateUtils.dateOnly(now),
        ) +
        1;
  }

  /// `2026-09-23` — 네이티브·서버와 약속한 날짜 표기. 시각·시간대를 싣지 않는다
  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 저장 코스 카드(`_toSavedCardMap`)에서 만든다.
  ///
  /// 날짜가 없는 코스(일정 미확정)는 D-day를 셀 수 없어 **null**이다 —
  /// 억지로 오늘로 치면 엉뚱한 여행이 잠금화면에 뜬다
  static TripCountdown? tryFrom(Map<String, dynamic> card) {
    // **로컬 자정으로 맞춰 둔다.** 서버가 '2026-09-22T15:00:00Z' 같은 UTC
    // 표기로 바꾸면 isUtc 인 DateTime 이 만들어지고, 한국(UTC+9)에서는
    // 로컬 9/23 인데 날짜가 9/22 로 셈해져 D-day 가 하루 어긋난다
    final start = _dateOnlyLocal(card['startDate'] as String?);
    if (start == null) return null;
    final end = _dateOnlyLocal(card['endDate'] as String?) ?? start;
    final id = card['courseId'] as String? ?? card['id'] as String?;
    if (id == null) return null;
    return TripCountdown(
      courseId: id,
      regionName: card['regionName'] as String? ?? '',
      startDate: start,
      endDate: end,
    );
  }

  static DateTime? _dateOnlyLocal(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    return parsed == null ? null : DateUtils.dateOnly(parsed.toLocal());
  }

  /// 여러 코스 중 **잠금화면에 띄울 하나**를 고른다.
  ///
  /// 여행 중인 것이 가장 급하고, 없으면 가장 가까운 예정이다. 지난 여행은
  /// 고르지 않는다 — 끝난 여행이 잠금화면에 남아 있을 이유가 없다.
  ///
  /// **며칠 뒤까지 띄울지는 [within]이 정한다.** 두 달 뒤 여행에 D-60을
  /// 띄우면 잠금화면만 차지한다 — D-5 부터 띄운다
  static TripCountdown? pick(
    List<TripCountdown> trips,
    DateTime now, {
    int within = 5,
  }) {
    final ongoing = trips.where((t) => t.isOngoing(now)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    if (ongoing.isNotEmpty) return ongoing.first;

    final upcoming =
        trips
            // **역전 데이터를 먼저 걷어낸다.** endDate 가 startDate 보다
            // 앞서면 isOngoing·isPast 둘 다 false 라 그대로 뽑힌다 —
            // 지난 날짜면 'D--3' 이, 앞선 날짜면 엉뚱한 기간이 나간다.
            // 하한(>= 0)만으로는 미래의 역전을 못 막는다
            .where(
              (t) =>
                  !DateUtils.dateOnly(
                    t.endDate,
                  ).isBefore(DateUtils.dateOnly(t.startDate)) &&
                  !t.isPast(now) &&
                  t.daysUntil(now) >= 0 &&
                  t.daysUntil(now) <= within,
            )
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
