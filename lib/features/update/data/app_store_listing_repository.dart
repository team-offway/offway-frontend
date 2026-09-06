import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App Store에 올라온 이 앱의 버전과 페이지 주소.
///
/// **우리 서버가 아니라 애플의 조회 API**를 부른다 — 서버에 앱 버전을 두는
/// API가 없고, 스토어가 곧 진실이다. 인증 인터셉터가 붙은 앱 Dio를 쓰면
/// 애플에 우리 JWT가 나가므로 맨 Dio를 따로 쓴다.
///
/// 심사 전이라 스토어에 없으면 `resultCount` 0이 온다 — 그때는 null이고
/// 업데이트를 묻지 않는다. 못 불러도 null이다. 홈이 이것 때문에 늦거나
/// 깨지면 안 된다.
final appStoreListingRepositoryProvider = Provider<AppStoreListingRepository>(
  (ref) => AppStoreListingRepository(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    ),
  ),
);

class AppStoreListingRepository {
  AppStoreListingRepository(this._dio);

  final Dio _dio;

  /// 번들 ID — 공개 식별자라 박아 둔다(AppConfig 주의사항과 같은 근거)
  static const bundleId = 'com.nth.offway';
  static const _lookupUrl = 'https://itunes.apple.com/lookup';

  /// `{version, url}` — 스토어에 없거나 못 읽으면 null
  Future<({String version, String url})?> latest() async {
    try {
      final response = await _dio.get<dynamic>(
        _lookupUrl,
        queryParameters: {'bundleId': bundleId, 'country': 'kr'},
      );
      // 애플이 content-type을 text/javascript로 주기도 해서 문자열로 올 수 있다
      final body = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (body is! Map<String, dynamic>) return null;
      final results = body['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map<String, dynamic>) return null;
      // 형식이 어긋난 응답(숫자 version, 객체 trackViewUrl)도 null이다 —
      // `as String?` 캐스팅이 던지면 프로바이더가 오류 상태가 되고, 그건
      // "업데이트 없음"과 달리 화면에 잡음을 남긴다
      final version = first['version'];
      final url = first['trackViewUrl'];
      if (version is! String || url is! String) return null;
      if (version.isEmpty || url.isEmpty) return null;
      return (version: version, url: url);
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
