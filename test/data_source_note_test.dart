import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/data_source_note.dart';

/// 공공데이터 출처 표기 (core #417).
///
/// 공모전 규정이 요구한다 — **누락이 곧 위반**이라 "가끔 빠진다"가 허용되지
/// 않는다. 그래서 조용히 사라지는 경로를 막는 축으로 테스트를 짠다.
void main() {
  const kto = DataSource(key: 'KTO', label: '한국관광공사');
  const permit = DataSource(key: 'LOCAL_PERMIT', label: '지방행정인허가데이터개방');

  Future<void> pump(WidgetTester tester, List<DataSource> sources) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: DataSourceNote(sources: sources)),
        ),
      );

  group('문구', () {
    test('기관마다 저작권 기호를 붙이고 가운뎃점으로 잇는다', () {
      // 한 번만 붙이면 뒤쪽 기관이 앞 기관의 부속처럼 읽힌다
      expect(
        const DataSourceNote(sources: [kto, permit]).label,
        '출처: ©한국관광공사 · ©지방행정인허가데이터개방',
      );
    });

    test('본문 서체에 있는 기호를 쓴다 — 규정 문서의 ⓒ는 두부로 깨진다', () {
      // Pretendard에 원문자 소문자(U+24D2) 글리프가 없다. 화면에서 안 보이면
      // 표기가 없는 것과 같아 규정 위반이다
      final label = const DataSourceNote(sources: [kto]).label;
      expect(label, contains('©'));
      expect(label, isNot(contains('ⓒ')));
    });

    test('서버가 준 순서를 지킨다 — 요청마다 차례가 바뀌면 안 된다', () {
      expect(
        const DataSourceNote(sources: [permit, kto]).label,
        '출처: ©지방행정인허가데이터개방 · ©한국관광공사',
      );
    });
  });

  group('화면', () {
    testWidgets('기관명을 서버가 준 말 그대로 그린다', (tester) async {
      // 앱이 매핑 표를 들면 출처가 하나 늘었을 때 그리지 못해, 앱 배포
      // 전까지 그 화면의 표기가 빈다 — 그 공백이 그대로 규정 위반이다
      await pump(tester, const [kto, permit]);

      expect(find.text('출처: ©한국관광공사 · ©지방행정인허가데이터개방'), findsOneWidget);
    });

    testWidgets('출처가 없으면 자리도 없다', (tester) async {
      // 고정 문구로 채우면 안 쓴 출처를 표기하게 되고, 그것도 잘못된 표기다.
      // 인허가 장소만 실린 화면에 한국관광공사를 붙이는 것이 그 경우다
      await pump(tester, const []);

      expect(find.textContaining('출처'), findsNothing);
      expect(tester.getSize(find.byType(DataSourceNote)), Size.zero);
    });
  });

  group('응답 파싱', () {
    test('래퍼의 sources를 읽는다', () {
      final sources = DataSource.parseList(const [
        {'key': 'KTO', 'label': '한국관광공사'},
        {'key': 'KMA', 'label': '기상청'},
      ]);

      expect(sources, [kto, const DataSource(key: 'KMA', label: '기상청')]);
    });

    test('라벨이 없는 항목은 버린다 — 빈칸을 그리느니 뺀다', () {
      expect(
        DataSource.parseList(const [
          {'key': 'KTO'},
        ]),
        isEmpty,
      );
      expect(
        DataSource.parseList(const [
          {'key': 'KTO', 'label': ' '},
        ]),
        isEmpty,
      );
    });

    test('키를 모르는 출처도 그린다 — 서버가 늘려도 앱 배포를 기다리지 않는다', () {
      // 앱이 아는 값만 그리면 새 기관의 표기가 배포 전까지 빈다
      final sources = DataSource.parseList(const [
        {'key': 'BRAND_NEW', 'label': '새로 생긴 기관'},
      ]);

      expect(sources.single.label, '새로 생긴 기관');
    });

    test('없거나 모양이 다르면 빈 목록이다', () {
      // 실패 응답과 data 없는 성공에는 안 실린다 — 빌려온 값이 없으니
      // 표기할 것도 없다
      expect(DataSource.parseList(null), isEmpty);
      expect(DataSource.parseList('아무 값'), isEmpty);
    });
  });
}
