import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 코스의 장소들을 마커로 찍어 보여주는 지도.
/// 코스 추천 결과·저장한 코스 화면이 공유한다.
class CourseMap extends StatelessWidget {
  const CourseMap({super.key, required this.places, required this.dayKey});

  final List<Map<String, dynamic>> places;

  /// Day가 바뀌면 지도를 다시 만들도록 하는 키 (마커 갱신용)
  final int dayKey;

  /// 위젯 테스트에서는 플랫폼 뷰(지도)를 렌더링할 수 없어 플레이스홀더로 대체
  static final bool _isTest = Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final p in places)
        if (p['mapy'] != null && p['mapx'] != null)
          NLatLng(p['mapy'] as double, p['mapx'] as double),
    ];
    if (_isTest || points.isEmpty) {
      return Container(
        color: const Color(0x806F767E),
        alignment: Alignment.center,
        child: const Text('지도', style: TextStyle(color: Colors.white)),
      );
    }
    final center = NLatLng(
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
    );
    return NaverMap(
      key: ValueKey('map-day-$dayKey'),
      // 리스트 스크롤보다 지도 제스처(이동/확대)가 우선하도록 설정
      forceGesture: true,
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(target: center, zoom: 10.5),
      ),
      onMapReady: (controller) {
        var n = 0;
        for (var i = 0; i < places.length; i++) {
          final p = places[i];
          if (p['mapy'] == null || p['mapx'] == null) continue;
          final marker = NMarker(
            id: 'place-$i',
            position: NLatLng(p['mapy'] as double, p['mapx'] as double),
            caption: NOverlayCaption(text: '${i + 1}. ${p['name']}'),
          );
          controller.addOverlay(marker);
          n++;
        }
        if (n >= 2) {
          controller.updateCamera(
            NCameraUpdate.fitBounds(
              NLatLngBounds.from(points),
              padding: const EdgeInsets.all(40),
            ),
          );
        }
      },
    );
  }
}
