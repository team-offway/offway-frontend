import 'package:dio/dio.dart';

/// 서버 공통 래퍼 `{status, data, detail, code, pageResponse}`를 다룬다.
///
/// 모든 API가 이 형태로 감싸 내려오므로 repository는 [unwrap]으로 `data`만
/// 꺼내 쓴다. 실패 응답도 같은 래퍼로 오고 `detail`이 사용자에게 보여줄
/// 한국어 문구라, 그대로 [ApiException]에 실어 화면까지 전달한다.
abstract final class ApiEnvelope {
  /// 성공 응답의 `code` 값 (백엔드 ApiResponseBody.SUCCESS_CODE)
  static const successCode = 'OK';

  /// 응답에서 `data`를 꺼낸다. 실패 래퍼면 [ApiException]을 던진다.
  ///
  /// 반환 타입은 호출부가 안다 — 목록이면 List, 객체면 Map으로 캐스팅해 쓴다.
  ///
  /// **출처(`sources`)는 여기서 꺼내지 않는다.** 28곳이 이 함수를 부르는데
  /// 반환값에 얹으면 호출부마다 그 값을 들고 다녀야 하고, 한 곳만 빠뜨려도
  /// 그 화면의 표기가 조용히 사라진다 — 표기 누락은 공모전 규정 위반이다.
  /// 대신 인터셉터가 응답을 지나가며 [DataSourceRegistry]에 모은다
  static dynamic unwrap(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw ApiException(
        status: response.statusCode ?? 0,
        code: 'CLIENT-PARSE',
        detail: '서버 응답을 이해할 수 없어요.',
      );
    }
    if (body['code'] != successCode) {
      throw ApiException.fromBody(body);
    }
    return body['data'];
  }

  /// 응답 래퍼의 `sources` → 출처 목록 (core #417).
  ///
  /// **서버가 라벨까지 준다.** 앱이 매핑 표를 들면 출처가 하나 늘었을 때
  /// 표에 없는 값을 그리지 못해 앱 배포 전까지 화면에서 그 출처가 빈다.
  /// `key`는 특정 기관만 다르게 그릴 때 문구를 비교하지 않으려고 함께 온다.
  ///
  /// 실패 응답과 data 없는 성공에는 안 실린다 — 빌려온 값이 없으니 표기할
  /// 것도 없다. null이 아니라 빈 목록이라 화면이 유무를 분기하지 않는다
  static List<DataSource> sourcesOf(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map<String, dynamic>) return const [];
    return DataSource.parseList(body['sources']);
  }

  /// Dio 예외를 [ApiException]으로 바꾼다.
  ///
  /// 서버가 4xx/5xx로 답하면 Dio는 예외를 던지지만 바디에는 여전히 공통
  /// 래퍼가 들어 있다. 그 안의 `detail`을 살려야 "왜 안 되는지"를 보여줄 수 있다.
  static ApiException toApiException(DioException e) {
    final body = e.response?.data;
    if (body is Map<String, dynamic> && body['code'] is String) {
      return ApiException.fromBody(body);
    }
    return ApiException(
      status: e.response?.statusCode ?? 0,
      code: 'CLIENT-NETWORK',
      detail: switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => '서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
        DioExceptionType.connectionError => '서버에 연결할 수 없어요. 네트워크를 확인해 주세요.',
        _ => '요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.',
      },
    );
  }
}

/// 서버가 실패로 답했거나 응답을 해석하지 못했을 때.
///
/// [detail]은 사용자에게 그대로 보여줄 수 있는 문구다 (서버가 한국어로 내려줌).
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.detail,
  });

  factory ApiException.fromBody(Map<String, dynamic> body) => ApiException(
    status: body['status'] as int? ?? 0,
    code: body['code'] as String? ?? 'UNKNOWN',
    detail: body['detail'] as String? ?? '요청을 처리하지 못했어요.',
  );

  final int status;
  final String code;
  final String detail;

  /// 임시 Basic 게이트(#122)나 만료된 토큰에 막힌 경우
  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($code, $status): $detail';
}

/// 이 응답이 빌려 쓴 공공데이터의 출처 하나 (core #417).
///
/// 공모전 규정이 출처 표기를 요구한다 — `출처: ⓒ한국관광공사`는 되고
/// `TourAPI`처럼 API 서비스명만 단독으로 적는 것은 안 된다. **로고 이미지는
/// 못 쓰고 텍스트 표기만 허용**된다.
class DataSource {
  const DataSource({required this.key, required this.label});

  static List<DataSource> parseList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) ?tryParse(item),
    ];
  }

  static DataSource? tryParse(Map<String, dynamic> json) {
    final label = (json['label'] as String?)?.trim();
    // 라벨이 없으면 화면에 쓸 말이 없다 — 빈칸을 그리느니 뺀다
    if (label == null || label.isEmpty) return null;
    return DataSource(
      key: (json['key'] as String?)?.trim() ?? '',
      label: label,
    );
  }

  /// 기관을 가리키는 계약 키 — `KTO`·`LOCAL_PERMIT`·`KHS`·`KMA`·`KASI`.
  /// 문구가 다듬어져도 이 값은 그대로다
  final String key;

  /// 화면에 그대로 쓰는 기관명 — `한국관광공사`. **서버가 정한다**
  final String label;

  @override
  bool operator ==(Object other) =>
      other is DataSource && other.key == key && other.label == label;

  @override
  int get hashCode => Object.hash(key, label);

  @override
  String toString() => 'DataSource($key, $label)';
}
