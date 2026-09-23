import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/region_visit_metrics.dart';
import '../data/region_detail_repository.dart';
import '../../../core/network/api_envelope.dart';

/// 매력 포인트 장소 개수 — 시안 노트: 최소 2 ~ 최대 10
const kMaxHighlightSpots = 10;

final regionDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, regionId) async {
      final data = await ref
          .watch(regionDetailRepositoryProvider)
          .detail(regionId);

      // 서버는 name에 시군구와 시도를 이미 합쳐 준다("동구 · 부산광역시")
      final spots =
          (data['highlightSpots'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];

      return {
        'id': regionId,
        'name': data['name'],
        // 혜택은 서버가 홈·장소 상세와 같은 모양으로 준다(core #418) —
        // 필드를 흩지 않고 통째로 넘긴다
        'benefit': data['benefit'],
        'photos': (data['photos'] as List?)?.cast<String>() ?? const <String>[],
        // 서버가 그 지역에 실제로 있는 것의 이름으로 만든 한 줄 문장이다(core #140).
        // 문단이 아니라 한 줄이라 펼치기 chevron은 쓸 자리가 없다
        if ((data['overview'] as String?)?.isNotEmpty ?? false)
          'story': data['overview'],
        // 공공데이터 출처 (core #417) — 리포지토리가 래퍼에서 꺼내 실어 준다
        '_sources': data['_sources'] ?? const <DataSource>[],
        // 한산한 요일·인기 추세 (core #438). 객체는 늘 오고 안의 두 값이
        // 각각 비어 있을 수 있다 — 재료가 모자라면 서버가 지어내지 않는다
        'visitMetrics': RegionVisitMetrics.parse(data['visitMetrics']),
        // 사진 없는 장소와 상한(10)은 서버가 이미 처리해 준다 — 앱에서 또
        // 자르면 세는 쪽과 그리는 쪽이 갈린다
        'highlightSpots': [
          for (final s in spots.take(kMaxHighlightSpots))
            {
              'name': s['name'],
              'caption': s['catchphrase'] ?? '',
              if (s['imageUrl'] != null) 'imageUrl': s['imageUrl'],
              if (s['poiContentId'] != null) 'poiContentId': s['poiContentId'],
            },
        ],
      };
    });
