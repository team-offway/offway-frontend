import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/curated_link_section.dart';
import 'package:offway/features/region/presentation/region_detail_screen.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/fake_url_launcher.dart';

/// 서버가 고른 외부 링크 (core #350) — 파싱 규칙과 접힘 규칙을 고정한다.
///
/// `description`·`thumbnailUrl`은 **null로 올 수 있고 키는 사라지지 않는다**는
/// 것이 서버와의 약속이다. 그 자리를 접는지, 없는 응답에서 섹션째 접히는지를
/// 본다 — 빈 섹션이 화면 끝에 붙으면 고장난 것처럼 보인다.
void main() {
  /// 실제 응답 한 건 (`/api/v1/home`에서 실측)
  Map<String, dynamic> link({
    Object? title = '코레일 승차권 예매',
    Object? chipText = '기차표 예매',
    Object? linkUrl = 'https://www.letskorail.com',
    Object? description = '한국철도공사 공식 예매.',
    Object? thumbnailUrl,
  }) => {
    'id': 3,
    'title': title,
    'chipText': chipText,
    'linkUrl': linkUrl,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
  };

  Future<void> pumpSection(WidgetTester tester, List<CuratedLink> links) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(children: [CuratedLinkSection(links: links)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('응답 파싱', () {
    test('키가 없으면 빈 목록이다', () {
      // 옛 서버 응답에는 curatedLinks 자체가 없다 — 터지지 않고 접혀야 한다
      expect(CuratedLink.parseList(null), isEmpty);
      expect(CuratedLink.parseList(const []), isEmpty);
    });

    test('배열이 아닌 값이 와도 화면을 무너뜨리지 않는다', () {
      // 링크는 화면에 덤으로 붙는 자리다 — 이 값 하나 때문에 홈이나
      // 코스가 통째로 못 뜨는 쪽이 훨씬 나쁘다
      expect(CuratedLink.parseList('nope'), isEmpty);
      expect(CuratedLink.parseList(42), isEmpty);
      expect(CuratedLink.parseList(const {'a': 1}), isEmpty);
    });

    test('성하지 않은 항목이 섞여도 나머지를 그린다', () {
      final parsed = CuratedLink.parseList([link(), 'nope', 42, null]);
      expect(parsed, hasLength(1));
    });

    test('description·thumbnailUrl이 null이어도 링크는 산다', () {
      final parsed = CuratedLink.parseList([
        link(description: null, thumbnailUrl: null),
      ]);

      expect(parsed, hasLength(1));
      expect(parsed.single.title, '코레일 승차권 예매');
      expect(parsed.single.description, isNull);
      expect(parsed.single.thumbnailUrl, isNull);
    });

    test('빈 문자열은 없는 것으로 친다', () {
      // 그대로 그리면 자리만 차지하는 빈 줄이 된다
      final parsed = CuratedLink.parseList([
        link(description: '  ', thumbnailUrl: ''),
      ]);

      expect(parsed.single.description, isNull);
      expect(parsed.single.thumbnailUrl, isNull);
    });

    test('제목이나 주소가 비면 그 건을 버린다', () {
      // 누를 데가 없는 줄은 고장으로 읽힌다
      expect(CuratedLink.parseList([link(linkUrl: '')]), isEmpty);
      expect(CuratedLink.parseList([link(title: '')]), isEmpty);
      expect(CuratedLink.parseList([link(linkUrl: null)]), isEmpty);
    });

    test('https가 아닌 주소는 버린다', () {
      // 서버도 저장할 때 막지만(core #350), 웹뷰에 주소를 넘기는 것은 앱이다.
      // 목록에 남겨 두고 누를 때 막으면 눌러도 아무 일이 없는 카드가 된다
      for (final bad in const [
        'http://www.letskorail.com', // 암호화되지 않은 채로 오간다
        'javascript:alert(1)', // 웹뷰에서 열 것이 아니다
        'data:text/html,<h1>x', //
        'www.letskorail.com', // 스킴이 없다
        'https:///path', // 스킴만 맞고 갈 곳이 없다
      ]) {
        expect(
          CuratedLink.parseList([link(linkUrl: bad)]),
          isEmpty,
          reason: '$bad 는 열지 않아야 한다',
        );
      }
    });

    test('대문자 스킴도 https면 받는다', () {
      // Uri가 스킴을 소문자로 정규화한다 — 멀쩡한 주소를 버리지 않는다
      final parsed = CuratedLink.parseList([
        link(linkUrl: 'HTTPS://www.letskorail.com'),
      ]);
      expect(parsed, hasLength(1));
    });

    test('성한 건만 남기고 나머지는 그린다', () {
      final parsed = CuratedLink.parseList([link(), link(title: null)]);
      expect(parsed, hasLength(1));
    });
  });

  group('섹션 그리기', () {
    testWidgets('칩·제목·설명을 함께 보여준다', (tester) async {
      await pumpSection(tester, CuratedLink.parseList([link()]));

      expect(find.text('함께 보면 좋아요'), findsOneWidget);
      expect(find.text('기차표 예매'), findsOneWidget);
      expect(find.text('코레일 승차권 예매'), findsOneWidget);
      expect(find.text('한국철도공사 공식 예매.'), findsOneWidget);
    });

    testWidgets('설명이 없으면 그 줄만 접고 제목은 남긴다', (tester) async {
      await pumpSection(
        tester,
        CuratedLink.parseList([link(description: null)]),
      );

      expect(find.text('코레일 승차권 예매'), findsOneWidget);
      expect(find.text('한국철도공사 공식 예매.'), findsNothing);
    });

    testWidgets('링크가 없으면 제목까지 통째로 접는다', (tester) async {
      await pumpSection(tester, const []);
      expect(find.text('함께 보면 좋아요'), findsNothing);
    });

    testWidgets('바깥으로 나가는 링크임을 읽어 줄 수 있다', (tester) async {
      // 화면 안 이동(쉐브론)과 구분되어야 한다
      final handle = tester.ensureSemantics();
      await pumpSection(tester, CuratedLink.parseList([link()]));

      expect(find.bySemanticsLabel('코레일 승차권 예매 웹사이트 열기'), findsOneWidget);
      handle.dispose();
    });
  });

  group('링크 열기', () {
    testWidgets('카드를 누르면 앱 안 브라우저로 연다', (tester) async {
      // 여행 정보를 하나 더 보려고 앱을 떠날 이유가 없다 — 닫으면
      // 보던 화면으로 돌아온다
      final launcher = FakeUrlLauncher.install();
      await pumpSection(tester, CuratedLink.parseList([link()]));

      await tester.tap(find.text('코레일 승차권 예매'));
      await tester.pumpAndSettle();

      expect(launcher.lastUrl, 'https://www.letskorail.com');
      expect(launcher.lastMode, PreferredLaunchMode.inAppBrowserView);
      expect(launcher.launchCount, 1);
    });

    testWidgets('못 열면 주의 토스트로 알린다', (tester) async {
      final launcher = FakeUrlLauncher.install();
      launcher.succeeds = false;
      await pumpSection(tester, CuratedLink.parseList([link()]));

      await tester.tap(find.text('코레일 승차권 예매'));
      await tester.pumpAndSettle();

      expect(find.text('페이지를 열지 못했어요.'), findsOneWidget);
    });

    testWidgets('플러그인이 예외를 던져도 토스트로 알린다', (tester) async {
      // url_launcher는 실패를 false로도, 예외로도 알린다. 던지는 쪽을
      // 놓치면 화면에 아무 일도 안 일어나 버튼이 고장난 것처럼 보인다
      final launcher = FakeUrlLauncher.install();
      launcher.throws = true;
      await pumpSection(tester, CuratedLink.parseList([link()]));

      await tester.tap(find.text('코레일 승차권 예매'));
      await tester.pumpAndSettle();

      expect(find.text('페이지를 열지 못했어요.'), findsOneWidget);
    });
  });

  group('지역 상세', () {
    Future<void> pumpRegion(
      WidgetTester tester, {
      List<CuratedLink> links = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            regionDetailProvider('정선').overrideWith(
              (ref) async => {
                'id': '정선',
                'name': '정선 · 강원',
                'photos': const <String>[],
                'highlightSpots': const <Map<String, dynamic>>[],
                'curatedLinks': links,
              },
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const RegionDetailScreen(regionId: '정선'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('링크가 오면 마무리 안내 앞에 끼워 넣는다', (tester) async {
      await pumpRegion(tester, links: CuratedLink.parseList([link()]));

      await tester.scrollUntilVisible(
        find.text('함께 보면 좋아요'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('기차표 예매'), findsOneWidget);
      // 화면을 맺는 말은 그대로 끝에 남는다
      await tester.scrollUntilVisible(
        find.text('새롭게 주목받는 인구감소지역이에요'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    });

    testWidgets('링크가 없으면 섹션이 없다', (tester) async {
      await pumpRegion(tester);
      expect(find.text('함께 보면 좋아요'), findsNothing);
    });
  });
}
