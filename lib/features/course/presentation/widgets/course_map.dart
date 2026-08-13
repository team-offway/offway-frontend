import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 코스의 장소들을 마커로 찍고 순서대로 이어 보여주는 지도.
/// 코스 추천 결과·저장한 코스·공유받은 코스 화면이 함께 쓴다.
/// 경로 점선 색 — Atomic/Cool Neutral/60
const _pathColor = Color(0xFF878A93);

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
      // Day 전환뿐 아니라 재추첨으로 장소가 통째로 바뀌어도 지도를 새로 만든다
      // — 마커는 onMapReady에서만 찍히므로 내용이 바뀌면 키도 바뀌어야 한다
      key: ValueKey(
        Object.hashAll([
          dayKey,
          for (final p in places) '${p['name']}@${p['mapx']},${p['mapy']}',
        ]),
      ),
      // 리스트 스크롤보다 지도 제스처(이동/확대)가 우선하도록 설정
      forceGesture: true,
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(target: center, zoom: 10.5),
      ),
      onMapReady: (controller) {
        for (var i = 0; i < places.length; i++) {
          final p = places[i];
          if (p['mapy'] == null || p['mapx'] == null) continue;
          final marker = NMarker(
            id: 'place-$i',
            position: NLatLng(p['mapy'] as double, p['mapx'] as double),
            caption: NOverlayCaption(text: '${i + 1}. ${p['name']}'),
          );
          controller.addOverlay(marker);
        }
        // 1→2→3 순서를 잇는 점선. 실제 도로가 아니라 도는 순서를 보이는 선이다
        if (points.length >= 2) {
          controller.addOverlay(
            NPolylineOverlay(
              id: 'course-path',
              coords: points,
              color: _pathColor,
              width: 4,
              // 웹의 shortdot과 같은 밀도 — 점이 촘촘히 이어져 경로로 읽힌다
              pattern: const [2, 6],
              lineCap: NLineCap.round,
            ),
          );
        }
        // 코스는 1번에서 시작한다 — 첫 장소를 가운데 두고 시작한다.
        // 전체를 담는 fitBounds 대신 1번 기준이라 사용자가 순서를 먼저 본다
        controller.updateCamera(NCameraUpdate.withParams(target: points.first));
      },
    );
  }
}
