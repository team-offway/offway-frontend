/// 한글 조사 — 앞말의 받침에 따라 '으로/로'를 고른다.
///
/// `정선으로`·`완도로`·`서울로`처럼 받침이 없거나 ㄹ 받침이면 '로', 그 밖의
/// 받침이면 '으로'다. 지역명이 서버에서 오므로 앱이 미리 알 수 없다.
/// 한글이 아닌 글자로 끝나면(영문·숫자) '으로'로 둔다.
String withEuro(String word) {
  if (word.isEmpty) return word;
  final code = word.codeUnitAt(word.length - 1);
  const first = 0xAC00, last = 0xD7A3;
  if (code < first || code > last) return '$word으로';
  final jong = (code - first) % 28;
  // 받침 없음(0) 또는 ㄹ 받침(8)이면 '로'
  return (jong == 0 || jong == 8) ? '$word로' : '$word으로';
}
