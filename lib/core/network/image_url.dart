/// 원격 이미지 주소를 **앱이 실제로 받을 수 있는 형태**로 다듬는다.
///
/// TourAPI가 사진 주소를 `http://tong.visitkorea.or.kr/...`로 준다. 1.0.2에서
/// iOS 보안 예외(ATS 전면 허용)를 걷어내면서 평문 HTTP가 막혀, 그대로 두면
/// **사진이 한 장도 안 내려온다.**
///
/// 같은 호스트가 https로도 같은 파일을 준다(TLS 1.3 · 한국관광공사 정식
/// 인증서, 2026-08-30 실측). 그래서 **아는 호스트만** 승격한다.
///
/// **모든 http를 올리지 않는 이유**는, https를 지원하지 않는 호스트가 섞여
/// 들어오면 지금 뜨는 사진까지 함께 깨지기 때문이다. 서버가 https로 바꿔
/// 주면(그게 정공법이다) 이 함수는 그냥 통과시킨다.
String? httpsImageUrl(String? url) {
  final raw = url?.trim();
  if (raw == null || raw.isEmpty) return url;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'http') return raw;
  if (!_upgradableHosts.contains(uri.host.toLowerCase())) return raw;
  return uri.replace(scheme: 'https').toString();
}

/// https로 같은 파일을 주는 것이 확인된 호스트.
///
/// 늘릴 때는 **인증서까지 검증하고** 넣는다 — iOS는 자체 서명이나 만료된
/// 인증서를 http만큼이나 확실하게 막는다.
const _upgradableHosts = {
  // 한국관광공사 TourAPI 사진 — 앱이 쓰는 이미지의 대부분이 여기서 온다
  'tong.visitkorea.or.kr',
};
