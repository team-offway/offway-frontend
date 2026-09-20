import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course_wizard/application/course_wizard_provider.dart';
import 'package:offway/features/course_wizard/data/origin_search_repository.dart';
import 'package:offway/features/course_wizard/domain/origin_hub.dart';
import 'package:offway/features/course_wizard/presentation/origin_screen.dart';

/// 출발지 화면 — **고른 것만 다음으로 넘어간다** (core #591).
///
/// 서버는 `originCode` 로 좌표를 해석한다. 친 글자를 그대로 넘기면 코드가
/// 없어 400 이거나 기본 출발지(서울역)로 조용히 떨어진다 — 고른 것과
/// 친 것을 가르는 자리가 이 화면이다.
void main() {
  late _RecordingRepository repo;

  Future<void> pumpScreen(WidgetTester tester) async {
    repo = _RecordingRepository();
    final router = GoRouter(
      initialLocation: AppRoutes.wizardOrigin,
      routes: [
        GoRoute(
          path: AppRoutes.wizardOrigin,
          builder: (_, _) => const OriginScreen(),
        ),
        GoRoute(
          path: AppRoutes.wizardDateGate,
          builder: (_, _) => const Text('날짜 갈림길'),
        ),
        GoRoute(path: AppRoutes.home, builder: (_, _) => const Text('홈')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [originSearchRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 손이 멈춘 뒤에야 검색이 나간다
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  testWidgets('시안 문구와 비활성 버튼으로 시작한다', (tester) async {
    await pumpScreen(tester);

    expect(find.text('출발지를 입력해주세요'), findsOneWidget);
    expect(find.text('출발지부터 이동 시간을 고려해\n여행지를 추천해드려요.'), findsOneWidget);
    expect(find.text('어디서 출발할까요?'), findsOneWidget); // placeholder
    expect(find.text('1/5'), findsOneWidget);

    final next = find.widgetWithText(FilledButton, '다음');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
  });

  testWidgets('두 글자 미만은 검색하지 않는다', (tester) async {
    await pumpScreen(tester);
    await type(tester, '정');

    expect(repo.queries, isEmpty);
  });

  testWidgets('치면 목록이 뜨고, 고르면 닫히며 다음이 켜진다', (tester) async {
    await pumpScreen(tester);
    await type(tester, '정선');

    expect(repo.queries, ['정선']);
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('정선터미널')),
      findsOneWidget,
    );

    await tester.tap(find.text('정선터미널'));
    await tester.pumpAndSettle();

    // 고른 뒤에는 목록을 닫는다 — 끝난 선택을 다시 고르라는 화면이 된다.
    // 고른 이름은 입력칸에 남으므로 목록 셀(InkWell)만 세어야 한다
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('정선터미널')),
      findsNothing,
    );
    expect(find.text('정선역'), findsNothing);
    final next = find.widgetWithText(FilledButton, '다음');
    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
  });

  testWidgets('고른 뒤 글자를 고치면 다음이 다시 꺼진다', (tester) async {
    // 고친 글자는 코드가 없다. 켜 둔 채 넘기면 서버가 엉뚱한 곳에서 잰다
    await pumpScreen(tester);
    await type(tester, '정선');
    await tester.tap(find.text('정선역'));
    await tester.pumpAndSettle();

    await type(tester, '정선역앞');

    final next = find.widgetWithText(FilledButton, '다음');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
  });

  testWidgets('고른 출발지가 위저드에 코드로 남는다', (tester) async {
    late WidgetRef capturedRef;
    repo = _RecordingRepository();
    final router = GoRouter(
      initialLocation: AppRoutes.wizardOrigin,
      routes: [
        GoRoute(
          path: AppRoutes.wizardOrigin,
          builder: (_, _) => Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const OriginScreen();
            },
          ),
        ),
        GoRoute(
          path: AppRoutes.wizardDateGate,
          builder: (_, _) => const Text('날짜 갈림길'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [originSearchRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await type(tester, '정선');
    await tester.tap(find.text('정선역'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await tester.pumpAndSettle();

    expect(find.text('날짜 갈림길'), findsOneWidget);
    // 앱은 좌표를 갖지 않는다 — 코드만 들고 간다
    expect(
      capturedRef.read(courseWizardProvider).origin?.code,
      'TRAIN:NAT610226',
    );
  });

  testWidgets('검색이 실패해도 화면이 멈추지 않는다', (tester) async {
    await pumpScreen(tester);
    repo.fail = true;
    await type(tester, '정선');

    expect(tester.takeException(), isNull);
    final next = find.widgetWithText(FilledButton, '다음');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
  });
}

class _RecordingRepository extends OriginSearchRepository {
  _RecordingRepository() : super(Dio());

  final queries = <String>[];
  bool fail = false;

  @override
  Future<List<OriginHub>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    if (query.trim().length < OriginSearchRepository.minQueryLength) {
      return const [];
    }
    queries.add(query.trim());
    if (fail) throw Exception('서버가 답하지 않았다');
    return const [
      OriginHub(
        code: 'TRAIN:NAT610226',
        name: '정선역',
        area: '강원',
        kind: 'TRAIN_STATION',
      ),
      OriginHub(
        code: 'BUS:NAEK222',
        name: '정선터미널',
        area: '강원',
        kind: 'BUS_TERMINAL',
      ),
    ];
  }
}
