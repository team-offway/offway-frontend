import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱의 모든 원격 이미지가 함께 쓰는 디스크 캐시.
///
/// `DefaultCacheManager`를 그냥 쓰면 **200개**가 넘는 순간부터 오래된 것을
/// 지운다 — 홈 카드만 50장이고 지역 상세·코스까지 합치면 금방 넘어,
/// 캐시를 두고도 다시 받는 일이 생긴다. TourAPI 사진은 거의 바뀌지 않으니
/// 넉넉히 들고 30일 안 쓰면 비운다.
///
/// 위젯(`CachedNetworkImage`)과 프리캐시용 provider(`CachedNetworkImageProvider`)
/// 양쪽에 **같은 인스턴스**를 넘겨야 한 벌의 캐시를 나눠 쓴다 — 키가 다르면
/// 목록에서 받은 사진을 공유 이미지가 또 받는다.
final CacheManager appImageCacheManager = CacheManager(
  Config(
    'offway_images',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 1000,
  ),
);

/// 사진 한 장을 [appImageCacheManager] 디스크 캐시에 미리 받는다. 끝나면(실패해도)
/// 완료된다 — 미리 받기는 덤이라 실패는 삼키고, 카드가 그릴 때 다시 받는다.
///
/// 같은 캐시·같은 주소는 한 번만 받는다 — 받는 중에 카드가 같은 사진을 요청하면
/// 그 받기를 이어받는다. 테스트는 이 provider 를 바꿔 끼워 네트워크를 막는다
final imagePrefetcherProvider = Provider<Future<void> Function(String url)>(
  (ref) =>
      (url) =>
          appImageCacheManager.downloadFile(url).then((_) {}, onError: (_) {}),
);
