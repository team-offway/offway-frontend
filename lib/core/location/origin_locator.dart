import 'package:flutter/foundation.dart';
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
  OriginLocator({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// 캐시가 언제 상했는지 재는 시계 — 테스트가 갈아 끼운다
  final DateTime Function() _now;

  /// 서울시청 — 위치 거부·실패 시의 출발 가정
  static const _seoulFallback = Origin(
    lat: 37.5665,
    lng: 126.9780,
    isFallback: true,
  );

  /// 위치를 이 시간 안에 못 잡으면 포기한다. 추천 로딩을 하염없이 붙잡지 않는다
  static const _fixTimeout = Duration(seconds: 5);

  /// 잡아 둔 좌표를 이만큼 다시 쓴다.
  ///
  /// 한 번의 위저드 주행에서 최소 두 번(후보 지역 진입·코스 생성) 부르고,
  /// '새로운 추천 받기' 마다 또 부른다. 그때마다 권한 확인과 측위를 새로 돌아
  /// 사용자를 몇 초씩 기다리게 했다(#317).
  ///
  /// **지역 단위 추천이라 몇 분 지난 좌표로도 결과가 같다** — 정밀도도
  /// `low` 로 잡는다. 5분이면 한 주행을 덮으면서, 실제로 멀리 이동한 뒤
  /// 다시 추천받을 때는 새로 잡는다
  static const cacheTtl = Duration(minutes: 5);

  Origin? _cached;
  DateTime? _cachedAt;

  /// 잡아 둔 좌표가 아직 쓸 만한가
  Origin? get _fresh {
    final at = _cachedAt;
    final origin = _cached;
    if (at == null || origin == null) return null;
    return _now().difference(at) < cacheTtl ? origin : null;
  }

  /// 기준 좌표를 준다. 최근에 잡아 둔 것이 있으면 그것을 그대로 쓴다.
  ///
  /// **실제로 잡은 좌표만 보관한다.** 폴백을 보관하면 권한을 방금 켰거나
  /// 신호가 잠깐 끊겼던 사용자가 [cacheTtl] 동안 서울에서 출발하게 된다 —
  /// 폴백은 빠르게 끝나는 길이라 다시 시도해도 기다림이 없다
  Future<Origin> resolve() async {
    if (_fresh case final cached?) return cached;
    final origin = await locate();
    if (!origin.isFallback) {
      _cached = origin;
      _cachedAt = _now();
    }
    return origin;
  }

  /// 실제 측위 — 권한을 확인하고 좌표를 잡는다. 못 잡으면 서울 가정.
  ///
  /// 캐시 정책과 떼어 둔다. 테스트가 이 자리를 갈아 끼워 **측위가 몇 번
  /// 일어났는지** 셀 수 있게 하려는 것이기도 하다
  @visibleForTesting
  Future<Origin> locate() async {
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
      // 국내 전용 서비스라 한국 밖 좌표(해외 사용자·시뮬레이터 기본 위치)로는
      // 도달 가능한 지역이 0곳이 된다 — 서울 출발로 가정한다
      if (!_inKorea(position.latitude, position.longitude)) {
        return _seoulFallback;
      }
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

  /// 한반도 남부(제주~접경지) 대략의 경계 상자
  static bool _inKorea(double lat, double lng) =>
      lat >= 33.0 && lat <= 38.7 && lng >= 124.5 && lng <= 132.0;
}
