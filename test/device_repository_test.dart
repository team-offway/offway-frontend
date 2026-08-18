import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/features/notification/data/device_repository.dart';

/// 푸시를 받을 기기 등록 — 요청 본문과 실패 처리를 고정한다.
void main() {
  late List<({String path, String method, Object? body})> sent;

  DeviceRepository repositoryWith({int status = 200}) {
    sent = [];
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.httpClientAdapter = _RecordingAdapter(sent, status);
    return DeviceRepository(dio);
  }

  test('토큰과 플랫폼을 함께 보낸다', () async {
    // platform이 enum이라 오타가 400이 된다 — 값을 직접 만들지 않는다
    await repositoryWith().register('fcm-token-abc');

    final request = sent.single;
    expect(request.path, '/api/v1/devices');
    expect(request.method, 'POST');

    final body = request.body! as Map;
    expect(body['token'], 'fcm-token-abc');
    expect(body['platform'], Platform.isIOS ? 'IOS' : 'ANDROID');
  });

  test('해제는 토큰을 보내지 않는다', () async {
    // 게스트 ID가 설치마다 발급되므로 그 아래 토큰은 이 기기의 것이다
    await repositoryWith().unregister();

    final request = sent.single;
    expect(request.path, '/api/v1/devices');
    expect(request.method, 'DELETE');
    expect(request.body, isNull);
  });

  test('등록이 실패하면 ApiException으로 올라온다', () async {
    // 부르는 쪽이 삼킬지 알릴지 정한다
    await expectLater(
      repositoryWith(status: 500).register('fcm-token-abc'),
      throwsA(isA<ApiException>()),
    );
  });
}

/// 요청을 받아 적고 지정한 상태로 답하는 어댑터
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.sent, this.status);

  final List<({String path, String method, Object? body})> sent;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add((path: options.path, method: options.method, body: options.data));
    if (status >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: {'status': status, 'code': 'X', 'detail': '실패'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      '{"status":200,"code":"OK","data":null}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
