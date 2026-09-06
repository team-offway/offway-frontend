import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/info_card.dart';
import '../../domain/golden_holiday.dart';

/// 홈 '연차 쓰기 전, 확인해보세요'의 첫 카드 — '2027 황금연휴 알아보기'.
///
/// 서버 링크 카드([CuratedLinkCard])와 같은 틀([InfoCard])이지만 밖으로
/// 나가지 않고 앱 안 화면(황금연휴)으로 간다. 그래서 버튼이 '웹사이트'가
/// 아니라 '자세히'와 쉐브론이다.
class GoldenHolidayCard extends StatelessWidget {
  const GoldenHolidayCard({super.key});

  static const title = '$kGoldenHolidayYear 황금연휴 알아보기';

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      // 시안의 샌드위치 일러스트(18900:72041) — 벡터 30장이라 한 장 PNG(3배)로
      // 받았다. 아랫단이 카드색으로 녹는 것(Gradient/Solid)까지 그림에 들어
      // 있어 카드의 페이드는 끈다
      fadeImageBottom: false,
      image: Image.asset(
        'assets/images/golden_holiday_card.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
      description: '샌드위치 연휴부터 연차 쓰기 좋은 날까지 미리 확인해보세요.',
      title: title,
      buttonLabel: '자세히',
      buttonIconAsset: 'assets/icons/ic_chevron_right.svg',
      semanticsLabel: '$title 보기',
      onTap: () => context.push(AppRoutes.goldenHolidays),
    );
  }
}
