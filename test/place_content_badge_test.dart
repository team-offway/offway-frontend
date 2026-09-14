import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/course/presentation/widgets/place_content_badge.dart';
import 'package:offway/features/course/presentation/widgets/place_info_sheet.dart';

/// 장소 모달의 성격 뱃지 — 반려동반 · 혼잡도
/// (시안 18991:86950, DS Content Badge · core #567·#568).
///
/// **둘 다 없으면 키가 아예 안 온다.** 서버가 "모른다"와 "아니다"를 갈라
/// 두었다 — 반려동반이 아닌 곳과 판정할 수 없는 곳이 함께 여기 해당하므로
/// 없다고 '불가'로 적지 않는다.
void main() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic> place) async {
    tester.view.physicalSize = const Size(402 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiScheduleProvider('1').overrideWith(
            (ref) async => (useTime: '09:00 - 18:00', restDate: '매주 월요일'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PlaceInfoSheet(
              place: place,
              isToday: false,
              onOpenDetail: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// [pet]이 null이면 키를 만들지 않는다 — 서버가 그렇게 준다.
  /// [wholeArea]는 전 구역(true) / 일부 구역(false)을 가른다
  Map<String, dynamic> place({bool? wholeArea, String? crowdLabel}) => {
    'name': '삼탄아트마인',
    'poiContentId': '1',
    'catchphrase': '폐광촌 예술 체험 공간',
    if (wholeArea != null)
      'petAccompany': {'wholeArea': wholeArea, 'area': '전구역 동반가능'},
    if (crowdLabel != null)
      'crowd': {
        'level': 'BUSY',
        'basis': 'ATTRACTION_FORECAST',
        'label': crowdLabel,
      },
  };

  testWidgets('서버가 안 주면 뱃지 줄이 아예 없다', (tester) async {
    await pump(tester, place());

    expect(find.byType(PlaceContentBadge), findsNothing);
    // 모달은 예전과 똑같이 보인다
    expect(find.text('운영시간'), findsOneWidget);
  });

  testWidgets('전 구역 동반이면 뱃지가 붙는다', (tester) async {
    await pump(tester, place(wholeArea: true));

    expect(find.text('반려동물 동반'), findsOneWidget);
    expect(find.byType(PlaceContentBadge), findsNWidgets(1));
  });

  testWidgets('일부 구역도 칩 문구는 같다 — 구분은 눌러서 여는 내용의 몫', (tester) async {
    // 서버 실측(태안 15건)에서 절반이 '일부구역 동반가능'이지만, 서버는
    // 그것을 **칩을 눌렀을 때 여는 내용**으로 설계했다(core #567).
    // 칩 문구를 앱이 지어내면 시안에 없는 말이 화면에 뜬다
    await pump(tester, place(wholeArea: false));

    expect(find.text('반려동물 동반'), findsOneWidget);
    // 구분 값은 버리지 않는다 — 상세 시안이 나오면 여기서 꺼내 쓴다
    expect(find.byType(PlaceContentBadge), findsNWidgets(1));
  });

  testWidgets('혼잡도는 서버 문구를 그대로 쓴다', (tester) async {
    // 앱이 말을 지어내지 않는다 — 기준이 바뀌면 서버가 문구를 바꾼다
    await pump(tester, place(crowdLabel: '이날 붐빔'));

    expect(find.text('이날 붐빔'), findsOneWidget);
  });

  testWidgets('둘 다 있으면 나란히 선다', (tester) async {
    await pump(tester, place(wholeArea: true, crowdLabel: '이날 붐빔'));

    final badges = find.byType(PlaceContentBadge);
    expect(badges, findsNWidgets(2));

    final first = tester.getRect(badges.at(0));
    final second = tester.getRect(badges.at(1));
    expect(first.top, second.top, reason: '같은 줄');
    expect(second.left - first.right, closeTo(8, 0.1), reason: '시안 뱃지 사이 8');
  });

  testWidgets('시안 치수 — 패딩 8·5, 반경 8, 글자 13', (tester) async {
    await pump(tester, place(wholeArea: true));

    final badge = tester.getRect(find.byType(PlaceContentBadge));
    final label = tester.getRect(find.text('반려동물 동반'));
    // 모달에는 쉐브론·시계 아이콘도 있다 — 뱃지 안쪽에서 찾는다
    final icon = tester.getRect(
      find.descendant(
        of: find.byType(PlaceContentBadge),
        matching: find.byType(SvgPicture),
      ),
    );

    expect(label.top - badge.top, 5);
    expect(icon.left - badge.left, 8);
    expect(icon.width, 16);
    expect(label.left - icon.right, 4);

    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(PlaceContentBadge),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.fillNormal);
    expect((decoration.borderRadius! as BorderRadius).topLeft.x, 8);
    expect(tester.widget<Text>(find.text('반려동물 동반')).style?.fontSize, 13);
  });
}
