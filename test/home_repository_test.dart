import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/home/data/home_repository.dart';

/// 2026-08-04 배포 서버(GET /api/v1/home)가 실제로 내려준 응답 그대로.
/// 명세가 아니라 실물 기준으로 어댑터를 고정한다 — 서버가 바뀌면 여기서 걸린다.
const _realHomeBody = {
  'status': 200,
  'data': {
    'user': {'name': '게스트', 'remainingLeaveDays': null},
    'filters': [
      {'key': 'ALL', 'label': '전체'},
      {'key': 'SIGHT', 'label': '관광지'},
    ],
    'recommendedRegions': [
      {
        'regionId': 1,
        'name': '동구 · 부산광역시',
        'crowdLevel': 'HIGH',
        'imageUrl': 'http://tong.visitkorea.or.kr/cms/resource/32/2869132.jpg',
        'categories': [
          {'key': 'FOOD', 'label': '맛집'},
          {'key': 'SIGHT', 'label': '관광지'},
          {'key': 'EXPERIENCE', 'label': '체험'},
          {'key': 'STAY', 'label': '숙박'},
        ],
        'benefit': {
          'text': '여행경비 50% 환급',
          'policyType': 'REGIONAL_VOUCHER',
          'policyId': 1,
        },
        'airQuality': null,
      },
      {
        'regionId': 29,
        'name': '공주시 · 충청남도',
        'crowdLevel': 'HIGH',
        'imageUrl': null,
        'categories': [
          {'key': 'FOOD', 'label': '맛집'},
        ],
        'benefit': null,
        'airQuality': null,
      },
    ],
  },
  'detail': '요청이 정상 처리되었습니다.',
  'code': 'OK',
  'pageResponse': null,
};

void main() {
  late HomeRepository repository;

  setUp(() {
    final dio = Dio(BaseOptions())
      ..httpClientAdapter = _FixedResponseAdapter(_realHomeBody);
    repository = HomeRepository(dio);
  });

  test('실서버 응답을 화면이 읽는 형태로 옮긴다', () async {
    final snapshot = await repository.fetch();

    expect(snapshot.user['nickname'], '게스트');
    expect(snapshot.user['remainingLeaveDays'], isNull);

    final region = snapshot.regions.first;
    // 서버가 합쳐 준 이름을 화면 조립 형태(name·sido)로 되쪼갠다
    expect(region['name'], '동구');
    expect(region['sido'], '부산광역시');
    // 라우트가 문자열 id를 쓰므로 숫자를 문자열로 바꾼다
    expect(region['id'], '1');
    expect(region['benefitBadge'], '여행경비 50% 환급');
    expect(region['benefitPolicyId'], 1);
    // 홈 필터가 한글 라벨로 거르므로 라벨을 키로 편다
    expect(region['categoryCounts'], containsPair('체험', 1));
  });

  test('혜택 없는 지역은 뱃지 키 자체를 만들지 않는다', () async {
    final snapshot = await repository.fetch();
    final region = snapshot.regions[1];

    // 카드가 `if (region['benefitBadge'] case ...)` 로 분기하므로
    // null을 넣는 게 아니라 키가 없어야 뱃지 줄이 사라진다
    expect(region.containsKey('benefitBadge'), isFalse);
    expect(region['imageUrl'], isNull);
  });
}

/// 무슨 요청이든 준비된 바디로 답하는 어댑터 — 네트워크 없이 변환만 검증한다
class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
