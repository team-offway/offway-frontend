import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../../../../core/network/image_cache.dart';
import '../../../../core/utils/widget_capture.dart';
import '../../../../core/widgets/app_toast.dart';
import 'course_share_image.dart';

/// 코스 일정 이미지를 만들어 사진첩에 저장한다. [day]가 null이면 전체 일정.
///
/// 코스 확정(담기 전)과 내 코스 상세가 같은 흐름을 쓴다 — 이미지 모양은
/// [image]가 정하고(날짜·연차 뱃지 유무), 여기서는 캡처 → 저장 → 알림만 한다.
/// [fileName]은 확장자 없이 준다.
Future<void> saveCourseImage(
  BuildContext context, {
  required CourseShareImage image,
  required String fileName,
}) async {
  try {
    // 시안이 1080 기준이라 위젯도 그 폭으로 그린다 — 배율은 1로 두어야
    // 실제 결과가 1080이 된다
    final png = await captureWidgetPng(
      context,
      widget: image,
      width: 1080,
      pixelRatio: 1,
      precacheImages: courseShareImages(image.course, image.day),
      // 사용 연차 뱃지의 시계 — 미리 안 넣으면 캡처된 이미지에 빈칸이다
      precacheSvgs: const [CourseShareImage.clockAsset],
    );
    await Gal.putImageBytes(png, name: fileName);
    if (context.mounted) {
      showAppToast(context, '이미지를 저장했어요.', kind: AppToastKind.success);
    }
  } on GalException catch (e) {
    if (!context.mounted) return;
    showAppToast(
      context,
      e.type == GalExceptionType.accessDenied
          ? '설정에서 사진 접근 권한을 허용해 주세요'
          : '이미지를 저장하지 못했어요',
    );
  } catch (_) {
    if (context.mounted) showAppToast(context, '이미지를 저장하지 못했어요');
  }
}

/// 이미지에 들어갈 사진들 — 캡처 전에 받아 둬야 빈 자리로 찍히지 않는다
List<ImageProvider> courseShareImages(Map<String, dynamic> course, int? day) {
  final allDays = (course['days'] as List).cast<Map<String, dynamic>>();
  final days = day == null ? allDays : allDays.where((d) => d['day'] == day);
  return [
    const AssetImage('assets/images/share_hero.png'),
    for (final d in days)
      for (final p in (d['places'] as List).cast<Map<String, dynamic>>())
        if (p['imageUrl'] case final String url when url.isNotEmpty)
          // 목록이 이미 받아 둔 디스크 캐시를 그대로 쓴다 — NetworkImage는
          // 캐시를 모르고 다시 받는다
          CachedNetworkImageProvider(url, cacheManager: appImageCacheManager),
  ];
}
