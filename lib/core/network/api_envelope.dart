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
