import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'push_registration.dart';

/// 기기 알림 권한이 켜져 있는지.
///
/// 화면에 들어올 때마다 다시 읽는다 — 설정에서 켜고 돌아온 사람에게
/// 안내가 남아 있으면 안 된다.
final notificationEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(pushRegistrationProvider).isAuthorized(),
);
