import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/place_thumbnail.dart';
import 'package:offway/features/course/presentation/widgets/course_place_list.dart';

/// 대중교통 코스의 첫·끝 칸 — 역·터미널 (core #431).
///
/// 장소 풀에서 온 칸이 아니라 **상세가 없다**. 코스의 1번이자 마지막
/// 번호라는 자리는 그대로 쓰되, 없는 것을 있는 척하지 않는다. 사진만은
/// 서버가 지점 이름으로 받아 둔 것이 있으면 실린다(core #466).
void main() {
  Map<String, dynamic> arrival() => {
    'name': '정선역',
    'kind': 'ARRIVAL',
    'category': '도착',
    // poiContentId·imageUrl이 없다 — 서버가 필드째 빼고 내린다
  };

  Map<String, dynamic> sight() => {
    'name': '아우라지',
    'kind': 'SIGHT',
    'category': '관광',
    'poiContentId': '126508',
    'imageUrl': 'https://example.com/a.jpg',
    'travelMinutes': 22,
  };

  Future<void> pump(
    WidgetTester tester,
    List<Map<String, dynamic>> places, {
    void Function(Map<String, dynamic>)? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoursePlaceList(
              places: places,
              regionName: '정선군',
              onTapPlace: onTap,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('도착·출발 칸을 다른 장소와 같은 번호로 그린다', (tester) async {
    // 코스는 역에서 시작해 역에서 끝난다 — 그 두 칸도 코스의 한 자리다
    await pump(tester, [
      arrival(),
      sight(),
      {'name': '정선역', 'kind': 'DEPARTURE', 'category': '출발'},
    ]);

    expect(find.text('정선역'), findsNWidgets(2));
    expect(find.text('도착'), findsOneWidget);
    expect(find.text('출발'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('사진이 없으면 자리를 남기지 않는다', (tester) async {
    // 안 받아 둔 지점은 imageUrl 없이 온다. 빈 회색 자리를 두면 '못 불러온
    // 사진'으로 읽혀, 데이터가 빠진 것처럼 보인다
    await pump(tester, [arrival(), sight()]);

    // 장소 칸 하나만 썸네일을 가진다
    expect(find.byType(PlaceThumbnail), findsOneWidget);
  });

  testWidgets('사진이 오면 다른 칸처럼 그린다 (core #466)', (tester) async {
    // 서버가 관광사진갤러리에서 지점 이름으로 받아 둔 사진을 붙여 보낸다
    await pump(tester, [
      {...arrival(), 'imageUrl': 'https://example.com/station.jpg'},
      sight(),
    ]);

    expect(find.byType(PlaceThumbnail), findsNWidgets(2));
  });

  testWidgets('빈 문자열 사진은 없는 것이다', (tester) async {
    // TourAPI 원문 정리 뒤 ''가 남을 수 있다 — 자리만 차지하는 빈 칸이 된다
    await pump(tester, [
      {...arrival(), 'imageUrl': ''},
      sight(),
    ]);

    expect(find.byType(PlaceThumbnail), findsOneWidget);
  });

  testWidgets('눌러도 아무 일이 없다 — 열 상세가 없다', (tester) async {
    // 누르면 '상세 정보가 아직 없어요'가 뜨는데, 데이터가 빠진 것이 아니라
    // 원래 없는 칸이라 틀린 안내다
    final tapped = <String>[];
    await pump(tester, [
      arrival(),
      sight(),
    ], onTap: (p) => tapped.add(p['name'] as String));

    await tester.tap(find.text('정선역'));
    await tester.pump();
    expect(tapped, isEmpty);

    // 장소 칸은 그대로 눌린다
    await tester.tap(find.text('아우라지'));
    await tester.pump();
    expect(tapped, ['아우라지']);
  });

  testWidgets('자차 코스는 그대로다 — 거점 칸이 없다', (tester) async {
    // 내릴 역이 없어 서버가 안 넣는다
    await pump(tester, [sight()]);

    expect(find.byType(PlaceThumbnail), findsOneWidget);
    expect(find.text('도착'), findsNothing);
  });
}
