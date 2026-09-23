import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/policy/data/region_policies_provider.dart';

/// 정책 상세를 묶음으로 **한꺼번에** 읽는다.
///
/// 하나씩 기다리면 왕복이 id 수만큼 쌓인다 — 정책 6개를 받는 데 10번을 불러
/// 2.6초였다. 같은 10번을 같이 띄우면 0.7초다. 요청 수는 그대로다.
void main() {
  const notFound = ApiException(status: 404, code: 'NOT_FOUND', detail: '없음');
  const serverError = ApiException(status: 500, code: 'ERR', detail: '서버 오류');

  Map<String, dynamic> policy(int id) => {
    'id': id,
    'badgeText': '혜택 $id',
    'regions': const <Object>[],
  };

  /// id 마다 미리 정한 답을 주고, 어느 순서로 불렸는지 남긴다.
  /// 답이 없는 id 는 404 다
  Future<Map<String, dynamic>> Function(int) detailOf(
    Map<int, Object> answers,
    List<int> called,
  ) => (id) async {
    called.add(id);
    final answer = answers[id] ?? notFound;
    if (answer is ApiException) throw answer;
    return answer as Map<String, dynamic>;
  };

  test('한 묶음은 한꺼번에 띄운다 — 첫 답이 오기 전에 열 개가 나가 있다', () async {
    final called = <int>[];
    final pending = <int, Completer<Map<String, dynamic>>>{};
    Future<Map<String, dynamic>> detail(int id) {
      called.add(id);
      return (pending[id] = Completer()).future;
    }

    final result = fetchPoliciesInBatches(detail);
    await Future<void>.delayed(Duration.zero);
    expect(
      called,
      List.generate(10, (i) => i + 1),
      reason: '하나씩 기다렸다면 1 하나만 나가 있다',
    );

    for (var id = 1; id <= 6; id++) {
      pending[id]!.complete(policy(id));
    }
    for (var id = 7; id <= 10; id++) {
      pending[id]!.completeError(notFound);
    }
    expect((await result).map((p) => p['id']), [1, 2, 3, 4, 5, 6]);
  });

  test('404 가 셋 이어지면 다음 묶음은 읽지 않는다', () async {
    final called = <int>[];
    final policies = await fetchPoliciesInBatches(
      detailOf({for (var i = 1; i <= 6; i++) i: policy(i)}, called),
    );
    expect(policies.length, 6);
    expect(called.length, 10, reason: '요청 수는 순차 때와 같다 — 순서만 바꿨다');
  });

  test('묶음이 다 차면 다음 묶음도 읽는다', () async {
    final called = <int>[];
    final policies = await fetchPoliciesInBatches(
      detailOf({for (var i = 1; i <= 10; i++) i: policy(i)}, called),
    );
    expect(policies.length, 10);
    expect(called.length, 20);
  });

  test('묶음 안에서 404 뒤에 온 정책은 버리지 않는다', () async {
    // 순차였다면 3·4·5 에서 멈춰 6 을 못 봤다 — 이미 손에 든 값이다
    final called = <int>[];
    final policies = await fetchPoliciesInBatches(
      detailOf({1: policy(1), 2: policy(2), 6: policy(6)}, called),
    );
    expect(policies.map((p) => p['id']), [1, 2, 6]);
    expect(called.length, 10);
  });

  test('서버 오류는 그 묶음까지만 본다 — 받은 것은 남긴다', () async {
    final called = <int>[];
    final policies = await fetchPoliciesInBatches(
      detailOf({
        1: policy(1),
        2: serverError,
        for (var i = 3; i <= 10; i++) i: policy(i),
      }, called),
    );
    expect(policies.length, 9);
    expect(called.length, 10, reason: '둘째 묶음은 읽지 않는다');
  });

  test('ApiException 이 아닌 오류는 그대로 던진다', () async {
    Future<Map<String, dynamic>> detail(int id) async => throw StateError('끊김');
    await expectLater(fetchPoliciesInBatches(detail), throwsStateError);
  });
}
