import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/origin_locator.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(dioProvider)),
);

/// 코스 API (`/api/v1/courses`).
class CourseRepository {
  CourseRepository(this._dio);

  final Dio _dio;

  /// 지역·조건으로 코스를 생성한다 (`POST /courses/generate`).
  ///
  /// [regionId]는 라우트가 문자열로 나르므로 여기서 숫자로 되돌린다.
  /// [density]·[transport]는 서버 enum 문자열(PACKED·RELAXED / CAR·TRANSIT).
  Future<Map<String, dynamic>> generate({
    required String regionId,
    required int travelDays,
    required String density,
    required String transport,
    required Origin origin,
    required DateTime travelDate,
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
      return _toCourseMap(data);
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 서버 코스 → 코스확정 화면·지도·장소 목록이 읽는 형태.
  ///
  /// 지도는 mock 시절 키(mapx=경도·mapy=위도)를 쓰므로 그대로 맞춰준다.
  Map<String, dynamic> _toCourseMap(Map<String, dynamic> course) {
    final days = (course['days'] as List).cast<Map<String, dynamic>>();
    final benefits = (course['benefits'] as List?) ?? const [];
    final firstItem = days.isEmpty || (days.first['items'] as List).isEmpty
        ? null
        : (days.first['items'] as List).first as Map<String, dynamic>;
    return {
      'regionName': firstItem?['regionName'] ?? '',
      'durationDays': course['travelDays'],
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
    };
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
