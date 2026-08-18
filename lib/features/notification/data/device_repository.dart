import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(ref.watch(dioProvider)),
);

/// 푸시를 받을 기기 등록 (`/api/v1/devices`, core #274).
class DeviceRepository {
  DeviceRepository(this._dio);

  final Dio _dio;

  /// FCM 토큰을 등록하거나 갱신한다.
  ///
  /// **몇 번을 보내도 결과가 같다** — 서버가 (소유자, 토큰)으로 한 행만 둔다.
  /// 실패했는지 애매하면 그냥 다시 보내면 된다.
  Future<void> register(String token) async {
    try {
      await _dio.post<dynamic>(
        '/api/v1/devices',
        data: {'token': token, 'platform': Platform.isIOS ? 'IOS' : 'ANDROID'},
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 이 소유자의 토큰을 전부 해제한다 (로그아웃·탈퇴).
  ///
  /// 토큰을 받지 않는다 — 게스트 ID가 설치마다 발급되므로 그 아래 토큰은
  /// 사실상 이 기기의 것이다. 지울 것이 없어도 성공이다.
  Future<void> unregister() async {
    try {
      await _dio.delete<dynamic>('/api/v1/devices');
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }
}
