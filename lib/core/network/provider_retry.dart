import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_envelope.dart';

/// 프로바이더가 실패했을 때 **다시 부를지, 얼마나 기다렸다 부를지** (core #475).
///
/// Riverpod 3는 기본으로 실패한 프로바이더를 0.2초부터 2배씩 늘려 10번까지
/// 다시 부른다. 그 기본값 그대로 두었더니 공공데이터 장애 날 장소 상세가
/// 502를 받고 **2초에 14번** 서버를 두드렸다 — 코스 화면의 장소 행들과 상세
/// 시트가 같은 장소를 동시에 물으면서 각자 되물었다. 서버 문구는 "잠시 후
/// 다시 시도"인데 0.2초 뒤에 다시 묻는 셈이었고, 서버가 실패를 1분 캐시하니
/// 답은 늘 같았다.
///
/// 루트 [ProviderScope]에 한 번 걸어 모든 프로바이더에 적용한다. 개별
/// 프로바이더의 `retry`가 있으면 그쪽이 이긴다(공휴일 프로바이더가 그렇다).
Duration? providerRetry(int retryCount, Object error) {
  // 서버가 답한 오류(4xx·5xx)는 곧바로 다시 물어도 답이 같다. 화면마다 있는
  // 수동 재시도 버튼에 맡긴다 — 서버가 "잠시 후" 라고 한 그 뜻이다
  if (error is ApiException && error.status != 0) return null;
  // 연결 자체가 안 된 경우(타임아웃·오프라인)는 다시 물을 가치가 있다 —
  // 지하철에서 잠깐 끊긴 것일 수 있다. 다만 1초부터 시작해 세 번까지만
  return ProviderContainer.defaultRetry(
    retryCount,
    error,
    maxRetries: _networkMaxRetries,
    minDelay: _networkMinDelay,
  );
}

/// 연결 실패 재시도 횟수 — 1초 · 2초 · 4초 뒤 세 번
const _networkMaxRetries = 3;
const _networkMinDelay = Duration(seconds: 1);
