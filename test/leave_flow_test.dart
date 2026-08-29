import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/course/data/course_repository.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/leave/presentation/leave_register_screen.dart';
import 'package:offway/features/leave/presentation/leave_date_picker_screen.dart';
import 'package:offway/features/leave/presentation/leave_usages_screen.dart';
import 'package:offway/features/leave/presentation/my_leave_screen.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';

/// 화면 검증용 내역 — 직접 등록 2건 + 코스 차감 1건
final _sampleUsages = [
  LeaveUsage(
    id: 1,
    usedOn: DateTime(2026, 6, 12),
    days: 1,
    reason: '개인 사유 · 코로나에 걸렸음 콜록콜ㄱ록 아이고',
  ),
  LeaveUsage(
    id: 2,
    usedOn: DateTime(2026, 6, 12),
    days: 1,
    reason: '개인 사유 · 청춘! 이는 듣기만 하여도 가슴이 설레는 말이다.',
  ),
  LeaveUsage(
    id: 3,
    usedOn: DateTime(2026, 6, 12),
    days: 1,
    courseId: 7,
    courseName: '정선 여행',
  ),
];

/// 삭제 요청만 기록하는 대역 — 서버를 부르지 않는다
class _RecordingLeaveRepository implements LeaveRepository {
  _RecordingLeaveRepository(this.deletedIds);

  /// 지운 내역 id — 상쇄 등록이 아니라 id로 지우는지 확인한다
  final List<int> deletedIds;

