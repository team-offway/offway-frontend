import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/utils/widget_capture.dart';
import 'package:offway/features/course/presentation/widgets/course_share_image.dart';

/// 사진첩에 저장하는 코스 이미지의 뱃지 — 시안(1023:46577)과 화면 규칙을 잠근다.
///
/// QA: 시계가 빠져 있었고, 지난 여행엔 뱃지가 아예 없었다. 화면·공유
/// 웹페이지와 이미지가 서로 다른 말을 하고 있었다.
void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> saved({
    required DateTime start,
    bool leaveDeducted = false,
  }) => {
    'startDate': iso(start),
    'endDate': iso(start.add(const Duration(days: 1))),
    'regionName': '정선군',
    'durationLabel': '1박 2일',
    'leaveDeducted': leaveDeducted,
  };

  final course = <String, dynamic>{
    'days': [
      {
        'day': 1,
        'date': iso(today.add(const Duration(days: 3))),
        'places': <Map<String, dynamic>>[],
      },
    ],
  };

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 1080, child: child)),
    ),
  );

  Finder clock() => find.byWidgetPredicate(
    (w) => w is SvgPicture && w.toString().contains('ic_clock_filled'),
  );

  testWidgets('사용 연차 뱃지에 채운 시계가 33 크기로, 글자와 8 띄워 붙는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(
        CourseShareImage(
          saved: saved(start: today.add(const Duration(days: 3))),
          course: course,
          consumedLeaveDays: 2,
        ),
      ),
    );
    await tester.pump();

    expect(clock(), findsOneWidget);
    final icon = tester.getRect(clock());
    expect(icon.size, const Size(33, 33));
    final text = tester.getRect(find.text('사용 연차 일수 2일'));
    expect(text.left - icon.right, 8, reason: '시안: 시계와 글자 사이 8');
  });

  testWidgets('D-DAY 뱃지에는 시계가 없다', (tester) async {
    // 시안은 사용 연차 뱃지에만 시계를 단다 — D-DAY 뱃지의 Leading Icon 은 숨김
    await tester.binding.setSurfaceSize(const Size(1080, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(
        CourseShareImage(
          saved: saved(start: today.add(const Duration(days: 3))),
          course: course,
          consumedLeaveDays: 2,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('D-3'), findsOneWidget);
    expect(clock(), findsOneWidget, reason: '시계는 연차 뱃지 하나뿐');
  });

  group('지난 여행 — 화면과 같은 규칙', () {
    testWidgets('여행 중 2일차는 D-DAY 다 — 미방문이 아니다', (tester) async {
      // 지난 여행인지는 종료일로 가른다. 출발일로 가르면 2박3일의
      // 둘째 날부터 '미방문'이 찍혔다 (목록 카드는 D-DAY)
      await tester.binding.setSurfaceSize(const Size(1080, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = saved(start: today.subtract(const Duration(days: 1)));
      data['endDate'] = iso(today.add(const Duration(days: 1)));
      await tester.pumpWidget(
        wrap(
          CourseShareImage(saved: data, course: course, consumedLeaveDays: 1),
        ),
      );
      await tester.pump();

      expect(find.text('D-DAY'), findsOneWidget);
      expect(find.text('미방문'), findsNothing);
    });

    testWidgets('다녀왔다고 답한 여행은 여행완료다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        wrap(
          CourseShareImage(
            saved: saved(
              start: today.subtract(const Duration(days: 5)),
              leaveDeducted: true,
            ),
            course: course,
            consumedLeaveDays: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('여행완료'), findsOneWidget);
    });

    testWidgets('답하지 않은 지난 여행은 미방문이다 — 빈칸이 아니다', (tester) async {
      // 전에는 지난 여행에 뱃지가 아예 없었다 — 화면은 '미방문'을 띄운다
      await tester.binding.setSurfaceSize(const Size(1080, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        wrap(
          CourseShareImage(
            saved: saved(start: today.subtract(const Duration(days: 5))),
            course: course,
            consumedLeaveDays: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('미방문'), findsOneWidget);
      expect(find.text('여행완료'), findsNothing);
    });
  });

  testWidgets('시계 에셋을 캡처 전에 캐시에 넣는다', (tester) async {
    // 이 수정의 핵심 위험. SVG 는 첫 그리기에서 비동기로 로드돼, 캡처가 그 전에
    // 돌면 이미지에 그 자리가 빈다. 캡처 함수가 쓰는 프리캐시가 정말 캐시에
    // 넣는지 본다 — putIfAbsent 는 키가 있으면 로더를 부르지 않으므로,
    // 넣은 뒤 '던지는 로더'로 다시 넣어 안 던지면 캐시된 것이다
    await tester.runAsync(() async {
      await precacheSvgAssets(const [CourseShareImage.clockAsset]);

      const loader = SvgAssetLoader(CourseShareImage.clockAsset);
      final bytes = await svg.cache.putIfAbsent(
        loader.cacheKey(null),
        () => throw StateError('캐시에 없어 로더를 불렀다'),
      );
      expect(bytes.lengthInBytes, greaterThan(0));
    });
  });
}
