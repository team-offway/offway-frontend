import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/domain/transit_access.dart';
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
    List<Object>? alternatives,
  }) => {
    'mode': 'INTERCITY_BUS',
    'modeLabel': modeLabel,
    'status': status,
    'fromPlace': fromPlace,
    'toPlace': toPlace,
    'vehicleType': vehicleType,
    'durationMinutes': durationMinutes,
    'alternatives': alternatives ?? const [],
  };

  group('응답 파싱', () {
    test('자차 코스는 값이 없다', () {
      // 저장된 코스도 null이다 — 서버가 안 싣는다
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
      expect(find.text('청량리에서 출발 · KTX · 약 3시간'), findsOneWidget);
    });

    testWidgets('내리는 곳을 모르면 통째로 접는다', (tester) async {
      await pump(tester, TransitAccess.tryParse(raw(toPlace: null))!);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('대안 수단은 소요시간을 알면 그것을 보여준다', (tester) async {
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            alternatives: [
              {'modeLabel': '열차', 'toPlace': '대천', 'durationMinutes': 180},
            ],
          ),
        )!,
      );
      expect(find.text('열차 · 3시간'), findsOneWidget);
    });

    testWidgets('소요시간을 모르면 어디에 내리는지라도 말한다', (tester) async {
      // 버스·여객선은 시간표를 못 물어 시간이 비는 일이 흔하다.
      // 수단 이름만 남으면 무엇을 알려 주는지 흐려진다
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            alternatives: [
              {'modeLabel': '열차', 'toPlace': '대천'},
            ],
          ),
        )!,
      );
      expect(find.text('열차 · 대천'), findsOneWidget);
    });

    testWidgets('둘 다 모르면 수단 이름만 남는다', (tester) async {
      await pump(
        tester,
        TransitAccess.tryParse(
          raw(
            alternatives: [
              {'modeLabel': '여객선'},
            ],
          ),
        )!,
      );
      expect(find.text('여객선'), findsOneWidget);
    });
  });
}
