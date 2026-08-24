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
  final homeFuture = ref.watch(homeUserProvider.future);

  final token = await ref.watch(secureStorageProvider).accessToken;
  if (token == null) return homeFuture;

  // 홈과 /users/me는 서로를 기다릴 이유가 없다 — 홈을 기다린 뒤 me를
  // 부르면 이름·연차가 한 왕복(0.3초) 늦게 뜬다. 함께 띄우고 함께 기다린다.
  //
  // 실패 처리는 **만들자마자** 붙인다. 홈을 기다리는 사이에 me가 먼저
  // 실패하면 듣는 이가 없는 오류가 되어 '처리되지 않은 예외'로 샌다.
  // 실패하면 null — 이름을 못 부르는 것뿐이라 화면을 막을 일이 아니다
  final meFuture = ref
      .watch(authRepositoryProvider)
      .me()
      .then<Map<String, dynamic>?>(
        (me) => me,
        onError: (Object e) {
          if (e is ApiException) return null;
          throw e;
        },
      );
  final home = await homeFuture;
  final me = await meFuture;
  if (me == null) return home;

  return {
    ...home,
    // 서버가 주는 이름이 정본이다 — 홈의 '게스트'를 덮는다
    if (me['nickname'] case final String name) 'nickname': name,
    if (me['email'] case final String email) 'email': email,
    if (me['provider'] case final String provider) 'provider': provider,
    // 프로필 사진(core #316) — 없으면 null이 실려 오고, 그때는 키를 만들지
    // 않아 마이 화면이 기본 아이콘을 그린다. Apple은 항상 null이다
    if (me['profileImageUrl'] case final String photo) 'profileImageUrl': photo,
  };
});
