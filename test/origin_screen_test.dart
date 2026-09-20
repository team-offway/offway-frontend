import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
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

  testWidgets('늦게 온 옛 검색 결과가 새 검색어의 목록에 뜨지 않는다', (tester) async {
    // 디바운스(300ms)가 끝나 요청이 나간 뒤 글자를 고치면, 그 사이 도착한
    // 옛 응답이 새 검색어 화면에 뜬다. 그때 누르면 엉뚱한 출발지가 잡힌다
    final slow = _SlowRepository();
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
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [originSearchRepositoryProvider.overrideWithValue(slow)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // '정선' 을 치고 디바운스가 끝나 요청이 나간다
    await tester.enterText(find.byType(TextField), '정선');
    await tester.pump(const Duration(milliseconds: 350));

    // 응답이 오기 전에 '서울' 로 고친다
    await tester.enterText(find.byType(TextField), '서울');
    await tester.pump();

    // 옛 응답('정선역')이 이제 도착한다
    slow.complete('정선', const [
      OriginHub(
        code: 'TRAIN:NAT610226',
        name: '정선역',
        area: '강원',
        kind: 'TRAIN_STATION',
      ),
    ]);
    await tester.pump();

    // 화면 어디에도 없어야 한다. ListView 안으로 한정하면, 목록이 아예
    // 안 그려진 경우에도 통과해 버려 무엇을 재는지 흐려진다
    expect(
      find.text('정선역'),
      findsNothing,
      reason: "'서울' 을 친 화면에 '정선' 의 결과가 남으면 안 된다",
    );

    // 새 검색어의 응답은 정상으로 뜬다 — 위 단언이 '아무것도 안 뜬다' 로
    // 통과하는 것이 아님을 못박는다.
    // '서울' 의 디바운스가 끝나야 그 요청이 나간다
    await tester.pump(const Duration(milliseconds: 350));
    slow.complete('서울', const [
      OriginHub(
        code: 'TRAIN:NAT010000',
        name: '서울역',
        area: '서울',
        kind: 'TRAIN_STATION',
      ),
    ]);
    await tester.pump();

    expect(find.text('서울역'), findsOneWidget);
  });

  testWidgets('검색어가 이름 가운데 있어도 그 부분만 굵다', (tester) async {
    // '충주' 를 치면 서충주터미널·건국대(충주)터미널도 함께 온다. 앞자리만
    // 보면 이 둘은 통째로 옅어져, 왜 걸렸는지 알 수 없는 줄이 된다
    final repo = _NamedRepository(const [
      OriginHub(
        code: 'TRAIN:A',
        name: '충주역',
        area: '충북',
        kind: 'TRAIN_STATION',
      ),
      OriginHub(
        code: 'BUS:B',
        name: '서충주터미널',
        area: '충북',
        kind: 'BUS_TERMINAL',
      ),
      OriginHub(
        code: 'BUS:C',
        name: '건국대(충주)터미널',
        area: '충북',
        kind: 'BUS_TERMINAL',
      ),
    ]);
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

    await tester.enterText(find.byType(TextField), '충주');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    /// 그 줄에서 굵게 그려진 조각들
    List<String> boldPartsOf(String name) {
      final widget = tester.widget<Text>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byWidgetPredicate(
            (w) => w is Text && w.textSpan?.toPlainText() == name,
          ),
        ),
      );
      final root = widget.textSpan! as TextSpan;
      return [
        for (final child in root.children ?? const <InlineSpan>[])
          if (child is TextSpan &&
              (child.text ?? '').isNotEmpty &&
              child.style?.fontWeight ==
                  AppTypography.body1NormalBold.fontWeight)
            child.text!,
      ];
    }

    expect(boldPartsOf('충주역'), ['충주']);
    expect(boldPartsOf('서충주터미널'), ['충주'], reason: '가운데 있어도 굵어야 한다');
    expect(boldPartsOf('건국대(충주)터미널'), ['충주'], reason: '괄호 안도 마찬가지다');
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

/// 검색어마다 응답을 붙잡아 두었다가 원할 때 돌려준다 — 늦게 온 응답을 만든다
class _SlowRepository extends OriginSearchRepository {
  _SlowRepository() : super(Dio());

  final _pending = <String, Completer<List<OriginHub>>>{};

  /// 취소로 이미 끝났을 수 있다 — 그 자체가 올바른 동작이라 조용히 넘어간다
  void complete(String query, List<OriginHub> hubs) {
    final c = _pending.remove(query);
    if (c != null && !c.isCompleted) c.complete(hubs);
  }

  @override
  Future<List<OriginHub>> search(String query, {CancelToken? cancelToken}) {
    final trimmed = query.trim();
    if (trimmed.length < OriginSearchRepository.minQueryLength) {
      return Future.value(const []);
    }
    final completer = Completer<List<OriginHub>>();
    _pending[trimmed] = completer;
    // **취소를 대신 처리하지 않는다.** 대역이 빈 목록으로 끝내 버리면 화면이
    // 취소를 제대로 다루는지 재지 못한다 — 실제 저장소는 취소된 요청에
    // 빈 목록을 돌려주고, 그 판단은 화면이 아니라 저장소의 몫이다.
    // 여기서는 응답이 **그대로 도착하는** 상황을 만들어 화면을 시험한다
    return completer.future;
  }
}

/// 정해 준 목록을 그대로 돌려준다
class _NamedRepository extends OriginSearchRepository {
  _NamedRepository(this.hubs) : super(Dio());

  final List<OriginHub> hubs;

  @override
  Future<List<OriginHub>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    if (query.trim().length < OriginSearchRepository.minQueryLength) {
      return const [];
    }
    return hubs;
  }
}
