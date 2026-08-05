import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';

Response<dynamic> _response(dynamic body, {int status = 200}) => Response(
  requestOptions: RequestOptions(path: '/test'),
  statusCode: status,
  data: body,
);

void main() {
  group('unwrap', () {
    test('성공 래퍼에서 data만 꺼낸다', () {
      final data = ApiEnvelope.unwrap(
        _response({
          'status': 200,
          'data': {'name': '게스트'},
          'detail': '요청이 정상 처리되었습니다.',
          'code': 'OK',
          'pageResponse': null,
        }),
      );
      expect(data, {'name': '게스트'});
    });

    test('data가 null인 성공(204류)도 그대로 통과한다', () {
      final data = ApiEnvelope.unwrap(
        _response({'status': 200, 'data': null, 'detail': '', 'code': 'OK'}),
      );
      expect(data, isNull);
    });

    test('실패 래퍼면 서버 문구를 실은 예외를 던진다', () {
      expect(
        () => ApiEnvelope.unwrap(
          _response({
            'status': 401,
            'data': null,
            'detail': '인증이 필요합니다.',
            'code': 'COMMON-401',
          }),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.detail, 'detail', '인증이 필요합니다.')
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue),
        ),
      );
    });

    test('래퍼 형태가 아니면 해석 불가 예외를 던진다', () {
      expect(
        () => ApiEnvelope.unwrap(_response('<html>gateway error</html>')),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'CLIENT-PARSE'),
        ),
      );
    });
  });

  group('toApiException', () {
    test('에러 응답 바디의 래퍼에서 detail을 살린다', () {
      final e = ApiEnvelope.toApiException(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: _response({
            'status': 404,
            'data': null,
            'detail': '지역을 찾을 수 없습니다.',
            'code': 'REGION-404',
          }, status: 404),
        ),
      );
      expect(e.code, 'REGION-404');
      expect(e.detail, '지역을 찾을 수 없습니다.');
    });

    test('타임아웃은 재시도를 권하는 문구로 바꾼다', () {
      final e = ApiEnvelope.toApiException(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(e.code, 'CLIENT-NETWORK');
      expect(e.detail, contains('다시 시도'));
    });

    test('연결 실패는 네트워크 확인을 권한다', () {
      final e = ApiEnvelope.toApiException(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(e.detail, contains('네트워크'));
    });
  });
}
