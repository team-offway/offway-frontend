import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 코스의 장소들을 마커로 찍고 순서대로 이어 보여주는 지도.
/// 코스 추천 결과·저장한 코스·공유받은 코스 화면이 함께 쓴다.
/// 경로 점선 색 — Atomic/Cool Neutral/60
const _pathColor = Color(0xFF878A93);

/// 지도 마커 — 36은 지도를 덮어 장소가 겹칠 때 서로 가렸다
const _pinSize = 28.0;

/// 처음 보여줄 확대 정도. 10.5는 군 전체가 들어와 마커가 한 덩어리로 뭉쳤다 —
/// 코스는 대개 한 지역 안이라 더 당겨야 순서가 읽힌다
const _initialZoom = 12.0;
const _placeColor = Color(0xFF18D2FE);
const _stayColor = Color(0xFFF553DA);

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
        initialCameraPosition: NCameraPosition(
          target: center,
          zoom: _initialZoom,
        ),
      ),
      onMapReady: (controller) async {
        // 마커가 하나뿐이면 순서가 의미 없다 — 번호 원 대신 네이버 기본
        // 핀을 브랜드색으로 물들여 꽂고, 캡션에서도 숫자를 뺀다(QA).
        // places가 아니라 points로 센다 — 좌표 없는 장소는 마커가 안 되므로,
        // 그걸 세면 하나뿐인 마커에 '2. 장소명'이 붙는 수가 있다
        final single = points.length == 1;
        for (var i = 0; i < places.length; i++) {
          final p = places[i];
          if (p['mapy'] == null || p['mapx'] == null) continue;
          // 시안: 기본 핀 대신 목록과 같은 번호 원. 숙박은 분홍으로 구분한다
          final icon = single || !context.mounted
              ? null
              : await NOverlayImage.fromWidget(
                  widget: _NumberPin(
                    number: i + 1,
                    isStay: p['kind'] == 'STAY',
                  ),
                  size: const Size(_pinSize, _pinSize),
                  context: context,
                );
          final marker = NMarker(
            id: 'place-$i',
            position: NLatLng(p['mapy'] as double, p['mapx'] as double),
            // icon이 null이면 네이버 기본 핀 — 거기에 브랜드색만 입힌다
            icon: icon,
            // 브랜드 하늘색 진한 단계(Primary/Strong · '추천' 글자색과 같다).
            // Normal(#3DC2FF)은 마커용 색과 거의 같아 바꾼 티가 안 났다
            iconTintColor: single
                ? AppColors.primaryStrong
                : Colors.transparent,
            caption: NOverlayCaption(
              text: single ? '${p['name']}' : '${i + 1}. ${p['name']}',
            ),
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
              // 마커를 줄인 만큼 선도 얇게 — 4는 점이 아니라 굵은 띠로 보였다
              width: 3,
              // 웹의 shortdot과 같은 밀도 — 점이 촘촘히 이어져 경로로 읽힌다
              pattern: const [2, 6],
              lineCap: NLineCap.round,
            ),
          );
        }
        // 코스는 1번에서 시작한다 — 첫 장소를 가운데 두고 시작한다.
        // 전체를 담는 fitBounds 대신 1번 기준이라 사용자가 순서를 먼저 본다.
        // 줌도 함께 준다 — 옮기기만 하면 초기값이 유지된다는 보장이 없다
        controller.updateCamera(
          NCameraUpdate.withParams(target: points.first, zoom: _initialZoom),
        );
      },
    );
  }
}

/// 지도 위 번호 마커 — 목록의 번호와 같은 모양이라 눈으로 이어진다
class _NumberPin extends StatelessWidget {
  const _NumberPin({required this.number, required this.isStay});

  final int number;
  final bool isStay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _pinSize,
      height: _pinSize,
      decoration: BoxDecoration(
        color: isStay ? _stayColor : _placeColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          // 시안 비율 48:28
          fontSize: _pinSize * 0.583,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
