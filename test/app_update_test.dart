import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/app_icon_button.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/course/application/pending_trip_provider.dart';
import 'package:offway/features/course/domain/pending_trip.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/policy/data/region_policies_provider.dart';
import 'package:offway/features/update/application/app_update_provider.dart';
import 'package:offway/features/update/data/app_store_listing_repository.dart';
import 'package:offway/features/update/data/update_prompt_snooze_storage.dart';
import 'package:offway/features/update/domain/app_update.dart';
import 'package:offway/features/update/presentation/update_prompt_sheet.dart';

/// 업데이트 모달 (시안 18932:73769) — 스토어에 더 새 버전이 있을 때 홈에서 한 번.
void main() {
  group('버전 비교', () {
    test('자리마다 숫자로 견준다 — 1.10.0은 1.9.0보다 새 버전이다', () {
      expect(
        AppVersion.tryParse('1.10.0')! > AppVersion.tryParse('1.9.0')!,
        isTrue,
      );
      expect(
        AppVersion.tryParse('1.0.3')! > AppVersion.tryParse('1.0.3')!,
        isFalse,
      );
      // 자릿수가 달라도 된다
      expect(
        AppVersion.tryParse('1.1')! > AppVersion.tryParse('1.0.9')!,
        isTrue,
      );
    });

    test('빌드 번호는 안 본다, 못 읽으면 null', () {
      expect(AppVersion.tryParse('1.0.3+30').toString(), '1.0.3');
      expect(AppVersion.tryParse('abc'), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });
  });

  group('업데이트 판단', () {
    test('스토어가 더 새면 업데이트, 같거나 낮으면 없음', () {
      final update = decideUpdate(
        currentVersion: '1.0.3',
        storeVersion: '1.0.4',
        storeUrl: 'https://apps.apple.com/kr/app/id1',
      );
      expect(update?.storeVersion, '1.0.4');
      expect(
        decideUpdate(
          currentVersion: '1.0.3',
          storeVersion: '1.0.3',
          storeUrl: 'u',
        ),
        isNull,
      );
      // TestFlight 빌드가 스토어보다 새롭다 — 묻지 않는다
      expect(
        decideUpdate(
          currentVersion: '1.0.5',
          storeVersion: '1.0.4',
          storeUrl: 'u',
        ),
        isNull,
      );
    });

    test('스토어에 없으면(심사 전) 묻지 않는다', () {
      expect(
        decideUpdate(
          currentVersion: '1.0.3',
          storeVersion: null,
          storeUrl: null,
        ),
        isNull,
      );
    });
  });

  group('스토어 조회', () {
    Future<({String version, String url})?> lookup(
      String body, {
      int status = 200,
      String contentType = 'text/javascript',
    }) {
      final dio = Dio(BaseOptions(baseUrl: 'https://itunes.apple.com'));
      dio.httpClientAdapter = _StubAdapter(body, status, contentType);
      return AppStoreListingRepository(dio).latest();
    }

    test('버전과 스토어 주소를 읽는다 — 문자열 본문도', () async {
      final listing = await lookup(
        '{"resultCount":1,"results":[{"version":"1.0.4",'
        '"trackViewUrl":"https://apps.apple.com/kr/app/id1"}]}',
      );
      expect(listing?.version, '1.0.4');
      expect(listing?.url, 'https://apps.apple.com/kr/app/id1');
    });

    test('스토어에 없으면 null, 못 부르면 null', () async {
      expect(await lookup('{"resultCount":0,"results":[]}'), isNull);
      expect(await lookup('오류', status: 500), isNull);
    });
  });

  group('시트', () {
    Future<UpdatePromptAnswer?> Function() pumpSheet(WidgetTester tester) {
      UpdatePromptAnswer? answer;
      var done = false;
      return () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    answer = await showUpdatePromptSheet(context);
                    done = true;
                  },
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(done, isFalse);
        return answer;
      };
    }

    testWidgets('제목·문구·버튼 둘이 있다', (tester) async {
      await pumpSheet(tester)();
      expect(find.text('업데이트 알림'), findsOneWidget);
      expect(find.text('새로 추가된 기능을\n앱 업데이트를 통해 바로 만나보세요.'), findsOneWidget);
      expect(find.text('업데이트'), findsOneWidget);
      expect(find.text('나중에'), findsOneWidget);
    });

    testWidgets("'업데이트'와 '나중에'가 답을 돌려주고, 닫기는 null이다", (tester) async {
      UpdatePromptAnswer? answer;
      Future<void> open(String tapLabel) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      answer = await showUpdatePromptSheet(context),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(tapLabel));
        await tester.pumpAndSettle();
      }

      await open('업데이트');
      expect(answer, UpdatePromptAnswer.update);
      await open('나중에');
      expect(answer, UpdatePromptAnswer.later);
      // 닫기(X) — 글자가 없는 아이콘 버튼이라 위젯으로 찾는다
      answer = UpdatePromptAnswer.update;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    answer = await showUpdatePromptSheet(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.semanticLabel == '닫기',
        ),
      );
      await tester.pumpAndSettle();
      expect(answer, isNull);
    });
  });

  group('홈에서', () {
    late _FakeSnooze snooze;

    Future<void> pump(
      WidgetTester tester, {
      AppUpdate? update = const AppUpdate(
        storeVersion: '1.0.4',
        storeUrl: 'https://apps.apple.com/kr/app/id1',
      ),
      PendingTrip? trip,
    }) async {
      snooze = _FakeSnooze();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) async => {'nickname': '영찬', 'remainingLeaveDays': 12.0},
            ),
            homeSnapshotProvider.overrideWith(
              (ref) async => const HomeSnapshot(
                user: {'remainingLeaveDays': 12.0},
                regions: [],
              ),
            ),
            pendingTripProvider.overrideWith((ref) async => trip),
            regionPoliciesProvider.overrideWith((ref) async => {}),
            availableUpdateProvider.overrideWith((ref) async => update),
            updatePromptSnoozeProvider.overrideWithValue(snooze),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('새 버전이 있으면 시트가 뜨고, 나중에를 누르면 오늘 하루 접는다', (tester) async {
      await pump(tester);
      expect(find.text('업데이트 알림'), findsOneWidget);

      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();

      expect(find.text('업데이트 알림'), findsNothing);
      expect(snooze.snoozed, ['1.0.4']);
    });

    testWidgets('오늘 이미 미뤘으면 안 뜬다', (tester) async {
      snooze = _FakeSnooze();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) async => {'nickname': '영찬', 'remainingLeaveDays': 12.0},
            ),
            homeSnapshotProvider.overrideWith(
              (ref) async => const HomeSnapshot(
                user: {'remainingLeaveDays': 12.0},
                regions: [],
              ),
            ),
            pendingTripProvider.overrideWith((ref) async => null),
            regionPoliciesProvider.overrideWith((ref) async => {}),
            availableUpdateProvider.overrideWith(
              (ref) async =>
                  const AppUpdate(storeVersion: '1.0.4', storeUrl: 'u'),
            ),
            updatePromptSnoozeProvider.overrideWithValue(
              snooze..snoozedToday.add('1.0.4'),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('업데이트 알림'), findsNothing);
    });

    testWidgets('후보 여행이 있어도 아직 물을 때가 아니면 업데이트 시트는 뜬다', (tester) async {
      // 어제 끝난 여행은 오늘 20시 전엔 안 묻는다 — 그렇다고 업데이트까지
      // 막으면 아무것도 안 뜬다(실기기에서 그랬다)
      final today = DateTime.now();
      await pump(
        tester,
        trip: PendingTrip(
          courseId: 1,
          regionName: '횡성군',
          startDate: today.subtract(const Duration(days: 1)),
          endDate: today,
          consumedLeaveDays: 1,
        ),
      );
      expect(find.text('업데이트 알림'), findsOneWidget);
    });

    testWidgets('"다녀오셨나요?"가 떠 있으면 업데이트 시트는 물러난다', (tester) async {
      final today = DateTime.now();
      await pump(
        tester,
        trip: PendingTrip(
          courseId: 1,
          regionName: '횡성군',
          startDate: today.subtract(const Duration(days: 5)),
          endDate: today.subtract(const Duration(days: 3)),
          consumedLeaveDays: 1,
        ),
      );
      expect(find.textContaining('다녀오셨나요'), findsOneWidget);
      expect(find.text('업데이트 알림'), findsNothing);
    });

    testWidgets('새 버전이 없으면 안 뜬다', (tester) async {
      await pump(tester, update: null);
      expect(find.text('업데이트 알림'), findsNothing);
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, this.status, this.contentType);
  final String body;
  final int status;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [contentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Keychain 대신 메모리 — 미룬 버전을 기록만 한다
class _FakeSnooze extends UpdatePromptSnoozeStorage {
  _FakeSnooze() : super(const FlutterSecureStorage());

  final snoozed = <String>[];
  final snoozedToday = <String>{};

  @override
  Future<bool> isSnoozedToday(String version, DateTime today) async =>
      snoozedToday.contains(version);

  @override
  Future<void> snooze(String version, DateTime today) async =>
      snoozed.add(version);
}
