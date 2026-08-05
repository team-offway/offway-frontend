import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/origin_locator.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

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
          'travelDate': _isoDate(travelDate),
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
          'travelDate': _isoDate(travelDate),
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

  /// 생성된 코스를 내 코스로 저장한다 (`POST /courses`). 저장된 courseId를 준다.
  Future<int> save(Map<String, dynamic> savePayload) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/courses',
        data: savePayload,
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return (data['courseId'] as num).toInt();
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 내 코스 목록 카드 (`GET /courses`).
  ///
  /// 요약에는 지역 이름이 없어 코스 상세를 병렬로 더 읽어 채운다.
  /// TODO(server): 요약 응답에 regionName이 실리면 상세 조회를 걷어낼 것.
  Future<List<Map<String, dynamic>>> savedCourseCards() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/courses');
      final summaries = (ApiEnvelope.unwrap(response) as List)
          .cast<Map<String, dynamic>>();
      final details = await Future.wait(
        summaries.map((s) => _fetchCourse((s['courseId'] as num).toInt())),
      );
      return [
        for (var i = 0; i < summaries.length; i++)
          _toSavedCardMap(summaries[i], details[i]),
      ];
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 저장한 코스 하나 (`GET /courses/{id}`) — 목록 카드와 일정 화면이 같이 쓴다.
  Future<({Map<String, dynamic> saved, Map<String, dynamic> course})?>
  savedCourseDetail(String courseId) async {
    try {
      final data = await _fetchCourse(int.parse(courseId));
      return (
        saved: _toSavedCardMap(_summaryFromDetail(data), data),
        course: _toCourseMap(data),
      );
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
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
            'places': [
              for (final item
                  in (day['items'] as List).cast<Map<String, dynamic>>())
                {
                  'name': item['title'],
                  'category': item['categoryLabel'],
                  'imageUrl': item['imageUrl'],
                  'address': item['address'],
                  'mapx': item['lng'],
                  'mapy': item['lat'],
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
      if (confirmedDate != null) 'travelDate': _isoDate(confirmedDate),
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
  Map<String, dynamic> _toSavedCardMap(
    Map<String, dynamic> summary,
    Map<String, dynamic> detail,
  ) {
    final id = (summary['courseId'] as num).toString();
    final travelDays = (summary['travelDays'] as num).toInt();
    final travelDate = summary['travelDate'] as String?;
    final start = travelDate == null ? null : DateTime.parse(travelDate);
    final firstItems = (detail['days'] as List).isEmpty
        ? const []
        : ((detail['days'] as List).first as Map<String, dynamic>)['items']
              as List;
    return {
      'id': id,
      'courseId': id,
      'regionId': (summary['regionId'] as num).toString(),
      'regionName': _regionNameOf(detail),
      'durationLabel': switch (travelDays) {
        1 => '당일치기',
        2 => '1박 2일',
        _ => '2박 3일',
      },
      // 여행 날짜가 있어야 '일정 확정'이다 — 추정 날짜는 저장 시 싣지 않는다
      'confirmed': travelDate != null,
      'startDate': ?travelDate,
      if (start != null)
        'endDate': _isoDate(
          DateTime(start.year, start.month, start.day + travelDays - 1),
        ),
      'thumbnailUrl': firstItems.isEmpty
          ? null
          : (firstItems.first as Map<String, dynamic>)['imageUrl'],
    };
  }

  /// 상세 응답만으로 요약과 같은 꼴을 만든다 (단건 조회 경로용)
  Map<String, dynamic> _summaryFromDetail(Map<String, dynamic> detail) => {
    'courseId': detail['courseId'],
    'regionId': detail['regionId'],
    'travelDate': detail['travelDate'],
    'travelDays': detail['travelDays'],
  };

  /// 지역 이름은 응답 본문이 아니라 슬롯에 실려 온다
  String _regionNameOf(Map<String, dynamic> course) {
    final days = (course['days'] as List?) ?? const [];
    if (days.isEmpty) return '';
    final items = (days.first as Map<String, dynamic>)['items'] as List;
    if (items.isEmpty) return '';
    return (items.first as Map<String, dynamic>)['regionName'] as String? ?? '';
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
