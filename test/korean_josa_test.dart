import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/utils/korean_josa.dart';

/// 결과 모달의 '○○으로 떠나기' — 지역명이 서버에서 오므로 조사를 앱이 고른다.
void main() {
  test('받침이 있으면 으로', () {
    expect(withEuro('정선'), '정선으로');
    expect(withEuro('보령'), '보령으로');
    expect(withEuro('남해'), '남해로');
  });

  test('받침이 없거나 ㄹ 받침이면 로', () {
    expect(withEuro('완도'), '완도로');
    expect(withEuro('제주'), '제주로');
    expect(withEuro('서울'), '서울로');
    expect(withEuro('울릉'), '울릉으로');
  });

  test('한글이 아니면 으로로 둔다', () {
    expect(withEuro('Jeju'), 'Jeju으로');
    expect(withEuro(''), '');
  });
}
