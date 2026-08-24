import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/storage/secure_storage.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/auth/data/auth_repository.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';

/// 로그인 상태가 바뀌면 사용자 정보를 다시 읽는지 고정한다.
///
/// currentUserProvider는 autoDispose가 아니다 — 탭을 오갈 때마다 다시
/// 불러 로딩이 걸리기 때문. 대신 **바뀌는 순간에 무효화**해야 하고,
/// 빠뜨리면 로그인해도 '게스트'가 남는다.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.nickname, {this.photo});

  final String nickname;
  final String? photo;

  @override
  Future<Map<String, dynamic>> me() async => {
    'nickname': nickname,
    // 서버는 없으면 null을 실어 보낸다(core #316)
    'profileImageUrl': photo,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = TokenStorage(const FlutterSecureStorage());
  });

  ProviderContainer containerWith(String nickname, {String? photo}) {
    final container = ProviderContainer(
      overrides: [
        homeSnapshotProvider.overrideWith(
          (ref) async => const HomeSnapshot(
            user: {'name': '게스트', 'remainingLeaveDays': 10.0},
            regions: [],
          ),
        ),
        secureStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(nickname, photo: photo),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('로그인 전에는 홈이 준 게스트가 그대로다', () async {
    final container = containerWith('영찬');

    final before = await container.read(currentUserProvider.future);
    expect(before['name'], '게스트');
    expect(before.containsKey('nickname'), isFalse);
  });

  test('토큰이 생긴 뒤 무효화하면 진짜 이름을 읽는다', () async {
    // 로그인 화면이 이 무효화를 빼먹으면 로그인해도 '게스트'가 남는다
    final container = containerWith('영찬');

    await container.read(currentUserProvider.future);
    await storage.saveTokens(accessToken: 'jwt');
    container.invalidate(currentUserProvider);

    final after = await container.read(currentUserProvider.future);
    expect(after['nickname'], '영찬');
  });

  test('무효화하지 않으면 옛 값이 남는다', () async {
    // 이 테스트가 '왜 무효화가 필요한가'를 적어 둔다
    final container = containerWith('영찬');

    await container.read(currentUserProvider.future);
    await storage.saveTokens(accessToken: 'jwt');

    final after = await container.read(currentUserProvider.future);
    expect(after.containsKey('nickname'), isFalse);
  });

  test('토큰을 지우고 무효화하면 게스트로 돌아간다', () async {
    // 로그아웃·탈퇴가 이 경로다 — 다음 사람이 옛 이름으로 인사받으면 안 된다
    await storage.saveTokens(accessToken: 'jwt');
    final container = containerWith('영찬');

    expect(
      (await container.read(currentUserProvider.future))['nickname'],
      '영찬',
    );

    await storage.clear();
    container.invalidate(currentUserProvider);

    final after = await container.read(currentUserProvider.future);
    expect(after.containsKey('nickname'), isFalse);
  });

  test('프로필 사진이 오면 옮기고, null이면 키를 만들지 않는다', () async {
    await storage.saveTokens(accessToken: 'a', refreshToken: 'r');

    final withPhoto = containerWith('영찬', photo: 'http://p/1.jpg');
    final user = await withPhoto.read(currentUserProvider.future);
    expect(user['profileImageUrl'], 'http://p/1.jpg');

    // Apple처럼 사진이 없는 계정 — 마이 화면이 기본 아이콘으로 가야 한다
    final without = containerWith('영찬');
    final bare = await without.read(currentUserProvider.future);
    expect(bare.containsKey('profileImageUrl'), isFalse);
  });
}
