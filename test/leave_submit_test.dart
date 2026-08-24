import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/leave/presentation/leave_register_screen.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';

/// 서버를 부르지 않고 결과만 흉내내는 대역
class _FakeLeaveRepository implements LeaveRepository {
  _FakeLeaveRepository({this.fail = false});

  final bool fail;
  bool called = false;

  /// 마지막 등록 요청의 사유·메모 — 합쳐 보내지 않고 따로 가는지 본다
  String? sentReason;
  String? sentMemo;

  @override
  Future<void> addUsage({
    required DateTime usedOn,
    required double days,
    String? reason,
    String? memo,
    int? courseId,
  }) async {
    called = true;
    sentReason = reason;
    sentMemo = memo;
    if (fail) throw ApiException(status: 400, code: 'X', detail: '');
  }

  /// 차감 일수 계산은 실패로 친다 — 화면이 로컬 근사로 폴백해 바로 확정할 수 있다
  @override
  Future<AvailableTime> availableTime({
    required String transport,
    DateTime? startDate,
    DateTime? endDate,
    String? periodStyle,
    DateTime? baseDate,
    String? weekendBridge,
    int? leaveDays,
  }) async => throw const ApiException(
    status: 0,
    code: 'TEST',
    detail: '테스트에는 서버가 없어요',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, LeaveRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        leaveRepositoryProvider.overrideWithValue(repo),
        homeSnapshotProvider.overrideWith(
          (ref) async => const HomeSnapshot(
            user: {'nickname': '예빈', 'remainingLeaveDays': 23.0},
            regions: [],
          ),
        ),
      ],
      child: const MaterialApp(home: LeaveRegisterScreen()),
    ),
  );
  await tester.pump();
}

/// 날짜 칸을 눌러 캘린더에서 하루를 고른다.
///
/// 주말을 고르면 차감 일수가 0일이 되어(평일만 센다) 등록이 잠긴다 —
/// 테스트가 도는 요일에 흔들리지 않도록 이번 달의 평일을 고른다.
Future<void> _pickOneDay(WidgetTester tester) async {
  await tester.tap(find.text('날짜를 선택해 주세요'));
  await tester.pumpAndSettle();
  final today = DateTime.now();
  var target = today;
  while (target.weekday == DateTime.saturday ||
      target.weekday == DateTime.sunday) {
    target = target.add(const Duration(days: 1));
  }
  // 같은 날을 두 번 눌러 하루짜리 범위를 만든다
  final day = find.text('${target.day}').first;
  await tester.tap(day);
  await tester.pump();
  await tester.tap(day);
  await tester.pump();
  // 차감 일수 계산이 끝나야 '선택 완료'가 열린다
  await tester.pumpAndSettle();
  await tester.tap(find.text('선택 완료'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('날짜를 고르기 전에는 서버를 부르지 않는다', (tester) async {
    final repo = _FakeLeaveRepository();
    await _pump(tester, repo);

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repo.called, isFalse);
  });

  testWidgets('등록에 실패하면 안내 토스트가 뜬다', (tester) async {
    final repo = _FakeLeaveRepository(fail: true);
    await _pump(tester, repo);
    await _pickOneDay(tester);

    await tester.tap(find.text('등록하기'));
    await tester.pump();
    await tester.pump();

    expect(repo.called, isTrue);
    expect(find.text('등록에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
  });

  testWidgets('등록에 성공하면 완료 토스트와 함께 돌아간다', (tester) async {
    final repo = _FakeLeaveRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveRepositoryProvider.overrideWithValue(repo),
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '예빈', 'remainingLeaveDays': 23.0},
              regions: [],
            ),
          ),
        ],
        child: MaterialApp(
          // 등록 후 pop 하므로 되돌아갈 화면이 있어야 한다
          home: const Scaffold(body: Text('내 연차')),
          builder: (context, child) => child!,
          routes: {},
        ),
      ),
    );
    await tester.pump();

    // 내 연차 위에 등록 화면을 얹어 실제 흐름과 같게 만든다
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const LeaveRegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await _pickOneDay(tester);
    // 상세 메모 칸(50자 제한인 TextField)에 적는다 — 사유 칩은 기본값 '여행'.
    // 차감 일수 칸도 TextField라 순서로 집으면 그쪽을 건드린다
    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.maxLength == 50),
      '제주 갈 예정',
    );
    await tester.pump();
    await tester.tap(find.text('등록하기'));
    await tester.pump();
    await tester.pump();

    expect(repo.called, isTrue);
    // 사유와 메모는 따로 간다(core #323) — 예전처럼 '여행 · 제주 갈 예정'으로
    // 합치지 않는다
    expect(repo.sentReason, '여행');
    expect(repo.sentMemo, '제주 갈 예정');
    expect(find.text('등록 완료! 남은 연차를 확인해보세요.'), findsOneWidget);

    // 뒤에 있던 내 연차 화면이 다시 드러난다
    expect(find.text('내 연차'), findsOneWidget);
  });
}
