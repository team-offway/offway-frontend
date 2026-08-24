import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';
import '../../home/presentation/home_screen.dart' show homeUserProvider;

/// 지금 로그인한 사용자 — 홈·마이가 함께 읽는다.
///
/// **홈 응답만으로는 부족하다.** `/home`의 `user.name`은 비회원까지 아우르는
/// 값이라 로그인해도 '게스트'가 온다(core `HomeResponse.GUEST_NAME`).
/// 그래서 로그인 상태에서는 `/users/me`를 따로 묻는다.
///
/// 실패하면 홈 값으로 돌아간다 — 이름을 못 부르는 것뿐이라 화면을 막을 일이
/// 아니다.
///
/// **autoDispose를 쓰지 않는다.** 홈·마이가 서로 다른 탭이라 오갈 때마다
/// 버려지고, 그때마다 `/users/me`를 다시 불러 이름과 연차에 로딩이 걸린다.
/// 사용자 정보는 그 사이에 바뀌지 않는다 — 바뀌는 순간(로그인·로그아웃·
/// 탈퇴·연차 저장)에 부르는 쪽이 무효화한다.
final currentUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
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
      // 프로필 사진(core #316) — 없으면 null이 실려 오고, 그때는 키를 만들지
      // 않아 마이 화면이 기본 아이콘을 그린다. Apple은 항상 null이다
      if (me['profileImageUrl'] case final String photo)
        'profileImageUrl': photo,
    };
  } on ApiException {
    return home;
  }
});
