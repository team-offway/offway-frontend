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
  };

  group('응답 파싱', () {
    test('값이 없으면 그리지 않는다', () {
      // 옛 서버 응답과, 출발지를 모르는 옛 저장 코스가 null로 온다
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

    testWidgets('갈아끼우면 거리를 물려받지 않는다', (tester) async {
      // 출발지→도착 지점의 값이라, 다른 터미널에 내리는 수단으로 바꾸면
      // 다른 거리다 — 출발지를 안 물려주는 것과 같은 논리
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TransitAccessCard(
              access: TransitAccess.tryParse(
                raw(
                  distanceKm: 200,
                  alternatives: [
                    {'modeLabel': '열차', 'toPlace': '민둥산'},
                  ],
                ),
              )!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('열차로 보기'));
      await tester.pumpAndSettle();

      expect(find.textContaining('200km'), findsNothing);
    });
  });

  group('화면', () {
    Future<void> pump(WidgetTester tester, TransitAccess access) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: TransitAccessCard(access: access)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('무엇을 타고 어디에 내리는지 말한다', (tester) async {
      await pump(tester, TransitAccess.tryParse(raw())!);
      expect(find.text('시외버스로 정선까지'), findsOneWidget);
    });

    testWidgets('아는 만큼만 덧붙인다', (tester) async {
      // 버스는 시간표를 못 물어 소요시간이 없다 — 출발지만 알린다
      await pump(tester, TransitAccess.tryParse(raw(fromPlace: '동서울'))!);
      expect(find.text('동서울에서 출발'), findsOneWidget);
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
      // 서버가 소요시간을 아직 못 잰 구간은 출발지·편명·시간이 모두 비어
      // 둘째 줄이 통째로 없다. 그때 점선까지 사라지면 같은 카드가 지역마다
      // 다르게 보인다
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

    testWidgets('버튼을 누르면 그 수단으로 갈아끼운다', (tester) async {
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            fromPlace: '동서울',
            alternatives: [
              {'modeLabel': '열차', 'toPlace': '민둥산', 'durationMinutes': 180},
            ],
          ),
        )!,
      );

      await tester.tap(find.text('열차로 보기'));
      await tester.pumpAndSettle();

      expect(find.text('열차로 민둥산까지'), findsOneWidget);
      expect(find.text('약 3시간'), findsOneWidget);
      // 되돌아갈 길이 남아야 한다 — 목록에서 빼 버리면 갇힌다
      expect(find.text('시외버스로 보기'), findsOneWidget);
    });

    testWidgets('갈아끼우면 출발지를 물려받지 않는다', (tester) async {
      // 서버는 대안에 fromPlace를 싣지 않는다(TransitOptionResponse).
      // 지금 값을 그대로 두면 열차로 바꿨는데 '동서울에서 출발'이라 말한다 —
      // 수단이 다르면 타는 곳도 다르다
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            fromPlace: '동서울',
            alternatives: [
              {'modeLabel': '열차', 'toPlace': '민둥산'},
            ],
          ),
        )!,
      );

      await tester.tap(find.text('열차로 보기'));
      await tester.pumpAndSettle();

      expect(find.textContaining('동서울'), findsNothing);
    });

    testWidgets('다시 누르면 첫 화면 그대로 돌아온다', (tester) async {
      // 대표를 대안 목록에 접어 넣는 식으로 맞바꾸면, 서버가 대안에 싣지 않는
      // 출발지·편명이 그때 사라져 두 번 눌러 돌아왔을 때 '서울에서 출발'이
      // 빠진 채로 남았다
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            fromPlace: '동서울',
            vehicleType: '우등',
            durationMinutes: 149,
            alternatives: [
              {'modeLabel': '열차', 'toPlace': '민둥산', 'durationMinutes': 180},
            ],
          ),
        )!,
      );
      final before = tester.widget<Text>(find.text('동서울에서 출발 • 우등 약 2시간 29분'));

      await tester.tap(find.text('열차로 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시외버스로 보기'));
      await tester.pumpAndSettle();

      expect(find.text('시외버스로 정선까지'), findsOneWidget);
      expect(find.text(before.data!), findsOneWidget);
    });

    testWidgets('갈 수 있는 수단이 하나뿐이면 버튼이 없다', (tester) async {
      // 자차가 그렇다 — 갈아낄 것이 없는데 버튼만 두면 누를 데가 없다
      await pump(tester, TransitAccess.tryParse(raw())!);
      expect(find.textContaining('로 보기'), findsNothing);
    });
  });
}
