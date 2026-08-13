import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
