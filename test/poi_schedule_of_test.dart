import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/data/course_repository.dart';

/// 서버는 운영 정보를 타입별 블록에 담고 최상위는 비워 둔다.
/// 모달과 상세 화면이 같은 값을 말해야 한다.
void main() {
  test('문화시설은 culture 블록에서 읽는다', () {
    final s = poiScheduleOf(const {
      'title': '부산 동구도서관',
      'culture': {'useTime': '화요일~금요일 09:00~22:00', 'restDate': '매주 월요일'},
    });
    expect(s.useTime, '화요일~금요일 09:00~22:00');
    expect(s.restDate, '매주 월요일');
  });

  test('숙소는 체크인·체크아웃으로 대신 말한다', () {
    final s = poiScheduleOf(const {
      'title': '라메르호텔',
      'stay': {'checkIn': '15:00', 'checkOut': '11:00'},
    });
    expect(s.useTime, '체크인 15:00 · 체크아웃 11:00');
    expect(s.restDate, isNull);
  });

  test('식당은 food.openTime을 쓴다', () {
    final s = poiScheduleOf(const {
      'food': {'openTime': '11:00~21:00', 'restDate': '매주 화요일'},
    });
    expect(s.useTime, '11:00~21:00');
    expect(s.restDate, '매주 화요일');
  });

  test('최상위에 실려 오면 그 값이 먼저다', () {
    final s = poiScheduleOf(const {
      'useTime': '상시 개방',
      'culture': {'useTime': '09:00~18:00'},
    });
    expect(s.useTime, '상시 개방');
  });

  test('블록이 없으면 null — 없는 값을 지어내지 않는다', () {
    final s = poiScheduleOf(const {'title': '좌천동 가구거리'});
    expect(s.useTime, isNull);
    expect(s.restDate, isNull);
  });
}
