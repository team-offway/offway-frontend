import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';

/// 공휴일 API(`GET /holidays?year=`, core #322) 어댑터.
///
/// 2026-08-24 배포 서버가 실제로 내려준 응답 형태 기준.
void main() {
  LeaveRepository repositoryWith(Map<String, dynamic> body) {
    final dio = Dio(BaseOptions())
      ..httpClientAdapter = _FixedResponseAdapter(body);
    return LeaveRepository(dio);
  }

  test('날짜 문자열을 자정 DateTime 집합으로 옮긴다', () async {
    final repository = repositoryWith(const {
      'status': 200,
      'data': {
        'year': 2026,
        'dates': ['2026-08-15', '2026-10-09'],
      },
      'detail': '요청이 정상 처리되었습니다.',
      'code': 'OK',
      'pageResponse': null,
    });

    final holidays = await repository.holidays(2026);
    // leaveDaysBetween이 자정 DateTime으로 비교하므로 형태가 맞아야 걸러진다
    expect(holidays, {DateTime(2026, 8, 15), DateTime(2026, 10, 9)});
  });

  test('공휴일 없는 해는 빈 집합 — 실패(502)와는 다른 답이다', () async {
    final repository = repositoryWith(const {
      'status': 200,
      'data': {'year': 2027, 'dates': []},
      'detail': '요청이 정상 처리되었습니다.',
      'code': 'OK',
      'pageResponse': null,
    });
    expect(await repository.holidays(2027), isEmpty);
  });

  test('응답의 연도가 요청과 다르면 던진다 — 다른 해의 공휴일로 계산하면 안 된다', () async {
    final repository = repositoryWith(const {
      'status': 200,
      'data': {
        'year': 2025,
        'dates': ['2025-01-01'],
      },
      'detail': '요청이 정상 처리되었습니다.',
      'code': 'OK',
      'pageResponse': null,
    });
    expect(repository.holidays(2026), throwsFormatException);
  });
}

/// 무슨 요청이든 준비된 바디로 답하는 어댑터 — 네트워크 없이 변환만 검증한다
class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
