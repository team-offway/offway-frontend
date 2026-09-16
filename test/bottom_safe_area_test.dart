import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/utils/bottom_inset.dart';

/// 화면 맨 아래 홈 인디케이터 자리 처리 (#300).
///
/// `SafeArea` 를 그냥 두면 iOS 가 그 자리를 잘라내고 Scaffold 배경만 남겨,
/// 화면 아래에 **흰 띠가 하나 더 있는 것처럼** 보인다. 스크롤이 끝인 화면은
/// `bottom: false` 로 두고 목록 끝 여백에만 인디케이터 높이를 더한다.
void main() {
  const inset = 34.0; // 홈 인디케이터가 있는 기기

  Widget wrap(Widget child) => MediaQuery(
    data: const MediaQueryData(padding: EdgeInsets.only(bottom: inset)),
    child: MaterialApp(home: child),
  );

  testWidgets('bottomInset 은 기기의 홈 인디케이터 높이다', (tester) async {
    late double read;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            read = context.bottomInset;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(read, inset);
  });

  testWidgets('인디케이터가 없는 기기에서는 0 — 상수로 박으면 그 기기에 여백이 뜬다', (tester) async {
    late double read;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              read = context.bottomInset;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(read, 0);
  });

  testWidgets('bottom: false 면 내용이 인디케이터 아래까지 흐른다', (tester) async {
    // SafeArea 를 그냥 두면 잘려서 그 자리에 배경만 남는다 — 그게 흰 띠다
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: const [SizedBox(height: 2000), Text('마지막')],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final screen = tester.getSize(find.byType(MaterialApp)).height;
    final list = tester.getRect(find.byType(ListView));
    expect(list.bottom, screen, reason: 'bottom: false 라 스크롤 영역이 화면 끝까지 닿는다');
  });

  testWidgets('SafeArea 를 그냥 두면 그만큼 잘린다 — 고치기 전 상태', (tester) async {
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: SafeArea(
            child: ListView(
              children: const [SizedBox(height: 2000), Text('마지막')],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final screen = tester.getSize(find.byType(MaterialApp)).height;
    final list = tester.getRect(find.byType(ListView));
    expect(
      list.bottom,
      screen - inset,
      reason: '잘린 자리에 Scaffold 배경만 남아 흰 띠로 보였다',
    );
  });
}
