import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/image_url.dart';

/// TourAPI 사진 주소를 앱이 받을 수 있는 형태로 바꾸는지 고정한다.
///
/// 1.0.2에서 iOS 보안 예외(ATS 전면 허용)를 걷어내면서 평문 HTTP가 막혔다.
/// TourAPI는 사진을 http로 주므로, 그대로 두면 사진이 한 장도 안 내려온다.
void main() {
  group('올린다', () {
    test('TourAPI 사진은 https로 바꾼다', () {
      expect(
        httpsImageUrl(
          'http://tong.visitkorea.or.kr/cms2/website/78/2802978.jpg',
        ),
        'https://tong.visitkorea.or.kr/cms2/website/78/2802978.jpg',
      );
    });

    test('경로·질의를 그대로 살린다', () {
      expect(
        httpsImageUrl('http://tong.visitkorea.or.kr/a/b.jpg?v=2'),
        'https://tong.visitkorea.or.kr/a/b.jpg?v=2',
      );
    });

    test('대문자 호스트도 알아본다', () {
      expect(
        httpsImageUrl('http://TONG.VisitKorea.or.kr/x.jpg'),
        startsWith('https://'),
      );
    });
  });

  group('건드리지 않는다', () {
    test('이미 https면 그대로', () {
      // 서버가 https로 바꿔 주면(정공법) 이 함수는 통과만 한다
      const url = 'https://tong.visitkorea.or.kr/x.jpg';
      expect(httpsImageUrl(url), url);
    });

    test('모르는 호스트는 올리지 않는다', () {
      // https를 지원하지 않는 곳을 올리면 지금 뜨는 사진까지 깨진다
      const url = 'http://example.invalid/x.jpg';
      expect(httpsImageUrl(url), url);
    });

    test('소셜 프로필처럼 다른 https 호스트도 그대로', () {
      const url = 'https://k.kakaocdn.net/profile.jpg';
      expect(httpsImageUrl(url), url);
    });

    test('null·빈 값은 그대로 돌려준다', () {
      expect(httpsImageUrl(null), isNull);
      expect(httpsImageUrl(''), '');
    });

    test('주소가 아니면 손대지 않는다', () {
      expect(httpsImageUrl('그냥 글자'), '그냥 글자');
    });
  });
}
