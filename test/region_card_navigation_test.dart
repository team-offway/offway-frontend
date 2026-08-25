import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/features/region/presentation/widgets/region_card.dart';

/// 홈 장소 카드를 누르면 장소 상세 상단바에 어떤 지역명이 가는가.
void main() {
  testWidgets('장소 카드는 상세에 "시군구 · 시도"를 넘긴다 — 시군구만 주면 어느 동구인지 모른다', (
    tester,
  ) async {
    const place = {
      'id': '126508',
      'placeName': '삼탄아트마인',
      'name': '동구',
      'sido': '부산광역시',
    };
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: RegionCard(region: place)),
        ),
        GoRoute(
          path: AppRoutes.poiDetail,
          // 상세 대신 넘어온 지역명만 그린다 — 여기서 보려는 건 라우트 파라미터다
          builder: (_, state) => Scaffold(
            body: Text('region=${state.uri.queryParameters['region']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.tap(find.text('삼탄아트마인'));
    await tester.pumpAndSettle();

    expect(find.text('region=동구 · 부산광역시'), findsOneWidget);
  });
}
