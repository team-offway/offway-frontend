import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/location/origin_locator.dart';
import 'package:offway/features/course/data/course_repository.dart';

/// 코스를 담을 때 **출발지를 함께 보내는지** 고정한다.
///
/// 서버는 도착 정보(무엇을 타고 어디에 내리는가)를 저장하지 않는다 —
/// 시간표가 바뀌므로 생성 시점의 값을 보관하면 한 달 뒤 여행에서 낡은 시간을
/// 보여주게 되기 때문이다. 대신 **출발지를 두고 상세를 열 때마다 계산**한다
/// (core `CourseStorageService.trainAccessFor`).
///
/// 그래서 저장에 출발지가 빠지면 담은 코스의 교통 안내가 통째로 빈다.
void main() {
  late List<Map<String, dynamic>> sent;
  late CourseRepository repository;

  setUp(() {
    sent = [];
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = _RecordingAdapter(sent);
    repository = CourseRepository(dio);
  });

  test('생성한 코스를 담을 때 출발지가 실린다', () async {
    final generated = await repository.generate(
      regionId: '1',
      travelDays: 2,
      density: 'RELAXED',
      transport: 'TRANSIT',
      origin: const Origin(lat: 37.5665, lng: 126.9780, isFallback: false),
      travelDate: DateTime(2026, 9, 10),
    );

    final payload = generated['_save'] as Map<String, dynamic>;
    expect(payload['originLat'], 37.5665);
    expect(payload['originLng'], 126.9780);
  });

  test('출발지는 짝으로 간다', () async {
    // 한쪽만 보내면 서버가 400으로 되돌린다(CourseSaveRequest 검증)
    final generated = await repository.generate(
      regionId: '1',
      travelDays: 1,
      density: 'PACKED',
      transport: 'CAR',
      origin: const Origin(lat: 35.1796, lng: 129.0756, isFallback: false),
      travelDate: DateTime(2026, 9, 10),
    );

    final payload = generated['_save'] as Map<String, dynamic>;
    expect(payload.containsKey('originLat'), isTrue);
    expect(payload.containsKey('originLng'), isTrue);
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
