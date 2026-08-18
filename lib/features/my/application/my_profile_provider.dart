import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/data/auth_repository.dart';
import '../../home/presentation/home_screen.dart' show homeUserProvider;

/// 마이 화면에 그릴 사용자 — 로그인했으면 서버에서, 아니면 홈 응답에서 읽는다.
///
/// **홈 응답만으로는 부족하다.** `/home`의 `user.name`은 비회원까지 아우르는
/// 값이라 로그인해도 '게스트'가 온다(core `HomeResponse.GUEST_NAME`).
/// 그래서 로그인 상태에서는 `/users/me`를 따로 묻는다.
///
/// 실패하면 홈 값으로 돌아간다 — 이름을 못 부르는 것뿐이라 화면을 막을 일이
/// 아니다.
final myProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final home = await ref.watch(homeUserProvider.future);

  final token = await ref.watch(secureStorageProvider).accessToken;
  if (token == null) return home;

  try {
    final me = await ref.watch(authRepositoryProvider).me();
    return {
      ...home,
      // 서버가 주는 이름이 정본이다 — 홈의 '게스트'를 덮는다
      if (me['nickname'] case final String name) 'nickname': name,
      if (me['email'] case final String email) 'email': email,
      if (me['provider'] case final String provider) 'provider': provider,
    };
  } on ApiException {
    return home;
  }
});
