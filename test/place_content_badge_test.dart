import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/course/presentation/widgets/place_content_badge.dart';
import 'package:offway/features/course/presentation/widgets/place_info_sheet.dart';

/// 장소 모달의 성격 뱃지 — '반려동물 동반' · '주말에 붐빔'
/// (시안 18991:86950, DS Content Badge).
///
/// **서버가 아직 안 주는 값이다.** 필드가 비면 줄째 사라져 모달이 예전과
/// 똑같이 보이고, 서버가 채우면 앱을 고치지 않아도 뜬다.
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

  Map<String, dynamic> place({bool pet = false, String? crowd}) => {
    'name': '삼탄아트마인',
    'poiContentId': '1',
    'catchphrase': '폐광촌 예술 체험 공간',
    if (pet) 'petFriendly': true,
    'crowdNote': ?crowd,
  };

  testWidgets('서버가 안 주면 뱃지 줄이 아예 없다', (tester) async {
    await pump(tester, place());

    expect(find.byType(PlaceContentBadge), findsNothing);
    // 모달은 예전과 똑같이 보인다
    expect(find.text('운영시간'), findsOneWidget);
  });

  testWidgets('반려동물 동반이면 뱃지가 붙는다', (tester) async {
    await pump(tester, place(pet: true));

    expect(find.text('반려동물 동반'), findsOneWidget);
    expect(find.byType(PlaceContentBadge), findsNWidgets(1));
  });

  testWidgets('혼잡도는 서버 문구를 그대로 쓴다', (tester) async {
    // 앱이 말을 지어내지 않는다 — 기준이 바뀌면 서버가 문구를 바꾼다
    await pump(tester, place(crowd: '주말에 붐빔'));

    expect(find.text('주말에 붐빔'), findsOneWidget);
  });

  testWidgets('둘 다 있으면 나란히 선다', (tester) async {
    await pump(tester, place(pet: true, crowd: '주말에 붐빔'));

    final badges = find.byType(PlaceContentBadge);
    expect(badges, findsNWidgets(2));

    final first = tester.getRect(badges.at(0));
    final second = tester.getRect(badges.at(1));
    expect(first.top, second.top, reason: '같은 줄');
    expect(second.left - first.right, closeTo(8, 0.1), reason: '시안 뱃지 사이 8');
  });

  testWidgets('시안 치수 — 패딩 8·5, 반경 8, 글자 13', (tester) async {
    await pump(tester, place(pet: true));

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
