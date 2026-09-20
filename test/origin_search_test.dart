import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course_wizard/data/origin_search_repository.dart';

/// 출발지 자동완성이 **무엇을 묻고 무엇을 읽는지** 고정한다 (core #591).
///
/// 이 화면은 GPS 를 걷어낸 자리를 메운다. 앱이 좌표를 갖지 않고 코드만
/// 들고 다니므로, 코드를 잘못 읽으면 서버가 엉뚱한 곳에서 시간을 잰다.
void main() {
  late List<RequestOptions> requests;

  OriginSearchRepository repository(Object? body, {int status = 200}) {
    requests = [];
    final dio = Dio()
      ..httpClientAdapter = _StubAdapter(
        onSend: requests.add,
        body: body,
        status: status,
      );
    return OriginSearchRepository(dio);
  }

  const hubs = [
    {
      'code': 'TRAIN:NAT610226',
      'name': '정선역',
      'area': '강원',
      'kind': 'TRAIN_STATION',
    },
    {
      'code': 'BUS:NAEK222',
      'name': '정선터미널',
      'area': '강원',
      'kind': 'BUS_TERMINAL',
    },
  ];

  test('검색어를 실어 부르고 목록을 읽는다', () async {
    final result = await repository(hubs).search('정선');

    expect(requests.single.path, '/api/v1/origins');
    expect(requests.single.queryParameters, {'query': '정선'});
    expect(result.map((h) => h.code), ['TRAIN:NAT610226', 'BUS:NAEK222']);
    expect(result.first.name, '정선역');
    expect(result.first.area, '강원');
  });

  test('앞뒤 공백은 걷어내고 보낸다', () async {
    await repository(hubs).search('  정선  ');

    expect(requests.single.queryParameters, {'query': '정선'});
  });

  test('두 글자 미만이면 부르지 않는다', () async {
    // 서버가 외부 검색을 안 부르는 구간이다 — 빈 목록이 올 왕복을 아낀다
    final repo = repository(hubs);

    expect(await repo.search('정'), isEmpty);
    expect(await repo.search(' '), isEmpty);
    expect(requests, isEmpty);
  });

  test('취소는 오류가 아니라 빈 목록이다', () async {
    // 글자마다 앞선 요청을 끊는다 — 그때마다 화면이 오류를 띄우면 안 된다
    final token = CancelToken();
    final repo = repository(hubs);
    final pending = repo.search('정선', cancelToken: token);
    token.cancel();

    expect(await pending, isEmpty);
  });

  test('주소·장소는 area 가 비어 와도 읽는다', () async {
    // 카카오가 채우는 자리라 허브와 모양이 다르다
    final result = await repository([
      {'code': 'GEO:37.42,127.1265', 'name': '서초구 남부순환로 2567'},
    ]).search('남부순환로');

    expect(result.single.code, 'GEO:37.42,127.1265');
    expect(result.single.area, '');
    expect(result.single.kind, '');
  });

  test('서버가 실패하면 오류를 올린다', () async {
    // 조용히 빈 목록을 주면 '검색 결과 없음' 과 구별되지 않는다
    expect(
      () => repository(null, status: 500).search('정선'),
      throwsA(isA<Exception>()),
    );
  });
}

/// 공통 래퍼(`{status, data, ...}`)로 감싸 돌려준다
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({
    required this.onSend,
    required this.body,
    required this.status,
  });

  final void Function(RequestOptions) onSend;
  final Object? body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onSend(options);
    return ResponseBody.fromString(
      jsonEncode({
        'status': status,
        'data': body,
        'detail': '',
        'code': status == 200 ? 'OK' : 'ERROR',
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
