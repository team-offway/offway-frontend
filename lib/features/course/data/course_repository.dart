import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/origin_locator.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/tour_text.dart';

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(dioProvider)),
);

/// 코스 API (`/api/v1/courses`). 소유 식별은 인터셉터의 X-Guest-Id가 맡는다.
class CourseRepository {
  CourseRepository(this._dio);

  final Dio _dio;

  /// 지역·조건으로 코스를 생성한다 (`POST /courses/generate`).
  ///
  /// [regionId]는 라우트가 문자열로 나르므로 여기서 숫자로 되돌린다.
  /// [density]·[transport]는 서버 enum 문자열(PACKED·RELAXED / CAR·TRANSIT).
  /// [confirmedDate]는 사용자가 캘린더에서 직접 고른 날짜만 넣는다 — 추정한
  /// 날짜를 저장에 실으면 일정이 '확정'된 것처럼 보이게 된다.
  Future<Map<String, dynamic>> generate({
    required String regionId,
    required int travelDays,
    required String density,
    required String transport,
    required Origin origin,
    required DateTime travelDate,
    DateTime? confirmedDate,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/courses/generate',
        data: {
          'regionId': int.parse(regionId),
          'travelDays': travelDays,
          'density': density,
          'transport': transport,
          'originLat': origin.lat,
          'originLng': origin.lng,
          'travelDate': isoDate(travelDate),
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return _toCourseMap(
        data,
        savePayload: _toSavePayload(
          data,
          density: density,
          transport: transport,
          confirmedDate: confirmedDate,
        ),
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 같은 지역에서 코스를 다시 뽑는다 (`POST /courses/regenerate`).
  ///
  /// [previousSeed]는 직전 재생성이 돌려준 씨앗 — 넘겨야 그 코스와 다른 조합이
  /// 나온다. 첫 재생성은 생략한다(서버가 첫 생성 코스로 간주).
  /// `differentFromPrevious`가 거짓이면 후보가 모자란 지역이다.
  Future<({Map<String, dynamic> course, int seed, bool differentFromPrevious})>
  regenerate({
    required String regionId,
    required int travelDays,
    required String density,
    required String transport,
    required Origin origin,
    required DateTime travelDate,
    DateTime? confirmedDate,
    int? previousSeed,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/courses/regenerate',
        data: {
          'regionId': int.parse(regionId),
          'travelDays': travelDays,
          'density': density,
          'transport': transport,
          'originLat': origin.lat,
          'originLng': origin.lng,
          'travelDate': isoDate(travelDate),
          'previousSeed': ?previousSeed,
        },
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final course = data['course'] as Map<String, dynamic>;
      return (
        course: _toCourseMap(
          course,
          savePayload: _toSavePayload(
            course,
            density: density,
            transport: transport,
            confirmedDate: confirmedDate,
          ),
        ),
        seed: (data['seed'] as num).toInt(),
        differentFromPrevious: data['differentFromPrevious'] as bool? ?? true,
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 담지 않고 공유 링크만 만든다 (`POST /courses/share`).
  ///
  /// 내 코스 목록에는 남지 않고 링크로만 열린다 — 친구에게 보여주려고
  /// 매번 담을 필요가 없다. 요청 형태는 [save]와 같다.
  Future<String> shareWithoutSaving(Map<String, dynamic> savePayload) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/courses/share',
        data: savePayload,
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      final token = data['shareToken'] as String?;
      if (token == null || token.isEmpty) {
        throw StateError('공유 응답에 shareToken이 없습니다: $data');
      }
      return token;
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 생성된 코스를 내 코스로 저장한다 (`POST /courses`).
  Future<({int courseId, String? shareToken})> save(
    Map<String, dynamic> savePayload,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/courses',
        data: savePayload,
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return (
        courseId: (data['courseId'] as num).toInt(),
        shareToken: data['shareToken'] as String?,
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 내 코스 목록 카드 (`GET /courses?scope=`).
  ///
  /// [scope]는 ALL·UPCOMING(예정)·PAST(다녀온) — 정렬까지 서버가 해준다.
  /// 요약이 지역 이름·대표 이미지까지 주므로 요청 한 번으로 끝난다.
  Future<List<Map<String, dynamic>>> savedCourseCards({
    String scope = 'ALL',
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/courses',
        queryParameters: {'scope': scope},
      );
      return [
        for (final summary
            in (ApiEnvelope.unwrap(response) as List)
                .cast<Map<String, dynamic>>())
          _toSavedCardMap(summary),
      ];
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 저장한 코스 하나 (`GET /courses/{id}`) — 목록 카드와 일정 화면이 같이 쓴다.
  Future<({Map<String, dynamic> saved, Map<String, dynamic> course})?>
  savedCourseDetail(String courseId) async {
    try {
      final id = int.parse(courseId);
      // 상세 응답에는 차감 여부가 없어 목록 요약에서 찾아 채운다. 두 요청은
      // 서로를 기다릴 이유가 없어 함께 띄운다 — 화면이 그만큼 빨리 뜬다.
      //
      // `.wait`는 쓰지 않는다. 상세가 404를 던지면 ParallelWaitError로 감싸여
      // 아래 `on ApiException`이 잡지 못한다.
      // TODO(server): CourseResponse에 leaveDeducted가 실리면 걷어낼 것
      final summaryFuture = _findSummary(id);
      final data = await _fetchCourse(id);
      final found = await summaryFuture;
      return (
        saved: _toSavedCardMap(found ?? _summaryFromDetail(data), data),
        course: _toCourseMap(data),
      );
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// 목록에서 이 코스의 요약을 찾는다 — 못 찾으면 null
  Future<Map<String, dynamic>?> _findSummary(int courseId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/courses',
        queryParameters: const {'scope': 'ALL'},
      );
      return (ApiEnvelope.unwrap(response) as List)
          .cast<Map<String, dynamic>>()
          .where((s) => (s['courseId'] as num).toInt() == courseId)
          .firstOrNull;
    } on DioException {
      return null; // 보조 정보라 실패해도 상세는 그대로 보여준다
    } on ApiException {
      // 공통 래퍼가 실패로 와도 마찬가지 — 상세를 막지 않는다
      return null;
    }
  }

  /// 확정한 코스의 연차를 차감한다 (`POST /courses/{id}/leave-deduction`).
  ///
  /// 날짜 있는 코스만 가능하고 멱등이다(중복 호출해도 한 번만 차감).
  /// 코스를 삭제하면 서버가 차감을 알아서 되돌린다 — 취소 호출은 필요 없다.
  Future<void> deductLeave(int courseId) async {
    try {
      await _dio.post<dynamic>(
        '/api/v1/courses/$courseId/leave-deduction',
        data: const <String, dynamic>{},
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 홈에서 물어볼 지난 여행 (`GET /courses/pending-trips`).
  ///
  /// 끝났고(종료일 < 오늘) 아직 답하지 않은 코스만 온다. 모달을 그리는 데
  /// 필요한 값(지역명·날짜·차감될 연차·좌표)이 응답 하나에 다 들어 있다.
  /// 비어 있으면 물어볼 게 없다는 뜻이다.
  Future<({double? remainingDays, List<Map<String, dynamic>> trips})>
  pendingTrips() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/courses/pending-trips');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return (
        remainingDays: (data['remainingDays'] as num?)?.toDouble(),
        trips: ((data['trips'] as List?) ?? const [])
            .cast<Map<String, dynamic>>(),
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 지난 여행에 다녀왔는지 답한다 (`POST /courses/{id}/trip-outcome`).
  ///
  /// [visited]가 참이면 서버가 이때 연차를 깎는다. 안 갔어도 반드시 답해야
  /// 한다 — 기록하지 않으면 홈을 열 때마다 다시 묻는다.
  /// 답한 뒤의 잔여 연차를 돌려주므로 화면이 바로 고쳐 그릴 수 있다.
  ///
  /// 이미 답했거나 아직 끝나지 않은 여행이면 409가 온다.
  Future<double?> answerTripOutcome(
    int courseId, {
    required bool visited,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/courses/$courseId/trip-outcome',
        data: {'outcome': visited ? 'VISITED' : 'NOT_VISITED'},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>?;
      return (data?['remainingDays'] as num?)?.toDouble();
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 저장한 코스를 지운다 (`DELETE /courses/{id}`).
  Future<void> delete(String courseId) async {
    try {
      await _dio.delete<dynamic>('/api/v1/courses/$courseId');
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 공유 링크로 받은 코스 (`GET /public/courses/{shareToken}`).
  ///
  /// 인증이 필요 없다 — 링크를 받은 사람에게는 계정이 없다.
  /// 소유자 정보와 내부 courseId는 실리지 않고, 보기 전용이다.
  Future<Map<String, dynamic>> sharedCourse(String shareToken) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/public/courses/$shareToken',
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return _toCourseMap(data);
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 여행 날짜를 옮긴다 (`PATCH /courses/{id}`).
  ///
  /// 서버가 연차 차감량을 다시 계산한다 — 옮긴 구간의 평일·공휴일이 달라지기
  /// 때문. 이미 차감한 코스면 기존 내역을 새 값으로 갱신한다.
  Future<void> reschedule({
    required String courseId,
    required DateTime travelDate,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        '/api/v1/courses/$courseId',
        data: {'travelDate': isoDate(travelDate)},
      );
      ApiEnvelope.unwrap(response);
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 장소 상세 (`GET /pois/{contentId}`) — 주소·운영시간·휴무일·소개·좌표.
  ///
  /// useTime·restDate는 TourAPI 자유 텍스트("매주 월요일", "상시 개방" 등)라
  /// 해석은 화면 몫이다.
  Future<Map<String, dynamic>> poiDetail(String contentId) async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/pois/$contentId');
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      // TourAPI 원문에는 <br> 같은 HTML이 섞여 온다 — 화면에 내보내기 전에 걷어낸다
      for (final key in const [
        'title',
        'address',
        'useTime',
        'restDate',
        'overview',
        'catchphrase',
      ]) {
        if (data[key] is String) {
          data[key] = cleanTourApiText(data[key] as String);
        }
      }
      return data;
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 장소의 운영 정보만 — 여행 당일 휴무일·운영시간 안내에 쓴다.
  Future<({String? useTime, String? restDate})> poiSchedule(
    String contentId,
  ) async {
    final data = await poiDetail(contentId);
    return (
      useTime: data['useTime'] as String?,
      restDate: data['restDate'] as String?,
    );
  }

  Future<Map<String, dynamic>> _fetchCourse(int courseId) async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/courses/$courseId');
      return ApiEnvelope.unwrap(response) as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  // ── 응답 → 화면 형태 ────────────────────────────────────────────────

  /// 서버 코스 → 코스확정 화면·지도·장소 목록이 읽는 형태.
  ///
  /// 지도는 mock 시절 키(mapx=경도·mapy=위도)를 쓰므로 그대로 맞춰준다.
  /// [savePayload]가 있으면 '_save'로 실어 화면이 그대로 저장 API에 넘긴다.
  Map<String, dynamic> _toCourseMap(
    Map<String, dynamic> course, {
    Map<String, dynamic>? savePayload,
  }) {
    final days = (course['days'] as List).cast<Map<String, dynamic>>();
    final benefits = (course['benefits'] as List?) ?? const [];
    return {
      'regionName': _regionNameOf(course),
      // 서버 JSON이 2.0처럼 실수로 보내도 깨지지 않게 num으로 받아 정규화한다
      'durationDays': (course['travelDays'] as num).toInt(),
      'travelDate': course['travelDate'],
      'days': [
        for (final day in days)
          {
            'day': day['day'],
            'date': day['date'],
            'weather': day['weather'],
            // 서버가 요일을 준다 — 날짜로 다시 계산하지 않는다
            'dayOfWeek': day['dayOfWeek'],
            // 전날 마지막 장소에서 이 날 첫 장소까지 (첫날은 없다)
            'distanceFromPrevDayMeters': day['distanceFromPrevDayMeters'],
            'travelMinutesFromPrevDay': day['travelMinutesFromPrevDay'],
            'places': [
              for (final item
                  in (day['items'] as List).cast<Map<String, dynamic>>())
                {
                  'name': item['title'],
                  'category': item['categoryLabel'],
                  'catchphrase': item['catchphrase'],
                  // 색 구분(숙박 등)은 라벨이 아니라 종류 코드로 한다
                  'kind': item['kind'],
                  'poiContentId': item['poiContentId'],
                  'imageUrl': item['imageUrl'],
                  'address': item['address'],
                  'mapx': item['lng'],
                  'mapy': item['lat'],
                  'distanceFromPrevMeters': item['distanceFromPrevMeters'],
                  'travelMinutes': item['travelMinutes'],
                  // 사진이 없는 장소에만 온다 — 지도 검색으로 대신 보낸다
                  'mapSearchUrl': item['mapSearchUrl'],
                },
            ],
          },
      ],
      if (benefits.isNotEmpty)
        'benefitBadge': (benefits.first as Map<String, dynamic>)['text'],
      '_save': ?savePayload,
    };
  }

  /// 저장 API가 받는 형태 — 생성 응답의 슬롯을 저장 계약 필드만 남겨 되돌린다
  Map<String, dynamic> _toSavePayload(
    Map<String, dynamic> course, {
    required String density,
    required String transport,
    required DateTime? confirmedDate,
  }) {
    final days = (course['days'] as List).cast<Map<String, dynamic>>();
    return {
      'regionId': course['regionId'],
      'density': density,
      'transport': transport,
      if (confirmedDate != null) 'travelDate': isoDate(confirmedDate),
      'days': [
        for (final day in days)
          {
            'day': day['day'],
            'items': [
              for (final item
                  in (day['items'] as List).cast<Map<String, dynamic>>())
                {
                  'order': item['order'],
                  'timeOfDay': item['timeOfDay'],
                  'kind': item['kind'],
                  'poiContentId': item['poiContentId'],
                  'title': item['title'],
                  'imageUrl': item['imageUrl'],
                  'address': item['address'],
                  'catchphrase': item['catchphrase'],
                  'lat': item['lat'],
                  'lng': item['lng'],
                  'travelMinutes': item['travelMinutes'],
                },
            ],
          },
      ],
    };
  }

  /// 요약 + 상세 → 내 코스 목록 카드가 읽는 형태
  /// [detail]은 단건 조회 경로에서만 넘어온다. 목록은 요약만으로 카드를
  /// 만든다 — 서버가 regionName·coverImageUrl을 요약에 실어주기 때문이다.
  Map<String, dynamic> _toSavedCardMap(
    Map<String, dynamic> summary, [
    Map<String, dynamic>? detail,
  ]) {
    final id = (summary['courseId'] as num).toString();
    final travelDays = (summary['travelDays'] as num).toInt();
    final travelDate = summary['travelDate'] as String?;
    final start = travelDate == null ? null : DateTime.parse(travelDate);
    return {
      'id': id,
      'courseId': id,
      'regionId': (summary['regionId'] as num).toString(),
      'regionName':
          summary['regionName'] as String? ??
          (detail == null ? '' : _regionNameOf(detail)),
      'durationLabel': switch (travelDays) {
        1 => '당일치기',
        2 => '1박 2일',
        _ => '2박 3일',
      },
      // 여행 날짜가 있어야 '일정 확정'이다 — 추정 날짜는 저장 시 싣지 않는다
      'confirmed': travelDate != null,
      // 연차를 이미 깎았는지 — 차감 액션 노출 여부를 이 값이 정한다
      'leaveDeducted': summary['leaveDeducted'] as bool? ?? false,
      // 공유 링크를 만들 토큰. 상세·목록 어느 쪽에서 왔든 실려 있다
      'shareToken': (detail?['shareToken'] ?? summary['shareToken']) as String?,
      'startDate': ?travelDate,
      if (start != null)
        'endDate': isoDate(
          DateTime(start.year, start.month, start.day + travelDays - 1),
        ),
      // coverImageUrl은 아직 서버가 비워 보낼 때가 있어 첫 장소로 폴백한다
      'thumbnailUrl':
          summary['coverImageUrl'] as String? ??
          (detail == null ? null : _firstImageOf(detail)),
    };
  }

  /// 상세 응답만으로 요약과 같은 꼴을 만든다 (단건 조회 경로용)
  Map<String, dynamic> _summaryFromDetail(Map<String, dynamic> detail) => {
    'courseId': detail['courseId'],
    'regionId': detail['regionId'],
    'travelDate': detail['travelDate'],
    'travelDays': detail['travelDays'],
  };

  /// 첫날 첫 장소 이미지 — 요약에 대표 이미지가 없을 때의 폴백
  String? _firstImageOf(Map<String, dynamic> course) {
    final days = (course['days'] as List?) ?? const [];
    if (days.isEmpty) return null;
    final items = (days.first as Map<String, dynamic>)['items'] as List;
    if (items.isEmpty) return null;
    return (items.first as Map<String, dynamic>)['imageUrl'] as String?;
  }

  /// 지역 이름은 응답 본문이 아니라 슬롯에 실려 온다
  String _regionNameOf(Map<String, dynamic> course) {
    final days = (course['days'] as List?) ?? const [];
    if (days.isEmpty) return '';
    final items = (days.first as Map<String, dynamic>)['items'] as List;
    if (items.isEmpty) return '';
    return (items.first as Map<String, dynamic>)['regionName'] as String? ?? '';
  }
}
