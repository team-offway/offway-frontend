import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/application/course_providers.dart';
import 'package:offway/features/course/presentation/my_courses_screen.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/widgets/async_retry.dart';

/// 내 코스 목록은 **세션 동안 들고 있는다**(#392).
///
/// autoDispose 였을 때는 탭을 옮길 때마다 버려져, 내 코스 탭에 들어올 때마다
/// 스켈레톤부터 다시 떴다.
void main() {
  Map<String, dynamic> card(String region) => {
    'id': region,
    'courseId': region,
    'regionId': '1',
    'regionName': region,
    'durationLabel': '1박2일',
    'confirmed': false,
    'leaveDeducted': false,
  };

  testWidgets('다시 들어오면 옛 목록을 바로 보이며 새로 받는다', (tester) async {
    var calls = 0;
    Completer<void>? gate;
    final container = ProviderContainer(
      overrides: [
        savedCoursesProvider.overrideWith((ref, scope) async {
          calls++;
          await gate?.future;
          return [card(calls == 1 ? '정선' : '영월')];
        }),
      ],
    );
    addTearDown(container.dispose);

    Widget screen(bool show) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: show ? const MyCoursesScreen() : const SizedBox(),
      ),
    );

    // 첫 진입
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(find.textContaining('정선', findRichText: true), findsWidgets);

    // 다른 탭으로 갔다가(화면이 사라진다) 다시 들어온다
    await tester.pumpWidget(screen(false));
    await tester.pumpAndSettle();
    gate = Completer<void>();
    await tester.pumpWidget(screen(true));
    await tester.pump();
    await tester.pump();

    // 새로 받는 동안에도 옛 목록이 보인다 — 스켈레톤이 아니다
    expect(find.textContaining('정선', findRichText: true), findsWidgets);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('영월', findRichText: true), findsWidgets);
    expect(calls, 2);
  });

  testWidgets('계정이 바뀐 뒤 들어오면 앞사람의 목록이 보이지 않는다', (tester) async {
    var account = 'A';
    Completer<void>? gate;
    final container = ProviderContainer(
      overrides: [
        savedCoursesProvider.overrideWith((ref, scope) async {
          await gate?.future;
          return [card(account == 'A' ? '정선' : '영월')];
        }),
      ],
    );
    addTearDown(container.dispose);

    Widget screen(bool show) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: show ? const MyCoursesScreen() : const SizedBox(),
      ),
    );

    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(find.textContaining('정선', findRichText: true), findsWidgets);

    // 로그아웃 — 화면을 떠나고 목록을 비운다(asReload)
    await tester.pumpWidget(screen(false));
    container.invalidate(savedCoursesProvider, asReload: true);
    account = 'B';
    gate = Completer<void>();

    // 다른 계정으로 다시 들어온다 — 받는 동안 앞사람 목록이 보이면 안 된다
    await tester.pumpWidget(screen(true));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('정선', findRichText: true), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('영월', findRichText: true), findsWidgets);
    expect(find.textContaining('정선', findRichText: true), findsNothing);
  });

  testWidgets('탭에 들어올 때 보고 있는 칩만 새로 받는다 — 예정 목록은 건드리지 않는다', (tester) async {
    // 예정 목록(UPCOMING)은 잠금화면 컨트롤러가 구독한다. 그것까지 다시 받으면
    // 탭에 들어올 때마다 잠금화면·위젯 맞추기가 한 번씩 돌았다
    final calls = <String, int>{};
    final container = ProviderContainer(
      overrides: [
        savedCoursesProvider.overrideWith((ref, scope) async {
          calls[scope] = (calls[scope] ?? 0) + 1;
          return [card('정선')];
        }),
      ],
    );
    addTearDown(container.dispose);
    // 잠금화면 컨트롤러처럼 예정 목록을 붙잡고 있는다
    container.listen(savedCoursesProvider('UPCOMING'), (_, _) {});
    await container.read(savedCoursesProvider('UPCOMING').future);

    Widget screen(bool show) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: show ? const MyCoursesScreen() : const SizedBox(),
      ),
    );

    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen(false));
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();

    expect(calls['UPCOMING'], 1);
    expect(calls['ALL'], greaterThanOrEqualTo(2));
  });

  testWidgets('실패한 칩으로 돌아와도 누르지 않은 다시 시도의 토스트가 뜨지 않는다', (tester) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        savedCoursesProvider.overrideWith((ref, scope) async {
          if (scope == 'PAST') {
            throw const ApiException(status: 500, code: 'X', detail: '서버 오류');
          }
          return [card('정선')];
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MyCoursesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('지난 여행'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지난 여행'));
    await tester.pumpAndSettle();

    expect(find.text(retryFailedMessage), findsNothing);
  });
}
