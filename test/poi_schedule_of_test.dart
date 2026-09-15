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

  test('최상위가 빈 문자열이면 블록 값이 이긴다', () {
    // null만 걸러서는 빈 문자열이 이겨 진짜 운영시간이 묻힌다
    final s = poiScheduleOf(const {
      'useTime': '',
      'restDate': '   ',
      'culture': {'useTime': '09:00~18:00', 'restDate': '매주 월요일'},
    });
    expect(s.useTime, '09:00~18:00');
    expect(s.restDate, '매주 월요일');
  });

  test('블록도 비어 있으면 다음 후보로 넘어간다', () {
    final s = poiScheduleOf(const {
      'useTime': '',
      'sight': {'useTime': ''},
      'food': {'openTime': '11:00~21:00'},
    });
    expect(s.useTime, '11:00~21:00');
  });

  test('체크인·체크아웃이 빈 문자열이면 지어내지 않는다', () {
    final s = poiScheduleOf(const {
      'stay': {'checkIn': '', 'checkOut': ''},
    });
    expect(s.useTime, isNull);
  });

  test('체크아웃만 있으면 그것만 말한다', () {
    final s = poiScheduleOf(const {
      'stay': {'checkIn': '  ', 'checkOut': '11:00'},
    });
    expect(s.useTime, '체크아웃 11:00');
  });

  test('앞뒤 공백은 다듬는다', () {
    final s = poiScheduleOf(const {'useTime': '  09:00~18:00  '});
    expect(s.useTime, '09:00~18:00');
  });

  test('빈 줄은 접는다 — 줄마다 항목 하나라 여백 없이도 뜻은 같다', () {
    // 서버(TourText.normalize)는 연속 빈 줄을 하나로만 줄인다. 그 하나가
    // 정보 상자에서 줄 하나를 통째로 비웠다 (QA 9/16, 연미산자연미술공원)
    final s = poiScheduleOf(const {
      'sight': {
        'useTime':
            '- 3월~10월 10:00~18:00 (입장마감 17:00)\n\n- 11월 10:00~17:00 (입장마감 16:00)',
        'restDate': '매주 월요일\n \n\n12월~2월 동절기',
      },
    });
    expect(
      s.useTime,
      '- 3월~10월 10:00~18:00 (입장마감 17:00)\n- 11월 10:00~17:00 (입장마감 16:00)',
    );
    expect(s.restDate, '매주 월요일\n12월~2월 동절기');
  });

  test('한 줄 줄바꿈은 그대로다 — 줄 구분이 곧 뜻이다', () {
    final s = poiScheduleOf(const {
      'useTime': '[동절기]\n- 10:00~17:00\n※ 폐장 30분 전 매표 마감',
    });
    expect(s.useTime, '[동절기]\n- 10:00~17:00\n※ 폐장 30분 전 매표 마감');
  });

  test('블록이 없으면 null — 없는 값을 지어내지 않는다', () {
    final s = poiScheduleOf(const {'title': '좌천동 가구거리'});
    expect(s.useTime, isNull);
    expect(s.restDate, isNull);
  });
}
