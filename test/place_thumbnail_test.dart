import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/widgets/place_thumbnail.dart';

/// 장소 썸네일의 디코드 폭 — 화면에서는 줄이고, 캡처에서는 원본 키를 쓴다.
void main() {
  const url = 'https://example.com/a.jpg';

  testWidgets('화면용은 그리는 폭까지만 디코드한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: PlaceThumbnail(imageUrl: url, size: 70)),
      ),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    // 70pt × 기기 배율(테스트는 3.0) = 210px
    expect(image.memCacheWidth, 210);
  });

  testWidgets('캡처용(decodeToFit: false)은 축소 없이 프리캐시와 같은 키로 그린다 (#155)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: PlaceThumbnail(imageUrl: url, size: 175, decodeToFit: false),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    // 폭이 붙으면 ResizeImage 키가 되어 precacheImage로 받아 둔 원본을 못 찾는다
    expect(image.memCacheWidth, isNull);
    expect(image.imageUrl, url);
  });
}
