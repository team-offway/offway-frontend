import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/rendering.dart';

/// [widget]을 화면 밖에서 그려 PNG 바이트로 만든다.
///
/// 오버레이에 잠깐 얹어 레이아웃·페인트를 거치게 하되, 멀리 밀어놔서 눈에는
/// 보이지 않는다. 높이는 내용만큼 늘어난다.
///
/// [precacheImages]에 위젯이 쓰는 이미지를 넘기면 **먼저 받아 둔 뒤** 캡처한다.
/// 한 프레임만 기다리면 이미지는 아직 디코드 전이라 빈 자리로 찍힌다.
Future<Uint8List> captureWidgetPng(
  BuildContext context, {
  required Widget widget,
  required double width,
  double pixelRatio = 3,
  List<ImageProvider> precacheImages = const [],
  List<String> precacheSvgs = const [],
}) async {
  // 이미지를 미리 받아 캐시에 올린다 — 실패한 것은 빈 자리로 두고 넘어간다
  for (final provider in precacheImages) {
    if (!context.mounted) break;
    try {
      await precacheImage(provider, context);
    } catch (_) {
      // 죽은 URL 하나 때문에 저장을 통째로 막지 않는다
    }
  }
  await precacheSvgAssets(precacheSvgs);
  if (!context.mounted) {
    throw StateError('캡처 중 화면이 사라졌습니다');
  }

  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 0,
      top: 0,
      child: Transform.translate(
        // Opacity(0)은 페인트 자체를 건너뛰어 캡처가 안 된다 — 밀어내기만 한다
        offset: const Offset(0, -100000),
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(width: width, child: widget),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // 캐시에 있어도 첫 프레임에는 자리만 잡히는 경우가 있어 두 번 기다린다
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}

/// SVG 에셋을 flutter_svg 캐시에 미리 넣는다.
///
/// SVG 는 첫 그리기에서 비동기로 로드된다 — 캡처가 두 프레임 안에 돌면 그
/// 자리가 빈 이미지가 된다. 미리 넣어 두면 첫 프레임부터 동기로 그려진다
/// (course_map 의 핀과 같은 방식). 부르는 쪽이 캡처 전에 기다려야 한다
Future<void> precacheSvgAssets(Iterable<String> assets) async {
  for (final asset in assets) {
    final loader = SvgAssetLoader(asset);
    await svg.cache.putIfAbsent(
      loader.cacheKey(null),
      () => loader.loadBytes(null),
    );
  }
}
