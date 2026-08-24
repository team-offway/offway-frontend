import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/home/presentation/home_screen.dart';

/// 홈의 온보딩(연차 입력) 리다이렉트 판단 (#132).
///
/// 재보된 버그: 로그아웃 → 재로그인하면 이미 연차를 등록한 회원인데도
/// 온보딩이 다시 떴다. 로그아웃 직후 캐시에 남은 게스트(연차 null)를
/// 재조회가 끝나기 전에 보고 판단한 것이 원인이다.
void main() {
  const guest = <String, dynamic>{'nickname': '게스트'};
  const member = <String, dynamic>{'nickname': '영찬', 'remainingLeaveDays': 5.0};

  test('연차가 없는 확정값이면 온보딩으로 보낸다', () {
    expect(leaveOnboardingNeeded(const AsyncData(guest)), isTrue);
  });

  test('연차가 있으면 보내지 않는다', () {
    expect(leaveOnboardingNeeded(const AsyncData(member)), isFalse);
  });

  test('아직 읽는 중이면 보내지 않는다', () {
    expect(
      leaveOnboardingNeeded(const AsyncLoading<Map<String, dynamic>>()),
      isFalse,
    );
  });

  test('재조회 중에 이전 값이 게스트여도 보내지 않는다 — 재로그인 직후 (#132)', () async {
    // invalidate 직후 Riverpod은 이전 값을 .value에 남긴 채 로딩 상태가 된다.
    // 로그아웃 직후에는 그 이전 값이 게스트(연차 null)다 — 새 값이 오기
    // 전에 이걸 보고 온보딩으로 보내면 안 된다
    var value = guest;
    final provider = FutureProvider<Map<String, dynamic>>((ref) async => value);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(provider, (_, _) {});
    await container.read(provider.future);

    value = member;
    container.invalidate(provider);
    final reloading = sub.read();
    // 전제: 로딩 중이고 이전 값(게스트)이 남아 있다 — 버그가 봤던 바로 그 상태
    expect(reloading.isLoading, isTrue);
    expect(reloading.value?['nickname'], '게스트');
    expect(leaveOnboardingNeeded(reloading), isFalse);
  });

  test('읽기에 실패했으면 보내지 않는다 — 못 읽은 것과 없는 것은 다르다', () {
    expect(
      leaveOnboardingNeeded(
        AsyncError<Map<String, dynamic>>('down', StackTrace.empty),
      ),
      isFalse,
    );
  });
}
