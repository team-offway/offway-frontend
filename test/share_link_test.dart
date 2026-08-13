import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/config/app_config.dart';
import 'package:offway/features/course/data/kakao_share.dart'
    show SharedCourseKind;
import 'package:offway/features/course/domain/share_link.dart';

void main() {
  const token = '2iQuIbj3FeUb1PAqLLd52g';

  test('추천코스는 /r/, 내 코스는 /m/ 로 갈린다', () {
    // 링크를 받은 사람이 보는 화면이 다르다 — 경로로 구분한다
    expect(
      ShareLink.of(token, kind: SharedCourseKind.recommend),
      '${AppConfig.shareBaseUrl}/r/$token',
    );
    expect(
      ShareLink.of(token, kind: SharedCourseKind.saved),
      '${AppConfig.shareBaseUrl}/m/$token',
    );
  });

  test('슬래시가 겹치지 않는다', () {
    // 주입한 주소 끝에 슬래시가 붙어도 //r/ 이 되면 링크가 깨진다
    for (final kind in SharedCourseKind.values) {
      final link = ShareLink.of('abc', kind: kind);
      expect(link, isNot(contains('//abc')));
      expect(link, endsWith('/abc'));
    }
  });
}
