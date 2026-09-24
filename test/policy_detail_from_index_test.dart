import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/policy/data/policy_repository.dart';
import 'package:offway/features/policy/presentation/policy_detail_sheet.dart';

/// 혜택 상세 시트 — **받아 둔 정책으로 바로 열고, 서버 값이 오면 바꿔 낀다.**
///
/// 받아 둔 값만 쓰면(#373) 앱을 켜 둔 사이 운영진이 고친 신청 링크·기간이
/// 안 보였다. 서버만 기다리면 스피너가 떴다(#364). 둘 다 피한다.
class _Repository implements PolicyRepository {
  _Repository({this.name = '서버에서 받은 정책', this.gate, this.fail = false});

  final String name;
  final Completer<void>? gate;
  final bool fail;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> detail(int policyId) async {
    calls++;
    await gate?.future;
    if (fail) {
      throw const ApiException(status: 500, code: 'X', detail: '서버 오류');
    }
    return {'id': policyId, 'name': name};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  List<Override> overrides(_Repository repo, {bool withKnown = true}) => [
    policyRepositoryProvider.overrideWithValue(repo),
    if (withKnown)
      allPoliciesProvider.overrideWith(
        (ref) async => [
          {'id': 7, 'name': '받아 둔 정책'},
        ],
      ),
  ];

  Future<void> openSheet(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPolicyDetailSheet(context, 7),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('받아 둔 값으로 바로 열고, 서버 값이 오면 바꿔 낀다', (tester) async {
    final gate = Completer<void>();
    final repo = _Repository(name: '운영진이 고친 정책', gate: gate);
    final container = ProviderContainer(
      overrides: overrides(repo),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await container.read(allPoliciesProvider.future);

    await openSheet(tester, container);
    // 서버를 기다리는 동안에도 받아 둔 값이 보인다 — 스피너가 아니다
    expect(find.text('받아 둔 정책'), findsOneWidget);
    expect(repo.calls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('운영진이 고친 정책'), findsOneWidget);
    expect(find.text('받아 둔 정책'), findsNothing);
  });

  testWidgets('새로 받기가 실패해도 받아 둔 값이 남는다', (tester) async {
    final repo = _Repository(fail: true);
    final container = ProviderContainer(
      overrides: overrides(repo),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await container.read(allPoliciesProvider.future);

    await openSheet(tester, container);
    await tester.pumpAndSettle();
    expect(find.text('받아 둔 정책'), findsOneWidget);
  });

  test('목록을 아무도 안 읽었으면 묶음 읽기를 시작하지 않는다', () async {
    final repo = _Repository();
    final container = ProviderContainer(
      overrides: overrides(repo, withKnown: false),
    );
    addTearDown(container.dispose);

    expect(container.read(knownPolicyProvider(7)), isNull);
    await container.read(policyDetailProvider(7).future);

    expect(repo.calls, 1);
    expect(container.exists(allPoliciesProvider), isFalse);
  });
}
