import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 아이콘 농도가 두 번 곱해지는 것을 막는다 (이슈 #226).
///
/// **`srcIn` 은 소스의 색상만 쓰고 대상의 알파는 남긴다.** 에셋에
/// `fill-opacity` 가 박혀 있는데 반투명 토큰을 `ColorFilter.mode(..., srcIn)`
/// 으로 씌우면 두 값이 곱해진다.
///
/// ```
/// 0.61 (에셋) x 0.61 (labelAlternative) = 0.37
/// ```
///
/// 실제로 세 번 겪었다 — 한산해요 배너의 i 아이콘(#222·#223·#224). 그때는
/// 에셋 하나만 고쳤고, 2026-09-14 전수 조사에서 같은 함정 두 곳을 더 찾았다
/// (홈 '더 보기' 쉐브론 · 지역 혜택 시트 쉐브론).
///
/// 사람이 매번 곱셈을 암산하는 대신 여기서 한 번에 막는다.
void main() {
  /// 알파가 1.0 이 아닌 Semantic 토큰 — 이것을 반투명 에셋에 씌우면 곱해진다
  Map<String, double> translucentTokens() {
    final src = File(
      'lib/core/theme/tokens/color_semantic.dart',
    ).readAsStringSync();
    final out = <String, double>{};
    for (final m in RegExp(
      r'static const (\w+) = Color\(0x([0-9A-Fa-f]{2})',
    ).allMatches(src)) {
      final a = int.parse(m.group(2)!, radix: 16) / 255;
      if (a < 0.99) out[m.group(1)!] = a;
    }
    return out;
  }

  /// `fill-opacity` 가 박힌 에셋 이름 → 그 값
  Map<String, double> translucentAssets() {
    final out = <String, double>{};
    for (final f in Directory('assets/icons').listSync().whereType<File>()) {
      if (!f.path.endsWith('.svg')) continue;
      final m = RegExp(
        r'fill-opacity="([0-9.]+)"',
      ).firstMatch(f.readAsStringSync());
      if (m != null) {
        out[f.uri.pathSegments.last] = double.parse(m.group(1)!);
      }
    }
    return out;
  }

  test('반투명 에셋에 반투명 토큰을 srcIn 으로 씌우지 않는다', () {
    final tokens = translucentTokens();
    final assets = translucentAssets();
    expect(assets, isNotEmpty, reason: '에셋을 하나도 못 읽었다면 경로가 틀렸다');

    final offenders = <String>[];
    for (final dart
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final lines = dart.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final asset = assets.keys.firstWhere(
          (a) => lines[i].contains(a),
          orElse: () => '',
        );
        if (asset.isEmpty) continue;
        // 같은 SvgPicture 안의 colorFilter 를 본다
        final window = lines
            .sublist(i, (i + 14).clamp(0, lines.length))
            .join('\n');
        final cf = RegExp(
          r'ColorFilter\.mode\(\s*(?:AppColors|AppPalette)\.(\w+)',
        ).firstMatch(window);
        if (cf == null) continue;
        final alpha = tokens[cf.group(1)!];
        if (alpha == null) continue; // 불투명 토큰이면 곱해지지 않는다
        offenders.add(
          '${dart.path}:${i + 1}  $asset(${assets[asset]}) '
          'x ${cf.group(1)}(${alpha.toStringAsFixed(2)}) '
          '= ${(assets[asset]! * alpha).toStringAsFixed(3)}',
        );
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '아이콘 농도가 두 번 곱해진다. 에셋의 fill-opacity 가 이미 시안 농도라면 '
          'colorFilter 를 빼고, 시안이 다른 농도라면 에셋에서 fill-opacity 를 '
          '걷어낸 사본을 쓴다:\n${offenders.join('\n')}',
    );
  });

  test('코스 배지의 시계는 불투명 사본을 쓴다', () {
    // 시안(1545:46487)은 시계가 글자와 같은 #3DC2FF 100% 다.
    // ic_clock 은 0.61 이 박혀 있어 불투명 색을 씌워도 61%로 나간다
    for (final path in [
      'lib/features/course/presentation/saved_course_screen.dart',
      'lib/features/course/presentation/shared_course_screen.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(
        src.contains('ic_clock_filled.svg'),
        isTrue,
        reason: '$path 의 배지가 불투명 시계를 써야 한다',
      );
    }
    expect(
      File('assets/icons/ic_clock_filled.svg').readAsStringSync(),
      isNot(contains('fill-opacity')),
      reason: '불투명 사본에 fill-opacity 가 남아 있으면 만든 뜻이 없다',
    );
  });
}
