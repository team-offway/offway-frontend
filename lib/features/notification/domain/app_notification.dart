/// 알림 종류 — 서버가 주는 `type` 값에 아이콘·문구를 맞추는 키 (core #263).
///
/// **문구를 서버가 들지 않는다.** 응답에는 이 상수 이름만 실린다 — 문구를
/// 서버에 굳히면 이미 쌓인 알림이 옛 문구로 남아 화면에 두 세대가 섞인다.
///
/// **모르는 값은 [unknown]으로 받는다.** 서버는 값을 늘릴 수 있고, 앱을
/// 업데이트하지 않은 사용자에게도 새 알림이 간다. 파싱에서 터지면 새 알림
/// 하나 때문에 목록 전체가 안 보인다.
enum NotificationType {
  /// 내일 여행을 떠난다 — 저장한 코스의 시작일이 내일
  tripTomorrow('TRIP_TOMORROW'),

  /// 여행이 끝났다 — 연차를 기록해 달라는 알림.
  ///
  /// **서버에 아직 이 타입이 없다.** `NotificationType`에 `TRIP_TOMORROW`
  /// 하나뿐이라 지금은 오지 않는다. 시안(알림_모달)이 요구하는 알림이라
  /// 앱 쪽 문구·이동은 먼저 맞춰 두고, 서버가 타입을 더하면 바로 뜬다.
  tripAfter('TRIP_AFTER'),

  /// 앱이 모르는 종류 — 기본 아이콘·문구로 그린다
  unknown('');

  const NotificationType(this.wireName);

  /// 서버가 쓰는 상수 이름
  final String wireName;

  static NotificationType parse(String? raw) {
    for (final type in values) {
      if (type != unknown && type.wireName == raw) return type;
    }
    return unknown;
  }
}

/// 알림 한 건.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.read,
    this.courseId,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: NotificationType.parse(json['type'] as String?),
      read: json['read'] as bool? ?? false,
      courseId: (json['courseId'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  final int id;
  final NotificationType type;
  final bool read;

  /// 누르면 이동할 코스. 코스와 무관한 알림이면 null이고,
  /// **지워진 코스를 가리킬 수도 있다** — 알림은 코스가 사라져도 남는다
  final int? courseId;

  final DateTime? createdAt;

  /// 셀 제목 — 시안은 종류와 무관하게 '알림'이다
  String get title => '알림';

  /// 셀 본문 — 종류에 따라 앱이 고른다.
  ///
  /// 지역명이 필요한 문구는 코스를 따로 읽어야 알 수 있어 넣지 않는다.
  /// 시안 문구에서 지역명만 뺀 형태다.
  String get body => switch (type) {
    NotificationType.tripTomorrow => '내일은 여행을 떠나는 날이에요.\n짐은 다 챙기셨나요?',
    NotificationType.tripAfter => '여행, 다녀오셨나요?\n연차를 사용했다면 기록해 주세요.',
    NotificationType.unknown => '새로운 소식이 도착했어요.',
  };

  /// 상대 시각 — `방금전` · `3시간 전` · `2일 전`.
  ///
  /// 서버가 보관하는 30일을 넘기지 않으므로 그 위 단위는 두지 않는다.
  String timeLabel([DateTime? now]) {
    final created = createdAt;
    if (created == null) return '';

    final elapsed = (now ?? DateTime.now()).difference(created);
    // 기기 시계가 조금 느리면 음수가 나온다 — 미래로 보이느니 '방금전'이다
    if (elapsed.inMinutes < 1) return '방금전';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}분 전';
    if (elapsed.inDays < 1) return '${elapsed.inHours}시간 전';
    return '${elapsed.inDays}일 전';
  }
}
