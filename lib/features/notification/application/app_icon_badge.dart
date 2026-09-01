import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

/// 앱 아이콘의 숫자 배지를 서버가 아는 안읽음 수에 맞춘다.
///
/// 푸시가 올 때는 서버가 `aps.badge`를 실어 iOS가 알아서 그린다(core #367).
/// 그런데 **앱 안에서 읽으면 그 숫자가 안 내려간다** — 아이콘 배지를 지우는
/// 쪽은 앱뿐인데 그 코드가 없었다. 다음 푸시가 올 때까지 낡은 숫자가 남아,
/// 홈 종의 점은 꺼졌는데 아이콘엔 숫자가 있는 어긋남이 생겼다.
///
/// 안읽음 수를 아는 자리(목록 조회·읽음 처리)와 세션이 끝나는 자리(로그아웃·
/// 만료·탈퇴)에서 부른다. **실패해도 삼킨다** — 배지는 덤이고, 여기서
/// 던지면 읽음 처리나 로그아웃이 막힌다.
Future<void> syncAppIconBadge(int unread) async {
  try {
    await AppBadgePlus.updateBadge(unread < 0 ? 0 : unread);
  } on Object catch (e) {
    debugPrint('앱 아이콘 배지 갱신 실패: $e');
  }
}

/// 세션이 끝났다 — 남의 숫자가 아이콘에 남지 않게 지운다
Future<void> clearAppIconBadge() => syncAppIconBadge(0);
