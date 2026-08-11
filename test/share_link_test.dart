import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/config/app_config.dart';
import 'package:offway/features/course/domain/share_link.dart';

void main() {
  test('공유 링크는 서버 스펙대로 /c/{shareToken} 이다', () {
    expect(
      ShareLink.of('2iQuIbj3FeUb1PAqLLd52g'),
      '${AppConfig.shareBaseUrl}/c/2iQuIbj3FeUb1PAqLLd52g',
    );
  });

  test('슬래시가 겹치지 않는다', () {
    // 주입한 주소 끝에 슬래시가 붙어도 //c/ 가 되면 서버 계약과 어긋난다
    expect(ShareLink.of('abc'), isNot(contains('//c/')));
    expect(ShareLink.of('abc'), endsWith('/c/abc'));
  });
}
