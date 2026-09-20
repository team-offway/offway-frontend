import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course/data/course_repository.dart';

/// 코스를 담을 때 **출발지를 함께 보내는지** 고정한다.
///
/// 서버는 도착 정보(무엇을 타고 어디에 내리는가)를 저장하지 않는다 —
/// 시간표가 바뀌므로 생성 시점의 값을 보관하면 한 달 뒤 여행에서 낡은 시간을
/// 보여주게 되기 때문이다. 대신 **출발지를 두고 상세를 열 때마다 계산**한다
/// (core `CourseStorageService.trainAccessFor`).
///
/// 그래서 저장에 출발지가 빠지면 담은 코스의 교통 안내가 통째로 빈다.
///
/// 출발지는 이제 **좌표가 아니라 허브 코드**다(core #591) — `TRAIN:…`·`BUS:…`.
/// 앱이 GPS 를 쓰지 않으므로 고른 값이 없으면 아무것도 싣지 않고,
/// 그때는 서버가 기본 출발지(서울역)를 쓴다.
void main() {
  late List<Map<String, dynamic>> sent;
  late CourseRepository repository;

  setUp(() {
    sent = [];
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = _RecordingAdapter(sent);
    repository = CourseRepository(dio);
  });

  test('고른 출발지가 있으면 담을 때 함께 실린다', () async {
    final generated = await repository.generate(
      regionId: '1',
      travelDays: 2,
      density: 'RELAXED',
      transport: 'TRANSIT',
      originCode: 'TRAIN:NAT610226',
      travelDate: DateTime(2026, 9, 10),
    );

    final payload = generated['_save'] as Map<String, dynamic>;
    expect(payload['originCode'], 'TRAIN:NAT610226');
  });

  test('고른 출발지가 없으면 싣지 않는다 — 서버가 기본 출발지를 쓴다', () async {
    // 빈 값을 보내면 서버가 그것을 코드로 풀려다 실패한다.
    // 아예 없으면 `originCode` → 좌표 → 기본값 순서에서 기본값으로 떨어진다
    final generated = await repository.generate(
      regionId: '1',
      travelDays: 1,
      density: 'PACKED',
      transport: 'CAR',
      originCode: null,
      travelDate: DateTime(2026, 9, 10),
    );

    final payload = generated['_save'] as Map<String, dynamic>;
    expect(payload.containsKey('originCode'), isFalse);
  });
}

/// 보낸 요청 본문을 기억하고 최소 응답을 돌려주는 대역
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.bodies);

  final List<Map<String, dynamic>> bodies;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.data is Map) {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    // 코스 생성 응답의 최소 모양 — _toCourseMap이 읽는 키만 채운다
    return ResponseBody.fromString(
      '{"code":"OK","status":200,"data":{"regionId":1,"travelDays":1,'
      '"travelDate":"2026-09-10",'
      '"days":[{"day":1,"date":"2026-09-10","items":[]}]}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
