import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/utils/external_link.dart';

/// 서버가 내려준 주소를 앱이 열어도 되는지 — 공용 판정의 계약을 고정한다.
///
/// 서버도 저장할 때 https를 강제하지만(core #350), 웹뷰에 주소를 넘기는 것은
/// 앱이다. 한 겹만 믿으면 서버의 다른 경로로 들어온 값이 그대로 통과한다.
void main() {
  group('열어도 되는 주소', () {
    test('https면 받는다', () {
      expect(
        safeExternalUri('https://korean.visitkorea.or.kr')?.toString(),
        'https://korean.visitkorea.or.kr',
      );
    });

    test('경로·질의가 붙어도 그대로 살린다', () {
      // 신청 페이지는 tour50.do 처럼 경로가 붙어 온다
      expect(
        safeExternalUri('https://a.kr/dgtourcard/tour50.do?x=1')?.toString(),
        'https://a.kr/dgtourcard/tour50.do?x=1',
      );
    });

    test('대문자 스킴도 받는다', () {
      // Uri가 소문자로 정규화한다 — 멀쩡한 주소를 버리지 않는다
      expect(safeExternalUri('HTTPS://a.kr'), isNotNull);
    });

    test('앞뒤 공백은 털어낸다', () {
      expect(safeExternalUri('  https://a.kr  ')?.host, 'a.kr');
    });
  });

  group('열지 않는 주소', () {
    test('http는 암호화되지 않은 채로 오간다', () {
      expect(safeExternalUri('http://a.kr'), isNull);
    });

    test('웹뷰에서 열 것이 아닌 스킴은 막는다', () {
      expect(safeExternalUri('javascript:alert(1)'), isNull);
      expect(safeExternalUri('data:text/html,<h1>x'), isNull);
      expect(safeExternalUri('file:///etc/passwd'), isNull);
    });

    test('스킴이 없으면 막는다', () {
      expect(safeExternalUri('www.letskorail.com'), isNull);
      expect(safeExternalUri('/apply'), isNull);
    });

    test('스킴만 맞고 갈 곳이 없으면 막는다', () {
      expect(safeExternalUri('https://'), isNull);
      expect(safeExternalUri('https:///path'), isNull);
    });

    test('비었거나 없으면 막는다', () {
      expect(safeExternalUri(null), isNull);
      expect(safeExternalUri(''), isNull);
      expect(safeExternalUri('   '), isNull);
    });
  });
}
