import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../domain/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(dioProvider)),
);

/// 알림 조회·읽음 처리 (`/api/v1/notifications`, core #263).
class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  /// 알림 목록 — 최근 것부터.
  ///
  /// [unreadCount]는 **이 페이지가 아니라 전체** 안읽음 수다. 홈 배지가 쓴다.
  Future<({List<AppNotification> notifications, int unreadCount})> fetch({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/notifications',
        queryParameters: {'page': page, 'size': size},
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>;
      return (
        notifications: ((data['notifications'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .toList(),
        unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 알림 하나를 읽음으로 바꾸고 남은 안읽음 수를 돌려준다.
  ///
  /// 이미 읽은 알림에 다시 보내도 200이다 — 화면이 중복 호출을 막지 않아도 된다.
  Future<int> markRead(int notificationId) async {
    try {
      final response = await _dio.patch<dynamic>(
        '/api/v1/notifications/$notificationId/read',
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>?;
      return (data?['unreadCount'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }

  /// 전부 읽음 처리하고 남은 안읽음 수(0)를 돌려준다
  Future<int> markAllRead() async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/notifications/read-all',
      );
      final data = ApiEnvelope.unwrap(response) as Map<String, dynamic>?;
      return (data?['unreadCount'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiEnvelope.toApiException(e);
    }
  }
}
