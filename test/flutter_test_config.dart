import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 모든 위젯 테스트에 앱 서체를 실어준다.
///
/// 기본 테스트 환경은 Ahem — 모든 글자가 1em 정사각형인 더미 폰트다. 글자
/// 폭이 실제와 달라, 줄바꿈이나 요소 폭을 재는 검사가 실기기와 다른 결론을
/// 낸다(15px 본문 한 줄이 Ahem에서는 272px, Pretendard에서는 199px).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = FontLoader('Pretendard');
  for (final path in const [
    'assets/fonts/Pretendard-Regular.otf',
    'assets/fonts/Pretendard-Medium.otf',
    'assets/fonts/Pretendard-SemiBold.otf',
    'assets/fonts/Pretendard-Bold.otf',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  }
  await loader.load();

  await testMain();
}
