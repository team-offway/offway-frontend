import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/policy/data/policy_repository.dart';

/// 혜택 상세 시트는 **이미 받아 둔 정책**을 먼저 쓴다(#364).
///
/// 앱을 켤 때 정책 상세를 전부 읽어 두는데, 시트가 그걸 두고 같은 정책을
/// 다시 불러 스피너가 떴다.
class _CountingRepository implements PolicyRepository {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> detail(int policyId) async {
    calls++;
    return {'id': policyId, 'name': '서버에서 받은 정책'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('받아 둔 목록에 있으면 서버를 부르지 않는다', () async {
    final repo = _CountingRepository();
    final container = ProviderContainer(
      overrides: [
        policyRepositoryProvider.overrideWithValue(repo),
        allPoliciesProvider.overrideWith(
          (ref) async => [
            {'id': 7, 'name': '받아 둔 정책'},
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(allPoliciesProvider.future);
    final policy = await container.read(policyDetailProvider(7).future);

    expect(policy['name'], '받아 둔 정책');
    expect(repo.calls, 0);
  });

  test('목록에 없는 정책은 서버에 묻는다', () async {
    final repo = _CountingRepository();
    final container = ProviderContainer(
      overrides: [
        policyRepositoryProvider.overrideWithValue(repo),
        allPoliciesProvider.overrideWith(
          (ref) async => [
            {'id': 7, 'name': '받아 둔 정책'},
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(allPoliciesProvider.future);
    final policy = await container.read(policyDetailProvider(9).future);

    expect(policy['name'], '서버에서 받은 정책');
    expect(repo.calls, 1);
  });

  test('목록을 아무도 안 읽었으면 묶음 읽기를 시작하지 않고 한 건만 묻는다', () async {
    final repo = _CountingRepository();
    final container = ProviderContainer(
      overrides: [policyRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(policyDetailProvider(3).future);

    expect(repo.calls, 1);
    expect(container.exists(allPoliciesProvider), isFalse);
  });
}