  @override
  Future<MyLeave> deleteUsage(int usageId) async {
    deletedIds.add(usageId);
    return const MyLeave(
      totalDays: 15,
      usedDays: 0,
      remainingDays: 15,
      usages: [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('연차 등록 화면: 날짜 전에는 차감 일수도 등록도 잠겨 있다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

    expect(find.text('연차 사용 등록'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsOneWidget);

    // 기본 선택 확인 — 브랜드색 글자가 골라진 칩이다
    final travel = tester.widget<Text>(find.text('여행'));
    expect(travel.style?.color, AppColors.primaryNormal);

    // 차감 일수는 날짜에서 계산되는 값이라 그전에는 섹션 자체가 없다
    expect(find.text('차감 일수'), findsNothing);
    expect(find.text('자동 계산된 값이에요. 다르게 썼다면 직접 수정할 수 있어요.'), findsNothing);

    // 날짜가 비어 있으므로 등록은 잠겨 있다
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('차감 일수는 숫자만 편집하고 연필을 누르면 바로 고칠 수 있다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveRepositoryProvider.overrideWithValue(
            _NoAvailableTimeRepository(),
          ),
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

    // 주말을 고르면 평일이 0일이라 차감 일수가 0이 된다 — 평일을 고른다
    await tester.tap(find.text('날짜를 선택해 주세요'));
    await tester.pumpAndSettle();
    var target = DateTime.now();
    while (target.weekday == DateTime.saturday ||
        target.weekday == DateTime.sunday) {
      target = target.add(const Duration(days: 1));
    }
    // 고를 날이 오늘이 아니면(오늘이 주말일 때) 그 칸이 첫 화면 아래로
    // 밀려 있을 수 있다 — 보이는 데까지 굴려 놓고 누른다
    final day = find.text('${target.day}').first;
    await tester.scrollUntilVisible(
      day,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(day);
    await tester.pump();
    await tester.tap(day);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();

    // 단위는 화면에만 붙는다 — 컨트롤러에는 숫자만 담겨 지워질 수 없다
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller?.text, isNot(contains('일')));
    expect(find.text('일'), findsOneWidget);

    // 연필을 누르면 입력 칸으로 커서가 가 지우기 아이콘으로 바뀐다
    expect(find.byIcon(Icons.cancel), findsNothing);
    await tester.tap(
      find
          .ancestor(
            of: find.byType(SvgPicture).last,
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cancel), findsOneWidget);

    // 값을 지우면 설명할 것이 없어 안내도 사라진다
    await tester.enterText(find.byType(TextField).last, '');
    await tester.pumpAndSettle();
    expect(find.text('차감 일수가 직접 입력한 값으로 수정됐어요.'), findsNothing);
    expect(find.text('자동 계산된 값이에요. 다르게 썼다면 직접 수정할 수 있어요.'), findsNothing);

    // 칸의 빈 자리를 눌러도 수정으로 들어간다 — 숫자 폭만큼만 TextField라
    // 그 바깥을 눌러도 닿아야 한다
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cancel), findsNothing);
    await tester.tap(find.text('일'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('입력 칸 밖을 누르면 키보드가 닫히고 칩은 그대로 눌린다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    // 포커스를 가진 노드가 실제 입력 칸의 것인지 견주어 본다
    bool memoHasFocus() {
      final memo = tester.widget<TextField>(find.byType(TextField).first);
      final node = FocusManager.instance.primaryFocus;
      return node != null &&
          node.context?.findAncestorWidgetOfExactType<TextField>() == memo;
    }

    expect(memoHasFocus(), isTrue, reason: '메모 칸에 포커스가 가야 한다');

    // 입력 칸 밖(라벨)을 누르면 포커스가 풀려 키보드가 내려간다
    await tester.tap(find.text('사유'));
    await tester.pumpAndSettle();
    expect(memoHasFocus(), isFalse, reason: '키보드가 내려가야 한다');

    // 탭을 삼키지 않아야 칩이 제 동작을 그대로 받는다
    await tester.tap(find.text('병가'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('병가')).style?.color,
      AppColors.primaryNormal,
    );
  });

  testWidgets('사용 내역: 코스 건만 펼쳐진다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith((ref) async => _sampleUsages),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('연차 사용 내역'), findsOneWidget);
    expect(find.text('코스 자세히 보기'), findsNothing);

    await tester.tap(find.text('정선 여행'));
    await tester.pumpAndSettle();
    expect(find.text('코스 자세히 보기'), findsOneWidget);

    // 다시 누르면 접힌다
    await tester.tap(find.text('정선 여행'));
    await tester.pumpAndSettle();
    expect(find.text('코스 자세히 보기'), findsNothing);
  });

  testWidgets('내 연차: 더보기로 들어가지 않아도 코스 건이 펼쳐진다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: 15,
              usedDays: 3,
              remainingDays: 12,
              usages: _sampleUsages,
            ),
          ),
          leaveUsagesProvider.overrideWith((ref) async => _sampleUsages),
        ],
        child: const MaterialApp(home: MyLeaveScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('코스 자세히 보기'), findsNothing);

    // 카드가 접힌 화면 아래쪽에 있어 스크롤해 올려야 탭이 닿는다
    await tester.ensureVisible(find.text('정선 여행'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정선 여행'));
    await tester.pumpAndSettle();
    expect(find.text('코스 자세히 보기'), findsOneWidget);
  });

  testWidgets('연차 사용일 선택: 2박3일 상한 없이 고를 수 있다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LeaveDatePickerScreen())),
    );
    await tester.pump();

    expect(find.text('연차 사용일 선택'), findsOneWidget);
    expect(find.text('사용한 연차 날짜를 선택해 주세요.'), findsOneWidget);
    // 여행 캘린더의 2박3일 안내 배너는 없어야 한다
    expect(find.textContaining('까지 선택할 수 있어요'), findsNothing);

    final done = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(done.onPressed, isNull, reason: '날짜를 안 골랐으면 잠겨 있어야 한다');
  });

  testWidgets('연차 사용일 선택: 하루를 한 번만 눌러도 선택 완료가 열린다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 차감 일수 계산이 끝나야 버튼이 열린다 — 대역으로 즉시 끝내고
          // 화면이 로컬 근사로 폴백하게 한다
          leaveRepositoryProvider.overrideWithValue(
            _NoAvailableTimeRepository(),
          ),
        ],
        child: const MaterialApp(home: LeaveDatePickerScreen()),
      ),
    );
    await tester.pump();

    // 여행이 아니라 연차 쓴 날이라 '가는날/오는날' 라벨은 붙지 않는다
    expect(find.text('가는날'), findsNothing);
    expect(find.text('오는날'), findsNothing);

    // 오늘 이후 아무 날이나 한 번 누르면 하루짜리 범위가 완성된다 —
    // 두 번 눌러야 열리면 하루만 쓰는 사람은 버튼이 잠긴 이유를 알 수 없다
    final today = DateTime.now();
    // 달 끝자락이면 오늘 칸이 첫 화면 아래로 밀린다 — 보이는 데까지 굴려
    // 놓고 누른다. 굴리지 않으면 탭이 허공에 떨어져 아무것도 안 골라진다
    final day = find.text('${today.day}').first;
    await tester.scrollUntilVisible(
      day,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(day);
    await tester.pumpAndSettle();

    final done = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(done.onPressed, isNotNull, reason: '한 번 눌렀으면 열려 있어야 한다');
    expect(find.text('가는날'), findsNothing);
  });

  testWidgets('내역이 없으면 빈 상태 안내가 뜬다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith((ref) async => const <LeaveUsage>[]),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('연차 사용 내역이 없어요'), findsOneWidget);
    expect(find.text('사용한 연차를 등록해보세요'), findsOneWidget);
  });

  testWidgets('삭제 모드: 고른 것이 있어야 삭제할 수 있다', (tester) async {
    final deletedIds = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith((ref) async => _sampleUsages),
          leaveRepositoryProvider.overrideWithValue(
            _RecordingLeaveRepository(deletedIds),
          ),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('더 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사용 내역 삭제'));
    await tester.pumpAndSettle();

    // 아무것도 안 골랐으면 삭제가 잠겨 있다
    final delete = find.widgetWithText(FilledButton, '삭제하기');
    expect(tester.widget<FilledButton>(delete).onPressed, isNull);

    await tester.tap(find.text('개인 사유').first);
    await tester.pump();
    expect(tester.widget<FilledButton>(delete).onPressed, isNotNull);

    // 확인 모달을 거쳐야 지워진다
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('사용 내역을 삭제할까요?'), findsOneWidget);
    expect(find.text('삭제하면 차감된 연차가 복구돼요.'), findsOneWidget);

    // 하단 CTA도 같은 글자라 모달 안의 것으로 좁힌다
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('삭제하기')),
    );
    await tester.pump();
    await tester.pump();

    // 상쇄 등록이 아니라 그 내역 id로 삭제가 나간다 (core#268)
    expect(deletedIds, [1]);
    // 삭제 모드는 빠져나온다
    expect(find.widgetWithText(FilledButton, '삭제하기'), findsNothing);
  });

  testWidgets('삭제 모드: 코스 건은 내역 삭제 대신 코스의 차감 취소가 나간다', (tester) async {
    // 내역 삭제 API는 코스 확정 건을 409로 막는다. 사용자에게 "코스에서
    // 취소해 달라"고 떠넘기는 대신, 앱이 그 코스의 차감 취소를 불러 같은
    // 결과(내역 삭제·연차 복구)를 내고 코스는 '미방문'으로 돌아간다
    final deletedIds = <int>[];
    final cancelledCourseIds = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith((ref) async => _sampleUsages),
          leaveRepositoryProvider.overrideWithValue(
            _RecordingLeaveRepository(deletedIds),
          ),
          courseRepositoryProvider.overrideWithValue(
            _RecordingCourseRepository(cancelledCourseIds),
          ),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('더 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사용 내역 삭제'));
    await tester.pumpAndSettle();

    // 코스 건(정선 여행, courseId 7)을 고른다
    await tester.tap(find.text('정선 여행'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '삭제하기'));
    await tester.pumpAndSettle();

    // 연차만 돌아오는 게 아니라 코스 상태도 바뀐다는 걸 모달이 미리 말한다
    expect(find.text('삭제하면 차감된 연차가 복구되고, 연결된 코스는 미방문으로 바뀌어요.'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('삭제하기')),
    );
    await tester.pump();
    await tester.pump();

    // 내역 삭제(409로 막힐 경로)가 아니라 코스 차감 취소로 간다
    expect(deletedIds, isEmpty);
    expect(cancelledCourseIds, [7]);
  });
}

/// 코스 차감 취소 요청만 기록하는 대역
class _RecordingCourseRepository implements CourseRepository {
  _RecordingCourseRepository(this.cancelledCourseIds);

  final List<int> cancelledCourseIds;

  @override
  Future<void> cancelLeaveDeduction(int courseId) async {
    cancelledCourseIds.add(courseId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 차감 일수 계산은 실패로 친다 — 화면이 로컬 근사로 폴백해 바로 확정할 수 있다
class _NoAvailableTimeRepository implements LeaveRepository {
  @override
  Future<AvailableTime> availableTime({
    required String transport,
    DateTime? startDate,
    DateTime? endDate,
    String? periodStyle,
    DateTime? baseDate,
    String? weekendBridge,
    int? leaveDays,
  }) async => throw const ApiException(status: 500, code: 'X', detail: '');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
