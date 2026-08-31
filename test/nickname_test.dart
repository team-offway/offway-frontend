import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/utils/nickname.dart';

/// 인사말에서 사람을 어떻게 부를지 고정한다.
///
/// 서버가 주는 이름은 가입 경로에 따라 갈린다 — 카카오는 대개 성까지 온다.
/// 그대로 부르면 `이예빈님, 어디로 떠나볼까요?`가 되는데, 성까지 붙여 부르는
/// 자리가 아니다.
void main() {
  group('세 글자 한국 이름은 성을 뗀다', () {
    test('이예빈 → 예빈', () {
      expect(displayName('이예빈'), '예빈');
    });

    test('김민수 → 민수', () {
      expect(displayName('김민수'), '민수');
    });
  });

  group('그대로 두는 경우', () {
    test('두 글자는 손대지 않는다', () {
      // 이미 이름만 남았거나(민수), 성을 떼면 한 글자가 되어 부를 수 없다
      expect(displayName('민수'), '민수');
    });

    test('네 글자 이상은 어디를 자를지 알 수 없다', () {
      // 복성일 수도(남궁예빈), 한국 이름이 아닐 수도 있다
      expect(displayName('남궁예빈'), '남궁예빈');
      expect(displayName('크리스티나'), '크리스티나');
    });

    test('한 글자도 그대로 둔다', () {
      expect(displayName('빈'), '빈');
    });

    test('한글이 아니면 자르지 않는다', () {
      // 'Alex'에서 'lex'가 되면 안 된다
      expect(displayName('Bob'), 'Bob');
      expect(displayName('김Bo'), '김Bo');
      expect(displayName('山田佐'), '山田佐');
    });

    test('빈 이름도 깨지지 않는다', () {
      expect(displayName(''), '');
    });
  });

  test('앞뒤 공백은 정리한다', () {
    // 공백까지 세면 세 글자 판정이 어긋난다
    expect(displayName(' 이예빈 '), '예빈');
    expect(displayName(' 민수 '), '민수');
  });
}
