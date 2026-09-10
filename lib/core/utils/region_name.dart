/// 행정구역 접미사 — 긴 것부터 본다(`특별자치시`가 `시`보다 먼저).
const _suffixes = ['특별자치시', '특별자치도', '광역시', '특별시', '시', '군', '구'];

/// 접미사를 떼고도 남아야 할 최소 글자 수.
///
/// '중구'에서 '구'를 떼면 '중'만 남아 어느 지역인지 알아볼 수 없다.
const _minNameLength = 2;

/// 행정구역 접미사를 뗀 지역명 (`정선군` → `정선`). 지역이 없으면 null.
///
/// 시안이 '정선 여행'이고 '정선군 여행'은 말맛이 어색하다.
String? shortRegionNameOf(String? regionName) {
  final name = regionName?.trim();
  if (name == null || name.isEmpty) return null;
  for (final suffix in _suffixes) {
    if (!name.endsWith(suffix)) continue;
    final stem = name.substring(0, name.length - suffix.length);
    return stem.length >= _minNameLength ? stem : name;
  }
  return name;
}

/// `공주시` → `공주 여행`. 지역이 없으면 null.
String? regionTripLabel(String? regionName) {
  final short = shortRegionNameOf(regionName);
  return short == null ? null : '$short 여행';
}
