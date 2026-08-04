import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final originLocatorProvider = Provider<OriginLocator>((ref) => OriginLocator());

/// 추천의 기준이 되는 출발 좌표.
class Origin {
  const Origin({
    required this.lat,
    required this.lng,
    required this.isFallback,
  });

  final double lat;
  final double lng;

  /// 위치를 못 받아 서울 기준으로 가정했는지 — 화면이 그 사실을 알릴 수 있게 남긴다
  final bool isFallback;
}

/// 현재 위치를 얻는다. 못 얻으면 추천을 막는 대신 서울에서 출발한다고 가정한다.
///
/// 권한 요청은 앱 시작이 아니라 여기(추천 직전)서 일어난다 — "여행지를 찾는 중"
/// 이라는 맥락이 있어야 사용자가 왜 위치를 묻는지 납득한다.
class OriginLocator {
  /// 서울시청 — 위치 거부·실패 시의 출발 가정
  static const _seoulFallback = Origin(
    lat: 37.5665,
    lng: 126.9780,
    isFallback: true,
  );

  /// 위치를 이 시간 안에 못 잡으면 포기한다. 추천 로딩을 하염없이 붙잡지 않는다
  static const _fixTimeout = Duration(seconds: 5);

  Future<Origin> resolve() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _seoulFallback;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _seoulFallback;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // 지역 단위 추천이라 동네 수준 정밀도면 충분하다 — 배터리·응답속도 우선
          accuracy: LocationAccuracy.low,
          timeLimit: _fixTimeout,
        ),
      );
      return Origin(
        lat: position.latitude,
        lng: position.longitude,
        isFallback: false,
      );
    } on Exception {
      // 타임아웃·기내모드 등 — 이유가 무엇이든 추천 자체는 계속돼야 한다
      return _seoulFallback;
    }
  }
}
