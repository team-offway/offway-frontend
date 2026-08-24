import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(dioProvider)),
);

/// 홈 API(`GET /api/v1/home`) 한 번으로 받는 화면 데이터.
class HomeSnapshot {
  const HomeSnapshot({
    required this.user,
    required this.regions,
    this.places = const [],
    this.filters = const [],
  });

  /// `{nickname, remainingLeaveDays(double?)}`
  final Map<String, dynamic> user;

  /// **'이번 연차엔 여기 어때요?'** 섹션 — 지역 카드.
  /// RegionCard가 읽는 형태 (name·sido·benefitBadge·categoryCounts…)
  final List<Map<String, dynamic>> regions;

  /// **'이번달 추천 여행지'** 섹션 — 장소 카드 (core #305).
  ///
  /// 예전에는 이 자리에도 [regions]를 썼다. 시안의 제목은 장소명인데 지역만
  /// 있어 오버레이와 제목에 같은 이름이 두 번 보였고, 칩을 눌러도 지역은
  /// 네 갈래를 다 가져 목록이 그대로였다.
  ///
  /// 부제를 만들 재료가 없는 장소가 있어 `subtitle`은 빈 채로 온다 —
  /// 지어내지 않고 그 줄을 접는 것이 서버와의 약속이다.
  final List<Map<String, dynamic>> places;

  /// 카테고리 칩 `[{key, label}]` — 구성·순서를 서버가 정한다
  final List<Map<String, dynamic>> filters;
}

/// 홈 API. 사용자 식별은 인터셉터가 싣는 JWT가 맡는다.
class HomeRepository {
  HomeRepository(this._dio);

  final Dio _dio;

