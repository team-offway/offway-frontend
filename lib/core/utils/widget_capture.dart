import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// [widget]을 화면 밖에서 한 프레임 그려 PNG 바이트로 만든다.
///
/// 오버레이에 잠깐 얹어 레이아웃·페인트를 거치게 하되, 멀리 밀어놔서 눈에는
/// 보이지 않는다. 높이는 내용만큼 늘어난다.
Future<Uint8List> captureWidgetPng(
  BuildContext context, {
  required Widget widget,
  required double width,
  double pixelRatio = 3,
}) async {
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
