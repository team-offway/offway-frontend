import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/dio_client.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/storage/secure_storage.dart';
import 'package:offway/features/auth/data/auth_repository.dart';

/// 메모리에만 담는 토큰 저장소 — Keychain 플러그인이 없는 테스트 환경용
class _MemoryStorage implements TokenStorage {
  String? access;
  String? refresh;

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    access = accessToken;
    if (refreshToken != null) refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 요청을 서버까지 보내지 않고 미리 정한 답을 돌려주는 어댑터
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  /// 경로별 응답을 정하는 함수. 호출된 순서를 [calls]에 남긴다
  final ResponseBody Function(RequestOptions options) respond;
  final calls = <String>[];

  /// 실제로 실린 Authorization 헤더 — 요청 순서대로
  final authorizations = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.path);
    authorizations.add(options.headers['Authorization'] as String?);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      '{"status":$status,"data":${_encode(body)},"detail":"","code":"OK"}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

String _encode(Map<String, dynamic> m) =>
    '{${m.entries.map((e) {
      final v = e.value;
      final encoded = v is String ? '"$v"' : '$v';
      return '"${e.key}":$encoded';
    }).join(',')}}';

void main() {
  group('로그인 응답', () {
    test('isNewUser를 그대로 읽는다 — 온보딩/홈 분기의 근거다', () {
      expect(
        AuthTokens.fromJson({'accessToken': 'a', 'isNewUser': true}).isNewUser,
        isTrue,
      );
      // 서버가 값을 빼먹으면 기존 사용자로 본다 — 새 사용자를 홈으로 보내는
      // 쪽이 기존 사용자를 온보딩으로 되돌리는 것보다 덜 나쁘다
      expect(AuthTokens.fromJson({'accessToken': 'a'}).isNewUser, isFalse);
    });

    test('토큰 쌍을 저장한다', () async {
      final storage = _MemoryStorage();
      final adapter = _StubAdapter(
        (_) => _json(200, {
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
          'isNewUser': true,
        }),
      );
      final dio = Dio()..httpClientAdapter = adapter;

      final tokens = await AuthRepository(
        dio,
        storage,
      ).loginWithSocial(SocialProvider.kakao, 'social-token');

      expect(tokens.isNewUser, isTrue);
      expect(storage.access, 'new-access');
      expect(storage.refresh, 'new-refresh');
    });
  });

  group('재발급', () {
    test('회전된 리프레시 토큰을 반드시 저장한다', () async {
      // 옛 값을 다시 쓰면 서버가 재사용으로 보고 계정 토큰을 전부 끊는다
      final storage = _MemoryStorage()
        ..access = 'old-access'
        ..refresh = 'old-refresh';
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter(
          (_) => _json(200, {
            'accessToken': 'rotated-access',
            'refreshToken': 'rotated-refresh',
          }),
        );

      final tokens = await AuthRepository(dio, storage).reissue();

      expect(tokens, isNotNull);
      expect(storage.access, 'rotated-access');
      expect(storage.refresh, 'rotated-refresh');
    });

    test('리프레시가 없으면 서버를 부르지 않는다', () async {
      final adapter = _StubAdapter((_) => _json(200, {}));
      final dio = Dio()..httpClientAdapter = adapter;

      final tokens = await AuthRepository(dio, _MemoryStorage()).reissue();

      expect(tokens, isNull);
      expect(adapter.calls, isEmpty);
    });

    test('재발급이 거절되면 토큰을 비운다 — 안 그러면 401을 되풀이한다', () async {
      final storage = _MemoryStorage()
        ..access = 'dead'
        ..refresh = 'dead';
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((_) => _json(401, {}));

      final tokens = await AuthRepository(dio, storage).reissue();

      expect(tokens, isNull);
      expect(storage.access, isNull);
      expect(storage.refresh, isNull);
    });

    test('네트워크가 끊기면 토큰을 지키다', () async {
      // 지하철에서 잠깐 끊긴 것뿐인데 60일짜리 리프레시까지 버리면,
      // 멀쩡한 세션을 두고 로그인 화면으로 튕긴다
      final storage = _MemoryStorage()
        ..access = 'alive'
        ..refresh = 'alive';
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((options) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: '끊김',
          );
        });

      final tokens = await AuthRepository(dio, storage).reissue();

      expect(tokens, isNull, reason: '이번에는 못 되살렸다');
      expect(storage.refresh, 'alive', reason: '토큰은 성하다 — 다음에 다시 시도한다');
    });

    test('서버가 5xx면 토큰을 지키다', () async {
      // 서버 사정이지 토큰 문제가 아니다
      final storage = _MemoryStorage()
        ..access = 'alive'
        ..refresh = 'alive';
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((_) => _json(503, {}));

      final tokens = await AuthRepository(dio, storage).reissue();

      expect(tokens, isNull);
      expect(storage.refresh, 'alive');
    });

    test('403도 거절로 보고 비운다', () async {
      // 서버가 폐기했거나 재사용을 감지한 경우다
      final storage = _MemoryStorage()
        ..access = 'dead'
        ..refresh = 'dead';
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((_) => _json(403, {}));

      await AuthRepository(dio, storage).reissue();

      expect(storage.refresh, isNull);
    });
  });

  group('401 인터셉터', () {
    test('토큰을 되살려 원래 요청을 한 번 다시 보낸다', () async {
      final storage = _MemoryStorage()..access = 'expired';
      var refreshed = false;
      var attempt = 0;

      final adapter = _StubAdapter((options) {
        attempt++;
        // 첫 시도는 만료로 막고, 되살린 뒤에는 통과시킨다
        if (attempt == 1) return _json(401, {});
        return _json(200, {'ok': 'yes'});
      });

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          tokenRefresherProvider.overrideWith(
            (ref) => () async {
              refreshed = true;
              storage.access = 'fresh';
              return true;
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final dio = container.read(dioProvider)..httpClientAdapter = adapter;
      final response = await dio.get<dynamic>('/api/v1/leaves/me');

      expect(refreshed, isTrue);
      expect(response.statusCode, 200);
      expect(adapter.calls, hasLength(2), reason: '원래 요청 + 재시도');
    });

    test('되살리지 못하면 401을 그대로 올린다', () async {
      final adapter = _StubAdapter((_) => _json(401, {}));
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(
            _MemoryStorage()..access = 'expired',
          ),
          // 기본값 — 되살릴 수 없다
        ],
      );
      addTearDown(container.dispose);

      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/api/v1/leaves/me'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      // 재시도하지 않았다 — 되살릴 방법이 없으면 되풀이가 무의미하다
      expect(adapter.calls, hasLength(1));
    });
  });

  group('로그아웃', () {
    test('Bearer를 실어 서버의 refresh 폐기에 닿는다 (#142)', () async {
      // 예전에는 kSkipAuthKey가 헤더 자체를 빼 버려 Basic(403)이나
      // 무헤더(401)로 컨트롤러에 닿지 못했다 — refresh 토큰이 60일 살아 있었다
      final storage = _MemoryStorage()
        ..access = 'live'
        ..refresh = 'live-refresh';
      final adapter = _StubAdapter((_) => _json(200, {}));
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      await AuthRepository(dio, storage).logout();

      expect(adapter.calls, ['/api/v1/auth/logout']);
      expect(adapter.authorizations.single, 'Bearer live');
      // 서버 폐기와 별개로 로컬은 비운다
      expect(storage.access, isNull);
      expect(storage.refresh, isNull);
    });

    test('만료된 토큰이면 401을 맞아도 재발급·만료 신호 없이 로컬만 비운다', () async {
      // 이미 못 쓰는 세션이다. 재발급을 돌리면 스스로 나간 사람에게
      // '세션이 만료됐어요'가 뜬다
      final storage = _MemoryStorage()..access = 'expired';
      final adapter = _StubAdapter((_) => _json(401, {}));
      var refreshAttempted = false;
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          tokenRefresherProvider.overrideWith(
            (ref) => () async {
              refreshAttempted = true;
              return false;
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      await AuthRepository(dio, storage).logout();

      expect(refreshAttempted, isFalse);
      expect(container.read(sessionExpiredProvider), isFalse);
      expect(adapter.calls, hasLength(1), reason: '재시도 없음');
      expect(storage.access, isNull);
    });
  });

  group('세션 만료 신호', () {
    test('되살리지 못한 401 이면 신호를 올린다', () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(
            _MemoryStorage()..access = 'expired',
          ),
          // 기본값 — 되살릴 수 없다
        ],
      );
      addTearDown(container.dispose);

      final dio = container.read(dioProvider)
        ..httpClientAdapter = _StubAdapter((_) => _json(401, {}));

      expect(container.read(sessionExpiredProvider), isFalse);
      await dio
          .get<dynamic>('/api/v1/leaves/me')
          .catchError(
            (_) => Response<dynamic>(requestOptions: RequestOptions()),
          );

      // 이 신호가 없으면 화면이 오류만 띄운 채 멈춘다
      expect(container.read(sessionExpiredProvider), isTrue);
    });

    test('네트워크 탓에 못 되살렸으면 만료라 하지 않는다', () async {
      // 재발급이 실패했다고 늘 만료는 아니다. 서버가 거절했으면 토큰이
      // 지워지고, 끊긴 것뿐이면 남는다 — 그 차이로 가른다
      final storage = _MemoryStorage()
        ..access = 'expired'
        ..refresh = 'alive';
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          // 되살리지는 못했지만 토큰은 건드리지 않았다 (끊김·5xx)
          tokenRefresherProvider.overrideWith(
            (ref) =>
                () async => false,
          ),
        ],
      );
      addTearDown(container.dispose);

      final dio = container.read(dioProvider)
        ..httpClientAdapter = _StubAdapter((_) => _json(401, {}));

      await dio
          .get<dynamic>('/api/v1/leaves/me')
          .catchError(
            (_) => Response<dynamic>(requestOptions: RequestOptions()),
          );

      expect(
        container.read(sessionExpiredProvider),
        isFalse,
        reason: '멀쩡한 세션을 두고 로그인 화면으로 보내면 안 된다',
      );
    });

    test('되살렸으면 신호를 올리지 않는다', () async {
      final storage = _MemoryStorage()..access = 'expired';
      var attempt = 0;
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          tokenRefresherProvider.overrideWith(
            (ref) => () async {
              storage.access = 'fresh';
              return true;
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final dio = container.read(dioProvider)
        ..httpClientAdapter = _StubAdapter((_) {
          attempt++;
          return attempt == 1 ? _json(401, {}) : _json(200, {});
        });

      await dio.get<dynamic>('/api/v1/leaves/me');

      expect(container.read(sessionExpiredProvider), isFalse);
    });
  });

  group('앱 시작 경로', () {
    test('첫 화면은 스플래시다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(initialRouteProvider), AppRoutes.splash);
    });

    test('로그인 전이면 스플래시 다음은 소개 화면이다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(postSplashRouteProvider),
        AppRoutes.onboardingIntro,
      );
    });

    test('토큰이 있으면 스플래시 다음이 홈이다 — main이 이 값을 덮어쓴다', () {
      // 앱을 켤 때마다 로그인 버튼을 다시 누르게 하면 안 된다
      final container = ProviderContainer(
        overrides: [postSplashRouteProvider.overrideWithValue(AppRoutes.home)],
      );
      addTearDown(container.dispose);
      expect(
        container.read(appRouterProvider).configuration.routes,
        isNotEmpty,
      );
      expect(container.read(postSplashRouteProvider), AppRoutes.home);
      // 첫 화면은 여전히 스플래시다 — 목적지만 바뀐다
      expect(container.read(initialRouteProvider), AppRoutes.splash);
    });
  });
}
