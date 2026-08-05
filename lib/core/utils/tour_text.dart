/// TourAPI 자유 텍스트 정리.
///
/// 원문에 `<br>` 같은 HTML 태그와 `&amp;` 같은 엔티티가 섞여 온다 —
/// 줄바꿈은 살리고 나머지 태그는 걷어내 화면에 그대로 보여줄 수 있게 한다.
String? cleanTourApiText(String? text) {
  if (text == null) return null;
  var cleaned = text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&nbsp;': ' ',
  };
  entities.forEach((from, to) => cleaned = cleaned.replaceAll(from, to));
  return cleaned.trim();
}
