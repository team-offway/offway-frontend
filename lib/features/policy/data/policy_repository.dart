import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final policyRepositoryProvider = Provider<PolicyRepository>(
  (ref) => PolicyRepository(ref.watch(dioProvider)),
);

/// 정책(혜택) 상세 — 지역 카드의 혜택 뱃지에서 들어온다
class PolicyRepository {
  PolicyRepository(this._dio);

  final Dio _dio;

  /// 정책 상세와 이 혜택이 되는 여행지 목록 (`GET /policies/{id}`)
  Future<Map<String, dynamic>> detail(int policyId) async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/policies/$policyId');
      return ApiEnvelope.unwrap(response) as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }
}

/// 정책 상세 **전부** — 세션 동안 한 번 읽는다.
///
/// 지역별 혜택 색인([regionPoliciesProvider])이 이걸 뒤집어 만들고, 혜택 상세
/// 시트([policyDetailProvider])가 여기서 먼저 찾는다. 원본을 들고 있지 않으면
/// 시트가 이미 받아 둔 정책을 다시 불렀다(#364)
final allPoliciesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => fetchPoliciesInBatches(ref.watch(policyRepositoryProvider).detail),
  retry: (retryCount, error) => null,
);

/// 정책 상세 — 뱃지를 누른 정책 하나.
///
/// **받아 둔 목록에 있으면 그것을 쓴다** — 앱을 켤 때 전부 읽어 두므로 대개
/// 여기서 끝나고, 시트가 스피너 없이 바로 열린다. 목록이 아직 오는 중이거나
/// 목록에 없는 정책(기간이 지나 끝난 뒤 읽은 것 등)만 서버에 묻는다.
///
/// 목록을 **기다리지 않는다**(`read(...).value`) — 첫 화면에서 뱃지를 바로
/// 눌렀는데 묶음 읽기 전체를 기다리면 한 건 묻는 것보다 느리다
final policyDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, policyId) async {
      // 아직 아무도 안 읽었으면 건드리지 않는다 — read 만으로도 묶음 읽기가
      // 시작된다
      final known = ref.exists(allPoliciesProvider)
          ? ref
                .read(allPoliciesProvider)
                .value
                ?.where((p) => (p['id'] as num?)?.toInt() == policyId)
                .firstOrNull
          : null;
      return known ?? ref.watch(policyRepositoryProvider).detail(policyId);
    });

/// 정책 상세를 [batchSize]개씩 **한꺼번에** 읽는다.
///
/// 하나씩 기다리면 왕복(약 0.26초)이 id 수만큼 쌓인다 — 정책 6개를 받는 데
/// 10번을 불러 2.6초였다. 한 묶음을 같이 띄우면 왕복 한 번 값이다(실측 0.7초).
/// 요청 수는 그대로다 — 순서만 바꿨다.
///
/// 끝을 보는 규칙은 그대로다: 404가 [_endAfterMisses]번 이어지면 그 뒤 묶음은
/// 읽지 않는다. 이미 읽은 묶음 안에서 그 뒤에 온 정책은 버리지 않는다 — 손에
/// 든 값을 버릴 이유가 없다. 404 아닌 서버 오류는 그 묶음까지만 보고 멈춘다 —
/// 색인이 조금 모자라면 "+1"이 덜 뜰 뿐이고, 통째로 실패하면 뱃지 전부를 잃는다
Future<List<Map<String, dynamic>>> fetchPoliciesInBatches(
  Future<Map<String, dynamic>> Function(int policyId) detail, {
  int maxId = _maxPolicyId,
  int batchSize = _batchSize,
}) async {
  final policies = <Map<String, dynamic>>[];
  var misses = 0;
  for (var from = 1; from <= maxId; from += batchSize) {
    final to = math.min(from + batchSize - 1, maxId);
    final batch = await Future.wait([
      for (var id = from; id <= to; id++) _tryDetail(detail, id),
    ]);
    var halted = false;
    for (final (:policy, :error) in batch) {
      if (policy != null) {
        policies.add(policy);
        misses = 0;
      } else if (error?.status == 404) {
        misses++;
      } else {
        halted = true;
      }
    }
    if (halted || misses >= _endAfterMisses) break;
  }
  return policies;
}

/// 없는 id(404)와 서버 오류를 값으로 돌려준다 — `Future.wait` 가 첫 실패에서
/// 묶음째 던지지 않게
Future<({Map<String, dynamic>? policy, ApiException? error})> _tryDetail(
  Future<Map<String, dynamic>> Function(int policyId) detail,
  int id,
) async {
  try {
    return (policy: await detail(id), error: null);
  } on ApiException catch (e) {
    return (policy: null, error: e);
  }
}

/// 정책 id 상한 — 검증된 정책이 이만큼 늘면 서버가 목록을 줘야 한다
const _maxPolicyId = 30;
const _endAfterMisses = 3;

/// 한 번에 띄우는 요청 수 — 지금 정책이 6개라 첫 묶음에서 끝난다
const _batchSize = 10;
