import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/domain/transit_access.dart';
import 'package:offway/features/course/presentation/widgets/dotted_line.dart';
import 'package:offway/features/course/presentation/widgets/transit_access_card.dart';

/// 무엇을 타고 어디에 내리는가 (core #97).
///
/// 버스·여객선은 **시간표를 못 묻는다** — 요청 시점에 조회가 안 된다.
/// 그래서 소요시간이 없는 경우가 흔하고, 아는 만큼만 말해야 한다.
/// 보내기만 받아 주는 콜백 — 버튼이 있는지만 보는 테스트가 쓴다
Future<void> _accept(TransitOption _) async {}

void main() {
  Map<String, dynamic> raw({
    Object? modeLabel = '시외버스',
    Object? status = 'POINT_ONLY',
    Object? fromPlace,
    Object? toPlace = '정선',
    Object? vehicleType,
    Object? durationMinutes,
    Object? distanceKm,
    List<Object>? alternatives,
    List<Object>? departures,
  }) => {
    'mode': 'INTERCITY_BUS',
    'modeLabel': modeLabel,
    'status': status,
    'fromPlace': fromPlace,
    'toPlace': toPlace,
    'vehicleType': vehicleType,
    'durationMinutes': durationMinutes,
    'distanceKm': distanceKm,
    'alternatives': alternatives ?? const [],
    'departures': departures ?? const [],
  };

  Future<void> pump(
    WidgetTester tester,
    TransitAccess access, {
    Future<void> Function(TransitOption option)? onModeSelected = _accept,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TransitAccessCard(
            access: access,
            onModeSelected: onModeSelected,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('응답 파싱', () {
    test('값이 없으면 그리지 않는다', () {
      // 자차 코스와 옛 서버 응답이 null로 온다
      expect(TransitAccess.tryParse(null), isNull);
    });

    test('수단 이름이 없으면 그리지 않는다', () {
      // "무엇을 타는지"를 말할 수 없다
      expect(TransitAccess.tryParse(raw(modeLabel: null)), isNull);
      expect(TransitAccess.tryParse(raw(modeLabel: '  ')), isNull);
    });

    test('버스는 소요시간 없이 온다', () {
      final a = TransitAccess.tryParse(raw())!;
      expect(a.modeLabel, '시외버스');
      expect(a.toPlace, '정선');
      expect(a.durationMinutes, isNull);
      expect(a.status, TransitStatus.pointOnly);
    });

    test('열차는 편명과 시간까지 온다', () {
      final a = TransitAccess.tryParse(
        raw(
          modeLabel: '열차',
          status: 'AVAILABLE',
          fromPlace: '청량리',
          toPlace: '민둥산',
          vehicleType: 'KTX',
          durationMinutes: 180,
        ),
      )!;
      expect(a.status, TransitStatus.available);
      expect(a.vehicleType, 'KTX');
      expect(a.durationLabel, '3시간');
    });

    test('모르는 상태는 unavailable로 받는다', () {
      // 서버가 상태를 늘려도 화면이 통째로 안 뜨는 일은 없어야 한다
      final a = TransitAccess.tryParse(raw(status: 'SOMETHING_NEW'))!;
      expect(a.status, TransitStatus.unavailable);
    });

    test('대안 수단을 함께 읽는다', () {
      final a = TransitAccess.tryParse(
        raw(
          alternatives: [
            {'modeLabel': '열차', 'toPlace': '민둥산', 'durationMinutes': 180},
          ],
        ),
      )!;
      expect(a.alternatives.single.modeLabel, '열차');
      expect(a.alternatives.single.durationLabel, '3시간');
    });
  });

  group('소요시간 문구', () {
    test('시간과 분을 함께 읽는다', () {
      expect(formatTransitDuration(90), '1시간 30분');
    });

    test('딱 떨어지면 시간만', () {
      expect(formatTransitDuration(180), '3시간');
    });

    test('한 시간 안이면 분만', () {
      expect(formatTransitDuration(50), '50분');
    });

    test('모르면 아무 말도 하지 않는다', () {
      expect(formatTransitDuration(null), isNull);
      expect(formatTransitDuration(0), isNull);
    });
  });

  group('거리 (core #380)', () {
    test('직선거리를 읽는다', () {
      expect(TransitAccess.tryParse(raw(distanceKm: 200))!.distanceKm, 200);
    });

    test('옛 서버 응답에는 없다 — 그래도 깨지지 않는다', () {
      expect(TransitAccess.tryParse(raw())!.distanceKm, isNull);
    });

    testWidgets('소요시간 옆에 붙는다', (tester) async {
      // 시안: 서울에서 출발 • 약 2시간 29분 • 200km
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TransitAccessCard(
              access: TransitAccess.tryParse(
                raw(fromPlace: '서울', durationMinutes: 149, distanceKm: 200),
              )!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('서울에서 출발 • 약 2시간 29분 • 200km'), findsOneWidget);
    });

    testWidgets('자차는 출발지 이름 없이 시간과 거리만 말한다', (tester) async {
      // 서버가 자차의 fromPlace를 비운다 — 출발지를 좌표로만 받아 그곳을
      // 뭐라고 부르는지 모른다(core #380). 앱도 이름을 모르기는 마찬가지라
      // 지어내지 않고 아는 만큼만 쓴다
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TransitAccessCard(
              access: TransitAccess.tryParse({
                'mode': 'CAR',
                'modeLabel': '자차',
                'status': 'AVAILABLE',
                'toPlace': '정선',
                'durationMinutes': 149,
                'distanceKm': 200,
                'alternatives': const <Object>[],
              })!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('자차로 정선까지'), findsOneWidget);
      expect(find.text('약 2시간 29분 • 200km'), findsOneWidget);
      // 자차에 대안은 없다 — 전환 버튼이 안 뜬다
      expect(find.textContaining('로 보기'), findsNothing);
    });
  });

  group('화면', () {
    testWidgets('무엇을 타고 어디에 내리는지 말한다', (tester) async {
      await pump(tester, TransitAccess.tryParse(raw())!);
      expect(find.text('시외버스로 정선까지'), findsOneWidget);
    });

    testWidgets('아는 만큼만 덧붙인다', (tester) async {
      // 버스도 어디서 타는지를 함께 준다(core #424) — 예전에는 이 값이 늘
      // null이라 같은 카드가 수단에 따라 다른 모양이었다. 소요시간은 아직
      // 안 잰 구간이면 비므로(core #107 배치가 채운다) 출발지만 남는다
      await pump(tester, TransitAccess.tryParse(raw(fromPlace: '동서울'))!);
      expect(find.text('동서울에서 출발'), findsOneWidget);
    });

    testWidgets('버스도 어디서 타는지 말한다 (core #424)', (tester) async {
      // 예전에는 버스·여객선의 fromPlace가 항상 null이라, 같은 카드가
      // 수단에 따라 다른 모양이었다 — 열차만 '어디서 출발'이 뜨고 버스는
      // 도착 지점만 떴다. 서버가 이미 찾고 있던 출발 터미널의 이름을
      // 싣기 시작했다
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(modeLabel: '고속버스', fromPlace: '서울경부', distanceKm: 150),
        )!,
      );

      expect(find.text('고속버스로 정선까지'), findsOneWidget);
      expect(find.text('서울경부에서 출발 • 150km'), findsOneWidget);
    });

    testWidgets('열차는 편명과 시간까지 보여준다', (tester) async {
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            modeLabel: '열차',
            fromPlace: '청량리',
            toPlace: '민둥산',
            vehicleType: 'KTX',
            durationMinutes: 180,
          ),
        )!,
      );
      expect(find.text('열차로 민둥산까지'), findsOneWidget);
      expect(find.text('청량리에서 출발 • KTX 약 3시간'), findsOneWidget);
    });

    testWidgets('내리는 곳을 모르면 통째로 접는다', (tester) async {
      await pump(tester, TransitAccess.tryParse(raw(toPlace: null))!);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('아는 것이 없어도 점선은 남는다', (tester) async {
      // 출발 지점을 못 찾는 구간이 그렇다 — 서울에서 울릉도는 출발 항구가
      // 반경 안에 없어 빈 값이 오고, 그게 맞는 답이다(core #424). 소요시간도
      // 아직 안 잰 구간이면 비어 둘째 줄이 통째로 없다. 그때 점선까지
      // 사라지면 같은 카드가 지역마다 다르게 보인다
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(fromPlace: null, vehicleType: null, durationMinutes: null),
        )!,
      );

      expect(find.text('시외버스로 정선까지'), findsOneWidget);
      expect(find.byType(DottedVerticalLine), findsOneWidget);
    });

    testWidgets('다른 수단이 있으면 갈아끼우는 버튼을 둔다', (tester) async {
      // 시안이 칩 나열을 버튼 하나로 정리했다 — 나란히 두면 무엇이 지금
      // 기준인지 흐려진다
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            alternatives: [
              {
                'mode': 'TRAIN',
                'modeLabel': '열차',
                'fromPlace': '청량리',
                'toPlace': '민둥산',
                'durationMinutes': 180,
              },
            ],
          ),
        )!,
      );
      expect(find.text('열차로 보기'), findsOneWidget);
    });

    testWidgets('버튼을 누르면 그 수단을 서버에 보내고 화면은 기다린다', (tester) async {
      // 화면 안에서 갈아끼우지 않는다 (core #458). 카드만 바꾸면 도착·출발
      // 칸은 옛 지점 그대로라 한 화면에서 두 값이 어긋난다 — 서버가 코스를
      // 통째로 바꿔 주면 그 값으로 다시 그린다
      final sent = <String?>[];
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            fromPlace: '동서울',
            alternatives: [
              {'mode': 'TRAIN', 'modeLabel': '열차', 'toPlace': '민둥산'},
            ],
          ),
        )!,
        onModeSelected: (option) async => sent.add(option.mode),
      );

      await tester.tap(find.text('열차로 보기'));
      await tester.pumpAndSettle();

      expect(sent, ['TRAIN']);
      // 답이 오기 전에는 대표가 그대로다 — 카드 혼자 앞서가지 않는다
      expect(find.text('시외버스로 정선까지'), findsOneWidget);
      expect(find.text('동서울에서 출발'), findsOneWidget);
    });

    testWidgets('답이 올 때까지 다시 눌러도 한 번만 보낸다', (tester) async {
      // 서버가 코스를 바꾸는 동안 두 번 누르면 같은 요청이 두 번 간다
      final completer = Completer<void>();
      var calls = 0;
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            alternatives: [
              {'mode': 'TRAIN', 'modeLabel': '열차', 'toPlace': '민둥산'},
            ],
          ),
        )!,
        onModeSelected: (_) {
          calls++;
          return completer.future;
        },
      );

      await tester.tap(find.text('열차로 보기'));
      await tester.pump();
      await tester.tap(find.text('열차로 보기'));
      await tester.pump();
      expect(calls, 1);

      // 답이 오면 다시 누를 수 있다
      completer.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('열차로 보기'));
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('보낼 곳이 없으면 버튼이 없다', (tester) async {
      // 공유 링크처럼 바꿀 권한이 없는 자리 — 눌러도 아무 일이 없는 버튼은
      // 고장으로 읽힌다
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            alternatives: [
              {'mode': 'TRAIN', 'modeLabel': '열차', 'toPlace': '민둥산'},
            ],
          ),
        )!,
        onModeSelected: null,
      );
      expect(find.textContaining('로 보기'), findsNothing);
    });

    testWidgets('수단 코드가 없는 대안은 보낼 수 없어 버튼이 없다', (tester) async {
      // 서버가 대안에 mode를 안 실으면 PATCH에 넣을 값이 없다
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            alternatives: [
              {'modeLabel': '열차', 'toPlace': '민둥산'},
            ],
          ),
        )!,
      );
      expect(find.textContaining('로 보기'), findsNothing);
    });

    testWidgets('갈 수 있는 수단이 하나뿐이면 버튼이 없다', (tester) async {
      // 자차가 그렇다 — 갈아낄 것이 없는데 버튼만 두면 누를 데가 없다
      await pump(tester, TransitAccess.tryParse(raw())!);
      expect(find.textContaining('로 보기'), findsNothing);
    });
  });

  group('시간표 — 몇 시 차가 있는가 (core #420)', () {
    Map<String, dynamic> departure({
      String? vehicleType = '무궁화호',
      Object? departAt = '2026-09-05T07:20:00',
      Object? arriveAt = '2026-09-05T09:49:00',
      Object? durationMinutes = 149,
    }) => {
      'vehicleType': vehicleType,
      'departAt': departAt,
      'arriveAt': arriveAt,
      'durationMinutes': durationMinutes,
    };

    test('출발·도착 시각과 등급을 읽는다', () {
      final access = TransitAccess.tryParse(raw(departures: [departure()]))!;

      expect(access.departures, hasLength(1));
      final d = access.departures.first;
      expect(d.departAt, DateTime(2026, 9, 5, 7, 20));
      expect(d.arriveAt, DateTime(2026, 9, 5, 9, 49));
      expect(d.vehicleType, '무궁화호');
      expect(d.durationMinutes, 149);
    });

    test('시각은 24시간 두 자리로 그린다 — 세로로 훑을 때 자리가 맞아야 한다', () {
      final d = TransitDeparture.tryParse(
        departure(departAt: '2026-09-05T07:05:00', arriveAt: null),
      )!;

      expect(d.departLabel, '07:05');
      // 도착을 모르면 출발만 말한다 — 화살표만 남기면 어디로 가는지 모른다
      expect(d.rangeLabel, '07:05');
    });

    test('출발 시각이 없는 편은 버린다 — 답할 질문이 없다', () {
      expect(TransitDeparture.tryParse(departure(departAt: null)), isNull);
      expect(TransitDeparture.tryParse(departure(departAt: '엉뚱한 값')), isNull);
    });

    test('타임존을 붙이지 않는다 — 9시간 밀리면 다른 날 차가 된다', () {
      // 서버가 한국 시각으로 내리고 사용자도 한국에서 본다
      final d = TransitDeparture.tryParse(departure())!;
      expect(d.departAt.isUtc, isFalse);
      expect(d.departAt.hour, 7);
    });

    test('목록이 없거나 모양이 다르면 빈 목록이다', () {
      // 창 밖 날짜·운행 없음·막차 지남이 모두 이 경우다 — 정상이다
      expect(TransitDeparture.parseList(null), isEmpty);
      expect(TransitDeparture.parseList('아무 값'), isEmpty);
      expect(TransitAccess.tryParse(raw())!.departures, isEmpty);
    });

    testWidgets('접힌 채로 다음 차 한 편만 보여준다', (tester) async {
      // 여섯 편이 다 펼쳐지면 카드가 화면 절반을 먹어 정작 코스가 안 보인다.
      // 그래도 한 편은 남긴다 — 표를 끊으려면 결국 시각을 봐야 한다
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            departures: [
              departure(),
              departure(
                vehicleType: 'KTX-이음',
                departAt: '2026-09-05T09:05:00',
                arriveAt: '2026-09-05T10:31:00',
              ),
            ],
          ),
        )!,
      );

      expect(find.text('07:20 → 09:49'), findsOneWidget);
      expect(find.text('무궁화호'), findsOneWidget);
      expect(find.text('09:05 → 10:31'), findsNothing);
      // 몇 편이 더 있는지 알려야 누를 값어치를 판단한다
      expect(find.text('다음 차 1편 더 보기'), findsOneWidget);
    });

    testWidgets('버튼을 누르면 나머지가 펼쳐지고 다시 접힌다', (tester) async {
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            departures: [
              departure(),
              departure(
                vehicleType: 'KTX-이음',
                departAt: '2026-09-05T09:05:00',
                arriveAt: '2026-09-05T10:31:00',
              ),
            ],
          ),
        )!,
      );

      await tester.tap(find.text('다음 차 1편 더 보기'));
      await tester.pumpAndSettle();

      expect(find.text('09:05 → 10:31'), findsOneWidget);
      expect(find.text('KTX-이음'), findsOneWidget);

      await tester.tap(find.text('접기'));
      await tester.pumpAndSettle();

      expect(find.text('09:05 → 10:31'), findsNothing);
    });

    testWidgets('한 편뿐이면 버튼이 없다 — 펼칠 것이 없다', (tester) async {
      await pump(
        tester,
        TransitAccess.tryParse(raw(departures: [departure()]))!,
      );

      expect(find.text('07:20 → 09:49'), findsOneWidget);
      expect(find.textContaining('더 보기'), findsNothing);
    });

    testWidgets('시간표가 없으면 그 줄만 접는다 — 소요시간은 그대로 그린다', (tester) async {
      // "가끔 안 나온다"가 아니라 "그 날짜엔 원래 없다"다
      await pump(
        tester,
        TransitAccess.tryParse(raw(fromPlace: '동서울', durationMinutes: 149))!,
      );

      expect(find.text('동서울에서 출발 • 약 2시간 29분'), findsOneWidget);
      expect(find.textContaining('→'), findsNothing);
    });

    testWidgets('새 코스가 오면 시간표가 다시 접힌다', (tester) async {
      // 수단을 바꿔 서버가 새 코스를 주면 다른 수단의 시간표다 — 펼친 채로
      // 넘어가면 그 시간표가 통째로 펼쳐져 있다
      TransitAccess access(List<Object> departures) =>
          TransitAccess.tryParse(raw(modeLabel: '열차', departures: departures))!;
      await pump(
        tester,
        access([departure(), departure(departAt: '2026-09-05T09:05:00')]),
      );
      await tester.tap(find.text('다음 차 1편 더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('09:05 → 09:49'), findsOneWidget);

      await pump(
        tester,
        access([
          departure(
            vehicleType: '우등',
            departAt: '2026-09-05T08:10:00',
            arriveAt: '2026-09-05T10:40:00',
          ),
          departure(
            vehicleType: '우등',
            departAt: '2026-09-05T14:10:00',
            arriveAt: '2026-09-05T16:40:00',
          ),
        ]),
      );

      expect(find.text('08:10 → 10:40'), findsOneWidget);
      expect(find.text('14:10 → 16:40'), findsNothing);
      expect(find.text('다음 차 1편 더 보기'), findsOneWidget);
    });
  });

  group('출발지를 모르는 코스 (core #423)', () {
    // 좌표 없이 저장된 옛 코스다. 예전에는 `transitAccess` 필드가 통째로
    // 빠져 "값을 모르는 옛 서버"와 구분되지 않았다. 서버가 상태를 만들어
    // 이제 이유를 말한다
    Map<String, dynamic> originUnknown() => {
      'status': 'ORIGIN_UNKNOWN',
      'mode': null,
      'modeLabel': null,
      'fromPlace': null,
      'toPlace': null,
      'vehicleType': null,
      'durationMinutes': null,
      'distanceKm': null,
      'alternatives': const [],
      'departures': const [],
    };

    test('카드를 그리지 않는다 — 수단도 내리는 곳도 없다', () {
      // 고칠 수 없는 사정이다. 원본 출발지가 사라져 되살릴 방법이 없어
      // (core #423), 안내로 띄워 봐야 답답하기만 하다
      expect(TransitAccess.tryParse(originUnknown()), isNull);
    });

    test('상태 이름을 안다 — UNAVAILABLE과 뭉치지 않는다', () {
      // 외부 장애가 아니라 우리 데이터가 빈 것이라 서버가 갈라 놓았다.
      // 앱이 이 값을 모르면 그 구분이 여기서 도로 사라진다
      expect(
        TransitStatus.parse('ORIGIN_UNKNOWN'),
        TransitStatus.originUnknown,
      );
      expect(
        TransitStatus.parse('ORIGIN_UNKNOWN'),
        isNot(TransitStatus.unavailable),
      );
    });

    test('서버가 상태를 더 늘려도 화면이 안 죽는다', () {
      // 모르는 값은 unavailable로 받는다
      expect(TransitStatus.parse('BRAND_NEW'), TransitStatus.unavailable);
      expect(TransitStatus.parse(null), TransitStatus.unavailable);
    });
  });
}
