import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/utils/date_format.dart';
import 'package:offway/features/course/domain/pending_trip.dart';

/// "다녀오셨나요?" 모달이 서버 응답으로 만드는 문구를 고정한다.
void main() {
  Map<String, dynamic> json({
    Object? courseId = 12,
    Object? regionName = '정선군',
    Object? travelDate = '2026-07-20',
    Object? travelEndDate = '2026-07-22',
    Object? consumedLeaveDays = 3.0,
  }) => {
    'courseId': courseId,
    'regionName': regionName,
    'travelDate': travelDate,
    'travelEndDate': travelEndDate,
    'consumedLeaveDays': consumedLeaveDays,
  };

  group('서버 응답 읽기', () {
    test('필요한 값을 모두 꺼낸다', () {
      final trip = PendingTrip.tryParse(json())!;

      expect(trip.courseId, 12);
      expect(trip.startDate, DateTime(2026, 7, 20));
      expect(trip.endDate, DateTime(2026, 7, 22));
      expect(trip.consumedLeaveDays, 3.0);
    });

    test('날짜가 없으면 버린다', () {
      // 없는 날짜로 'N일 차감'을 물으면 안 된다.
      // 서버는 날짜 없는 코스를 애초에 안 주지만 화면이 스스로 지킨다
      expect(PendingTrip.tryParse(json(travelDate: null)), isNull);
      expect(PendingTrip.tryParse(json(travelEndDate: null)), isNull);
      expect(PendingTrip.tryParse(json(courseId: null)), isNull);
    });

    test('차감 일수가 없으면 0으로 둔다', () {
      final trip = PendingTrip.tryParse(json(consumedLeaveDays: null))!;
      expect(trip.consumedLeaveDays, 0);
    });
  });

  group('모달 제목', () {
    test('행정구역 접미사를 뗀다', () {
      // 시안이 '정선 여행'이다 — '정선군 여행'은 말맛이 어색하다
      expect(PendingTrip.tryParse(json())!.title, '정선 여행, 다녀오셨나요?');
    });

    test('시·구·광역시도 뗀다', () {
      for (final (name, expected) in const [
        ('공주시', '공주'),
        ('부산광역시', '부산'),
        ('세종특별자치시', '세종'),
      ]) {
        final trip = PendingTrip.tryParse(json(regionName: name))!;
        expect(trip.title, '$expected 여행, 다녀오셨나요?', reason: name);
      }
    });

    test('접미사만 남을 이름은 그대로 둔다', () {
      // '중구' → '중'이 되면 지역을 알아볼 수 없다
      final trip = PendingTrip.tryParse(json(regionName: '중구'))!;
      expect(trip.title, '중구 여행, 다녀오셨나요?');
    });

    test('지역명이 없으면 지역을 빼고 묻는다', () {
      // 서버가 지역을 못 찾으면 null이 온다 — ' 여행, 다녀오셨나요?'로
      // 앞이 비어 보이면 안 된다
      for (final missing in [null, '', '  ']) {
        final trip = PendingTrip.tryParse(json(regionName: missing))!;
        expect(trip.title, '이 여행, 다녀오셨나요?', reason: '$missing');
      }
    });
  });

  group('여행 기간 문구', () {
    test('시안 형식 그대로 만든다', () {
      // 2026-07-20은 월요일, 22일은 수요일
      expect(
        tripPeriodLabel(DateTime(2026, 7, 20), DateTime(2026, 7, 22)),
        '7.20(월) – 7.22(수) · 2박 3일',
      );
    });

    test('월·일에 0을 채우지 않는다', () {
      // 시안이 '7.20'이지 '07.20'이 아니다
      expect(
        tripPeriodLabel(DateTime(2026, 3, 6), DateTime(2026, 3, 7)),
        '3.6(금) – 3.7(토) · 1박 2일',
      );
    });

    test('당일치기는 날짜를 한 번만 쓴다', () {
      expect(
        tripPeriodLabel(DateTime(2026, 7, 20), DateTime(2026, 7, 20)),
        '7.20(월) · 당일치기',
      );
    });

    test('달을 넘어가도 이어진다', () {
      expect(
        tripPeriodLabel(DateTime(2026, 7, 31), DateTime(2026, 8, 2)),
        '7.31(금) – 8.2(일) · 2박 3일',
      );
    });
  });
}
