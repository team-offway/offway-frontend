import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/storage/secure_storage.dart';
import 'package:offway/features/auth/data/auth_repository.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/my/application/my_profile_provider.dart';

/// 마이 화면 프로필 — 로그인 상태에서는 서버 이름이 홈의 '게스트'를 덮는다.
///
/// `/home`의 `user.name`은 비회원까지 아우르는 값이라 로그인해도 '게스트'가
/// 온다(core `HomeResponse.GUEST_NAME`). 그래서 `/users/me`를 따로 묻는다.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.profile, this.fails = false});

  final Map<String, dynamic>? profile;
  final bool fails;

  @override
  Future<Map<String, dynamic>> me() async {
    if (fails) {
      throw const ApiException(status: 401, code: 'USER-006', detail: '탈퇴함');
    }
    return profile!;
  }

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

  ProviderContainer containerWith({
    required Map<String, dynamic> home,
    Map<String, dynamic>? me,
    bool fails = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        homeSnapshotProvider.overrideWith(
          (ref) async => HomeSnapshot(user: home, regions: const []),
        ),
        secureStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(profile: me, fails: fails),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('로그인하지 않았으면 서버에 묻지 않는다', () async {
    // 토큰이 없으면 401이 뻔하다 — 부를 이유가 없다
    final container = containerWith(home: {'name': '게스트'});

    final profile = await container.read(myProfileProvider.future);
    expect(profile['name'], '게스트');
    expect(profile.containsKey('nickname'), isFalse);
  });

  test('로그인했으면 서버 닉네임이 홈의 게스트를 덮는다', () async {
    await storage.saveTokens(accessToken: 'jwt');
    final container = containerWith(
      home: {'name': '게스트', 'remainingLeaveDays': 3.5},
      me: {'nickname': '영찬', 'email': 'a@b.com', 'provider': 'KAKAO'},
    );

    final profile = await container.read(myProfileProvider.future);
    expect(profile['nickname'], '영찬');
    expect(profile['email'], 'a@b.com');
    // 홈이 준 값은 그대로 남는다
    expect(profile['remainingLeaveDays'], 3.5);
  });

  test('조회에 실패해도 홈 값으로 화면을 채운다', () async {
    // 이름을 못 부르는 것뿐이라 화면을 막을 일이 아니다
    await storage.saveTokens(accessToken: 'jwt');
    final container = containerWith(
      home: {'name': '게스트', 'remainingLeaveDays': 3.5},
      fails: true,
    );

    final profile = await container.read(myProfileProvider.future);
    expect(profile['remainingLeaveDays'], 3.5);
    expect(profile.containsKey('nickname'), isFalse);
  });

  test('서버가 이메일을 안 주면 그 칸을 만들지 않는다', () async {
    // 카카오 미동의·개발 로그인은 null이 온다 — 빈 문자열로 채우면
    // 화면이 빈 줄을 그린다
    await storage.saveTokens(accessToken: 'jwt');
    final container = containerWith(
      home: {'name': '게스트'},
      me: {'nickname': '영찬', 'email': null, 'provider': null},
    );

    final profile = await container.read(myProfileProvider.future);
    expect(profile['nickname'], '영찬');
    expect(profile.containsKey('email'), isFalse);
    expect(profile.containsKey('provider'), isFalse);
  });
}