  Future<HomeSnapshot> fetch() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/home');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final regions = (data['recommendedRegions'] as List)
          .cast<Map<String, dynamic>>();
      final filters = ((data['filters'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      return HomeSnapshot(
        user: {
          'nickname': user['name'],
          'remainingLeaveDays': user['remainingLeaveDays'],
          // 소셜 프로필 사진은 홈이 아니라 /users/me가 정본이다(core #316) —
          // currentUserProvider가 그 값으로 덮는다. 홈에 실려 오면 받아 둘 뿐이다
          'profileImageUrl': ?user['profileImageUrl'],
        },
        regions: regions.map(_toRegionCardMap).toList(),
        places: interleaveByRegion(
          ((data['recommendedPlaces'] as List?) ?? const [])
              .cast<Map<String, dynamic>>()
              .map((p) => toPlaceCardMap(p, filters: filters, regions: regions))
              .toList(),
        ),
        filters: filters,
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  Map<String, dynamic> _toRegionCardMap(Map<String, dynamic> card) =>
      toRegionCardMap(card);
}

/// 서버 장소 카드 → 화면(RegionCard)이 읽는 형태 (core #305).
///
/// 지역 카드와 같은 위젯을 쓰므로 키를 맞춰 넣는다. 다른 점은 셋이다 —
/// 제목이 장소명이고, 오버레이에 지역명이 오고, 한 줄 소개가 붙는다.
///
/// 칩 필터가 한글 라벨로 거르는데 장소는 `kind`(SIGHT…)를 주므로
/// [filters]에서 짝을 찾아 [RegionCard]가 읽는 `categoryCounts`로 편다.
/// 서버가 라벨을 정하므로 앱에 한글을 박아두지 않는다.
Map<String, dynamic> toPlaceCardMap(
  Map<String, dynamic> card, {
  List<Map<String, dynamic>> filters = const [],
  List<Map<String, dynamic>> regions = const [],
}) {
  final benefit = card['benefit'] as Map<String, dynamic>?;
  final kind = card['kind'] as String?;
  final label = filters
      .where((f) => f['key'] == kind)
      .map((f) => f['label'] as String?)
      .firstOrNull;
  // 장소의 regionName은 시군구("동구")만이다. 오버레이는 지역 카드처럼
  // "동구 · 부산광역시"여야 하므로, 같은 응답의 지역 목록(name이 이미 그
  // 형태다)에서 짝을 찾아 시도를 붙인다.
  //
  // 짝은 regionId로 찾는다(core #318) — 서버가 "장소의 regionId는 같은
  // 응답의 지역 중 하나와 반드시 일치한다"를 계약으로 잠갔다. 예전의 이름
  // 대조는 동구·남구처럼 여러 광역시에 있는 이름을 가리지 못해 시도를
  // 비우곤 했다. 짝이 없으면(옛 서버 등) 비워 시군구만 그린다
  final regionName = card['regionName'] as String?;
  final regionId = card['regionId'] as num?;
  final sido = regions
      .where((r) => regionId != null && r['regionId'] == regionId)
      .map((r) => (r['name'] as String? ?? '').split(' · '))
      .where((parts) => parts.length > 1)
      .map((parts) => parts[1])
      .firstOrNull;
  return {
    'id': card['poiContentId']?.toString() ?? '',
    'placeName': card['name'],
    // 같은 지역끼리 묶어 섞을 때 쓴다 — 시군구명은 광역시끼리 겹친다
    if (regionId != null) 'regionId': regionId.toString(),
    'name': regionName,
    // 짝을 못 찾으면 비워 둔다 — 오버레이가 가운뎃점 없이 시군구만 그린다
    'sido': sido ?? '',
    'imageUrl': card['imageUrl'],
    if ((card['subtitle'] as String?)?.isNotEmpty ?? false)
      'description': card['subtitle'],
    if (benefit != null) 'benefitBadge': benefit['text'],
    if (benefit != null) 'benefitPolicyId': benefit['policyId'],
    if (label != null) 'categoryCounts': {label: 1},
  };
}

/// 같은 지역이 연달아 나오지 않게 지역별로 번갈아 섞는다.
///
/// 서버는 지역 단위로 뽑아 지역별로 뭉쳐 준다(정선 8장 → 영월 8장 → …).
/// 홈 가로 목록에서 그대로 보이면 첫 화면이 한 지역으로만 찬다. 지역별
/// 순서는 그대로 두고 한 장씩 돌아가며 뽑는다 — 무작위로 섞으면 다시 읽을
/// 때마다 카드가 자리를 바꿔 튄다. 지역을 모르는 카드는 이름으로 묶는다.
List<Map<String, dynamic>> interleaveByRegion(
  List<Map<String, dynamic>> cards,
) {
  final groups = <Object, List<Map<String, dynamic>>>{};
  for (final card in cards) {
    final key = card['regionId'] ?? card['name'] ?? '';
    groups.putIfAbsent(key, () => []).add(card);
  }
  final queues = groups.values.toList();
  final mixed = <Map<String, dynamic>>[];
  for (var round = 0; mixed.length < cards.length; round++) {
    for (final queue in queues) {
      if (round < queue.length) mixed.add(queue[round]);
    }
  }
  return mixed;
}

/// 서버 카드 → 화면(RegionCard)이 읽는 형태.
///
/// 서버는 지역명을 "동구 · 부산광역시"로 합쳐 주므로 화면이 다시 조립하지
/// 않도록 쪼개 넣는다. 카테고리는 화면 필터가 한글 라벨('체험' 등)로
/// 거르므로 라벨을 키로 편다.
///
/// 홈(`/home`)과 지역 목록(`/regions`)이 **같은 재료**를 주므로 함께 쓴다 —
/// 같은 화면의 더보기라 카드 모양이 달라질 이유가 없다.
Map<String, dynamic> toRegionCardMap(Map<String, dynamic> card) {
  final nameParts = (card['name'] as String).split(' · ');
  final benefit = card['benefit'] as Map<String, dynamic>?;
  final categories = (card['categories'] as List).cast<Map<String, dynamic>>();
  return {
    'id': (card['regionId'] as num).toString(),
    'name': nameParts.first,
    'sido': nameParts.length > 1 ? nameParts[1] : '',
    'imageUrl': card['imageUrl'],
    if (benefit != null) 'benefitBadge': benefit['text'],
    if (benefit != null) 'benefitPolicyId': benefit['policyId'],
    'categoryCounts': {for (final c in categories) c['label'] as String: 1},
  };
}
