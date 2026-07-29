import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/tokens/tokens.dart';

/// Figma DS 값과 코드가 어긋나지 않도록 고정한다.
/// 토큰을 고칠 일이 생기면 Figma를 먼저 확인하고 여기 기대값도 함께 바꾼다.
void main() {
  group('Semantic 토큰은 Figma DS 값과 일치한다', () {
    test('Label', () {
      expect(AppColors.labelNormal, const Color(0xFF171719));
      expect(AppColors.labelStrong, const Color(0xFF000000));
      expect(AppColors.labelNeutral, const Color(0xE02E2F33)); // CN22 · 88%
      expect(AppColors.labelAlternative, const Color(0x9C37383C)); // CN25 · 61%
      expect(AppColors.labelAssistive, const Color(0x4737383C)); // CN25 · 28%
      expect(AppColors.labelDisable, const Color(0x2937383C)); // CN25 · 16%
    });

    test('Primary — 2026-07-30 DS 개편으로 하늘색 계열', () {
      expect(AppColors.primaryNormal, const Color(0xFF3DC2FF));
      expect(AppColors.primaryStrong, const Color(0xFF00AEFF));
      expect(AppColors.primaryHeavy, const Color(0xFF008DCF));
    });

    test('Background', () {
      expect(AppColors.backgroundNormal, const Color(0xFFFFFFFF));
      expect(AppColors.backgroundNormalAlternative, const Color(0xFFF7F7F8));
      expect(AppColors.backgroundElevated, const Color(0xFFFFFFFF));
      expect(AppColors.backgroundElevatedAlternative, const Color(0xFFF7F7F8));
      // Transparent 계열은 Figma가 불투명 흰색으로 내려준다 (디자이너 확인 대기)
      expect(AppColors.backgroundTransparent, const Color(0xFFFFFFFF));
      expect(
        AppColors.backgroundTransparentAlternative,
        const Color(0xFFFFFFFF),
      );
    });

    test('Line — 반투명과 불투명 계열이 구분된다', () {
      expect(AppColors.lineNormal, const Color(0x3870737C)); // CN50 · 22%
      expect(AppColors.lineNormalNeutral, const Color(0x5270737C)); // 32%
      expect(AppColors.lineNormalAlternative, const Color(0x1470737C)); // 8%
      expect(AppColors.lineNormalStrong, const Color(0x8570737C)); // 52%
      // Solid는 배경 위에 얹은 최종색이라 불투명하다
      expect(AppColors.lineSolidNormal, const Color(0xFFE1E2E4));
      expect(AppColors.lineSolidNeutral, const Color(0xFFEAEBEC));
      expect(AppColors.lineSolidAlternative, const Color(0xFFF4F4F5));
    });

    test('Fill', () {
      expect(AppColors.fillNormal, const Color(0x1470737C)); // CN50 · 8%
      expect(AppColors.fillStrong, const Color(0x2970737C)); // 16%
      expect(AppColors.fillAlternative, const Color(0x0D70737C)); // 5%
    });

    test('Status · Interaction · Inverse', () {
      expect(AppColors.statusPositive, const Color(0xFF00BF40));
      expect(AppColors.statusCautionary, const Color(0xFFFF9200));
      expect(AppColors.statusNegative, const Color(0xFFFF4242));
      expect(AppColors.interactionInactive, const Color(0xFF989BA2));
      expect(AppColors.interactionDisable, const Color(0xFFF4F4F5));
      expect(AppColors.inversePrimary, const Color(0xFF3385FF));
      expect(AppColors.inverseBackground, const Color(0xFF1B1C1E));
      expect(AppColors.inverseLabel, const Color(0xFFF7F7F8));
    });

    test('Material · Static · Initial', () {
      expect(AppColors.materialDimmer, const Color(0x85171719)); // CN10 · 52%
      expect(AppColors.staticWhite, const Color(0xFFFFFFFF));
      expect(AppColors.staticBlack, const Color(0xFF000000));
      expect(AppColors.initialBlack, const Color(0xFF000000));
      expect(AppColors.initialWhite, const Color(0xFFFFFFFF));
    });
  });

  group('Semantic은 Atomic을 가리킨다', () {
    test('같은 색이면 같은 상수를 참조한다', () {
      expect(AppColors.labelNormal, AppPalette.coolNeutral10);
      expect(AppColors.primaryNormal, AppPalette.lightBlue60);
      expect(AppColors.statusNegative, AppPalette.red50);
      expect(AppColors.backgroundNormalAlternative, AppPalette.coolNeutral99);
    });
  });

  group('Atomic 팔레트', () {
    test('명도 단계가 숫자 순서대로 밝아진다', () {
      // 낮은 숫자일수록 어둡다 — 단계를 잘못 옮기면 여기서 걸린다
      final steps = <Color>[
        AppPalette.coolNeutral5,
        AppPalette.coolNeutral10,
        AppPalette.coolNeutral30,
        AppPalette.coolNeutral50,
        AppPalette.coolNeutral70,
        AppPalette.coolNeutral90,
        AppPalette.coolNeutral99,
      ];
      for (var i = 1; i < steps.length; i++) {
        expect(
          steps[i].computeLuminance(),
          greaterThan(steps[i - 1].computeLuminance()),
          reason: '$i번째 단계가 이전 단계보다 밝아야 한다',
        );
      }
    });

    test('대표 색상값', () {
      expect(AppPalette.common0, const Color(0xFF000000));
      expect(AppPalette.common100, const Color(0xFFFFFFFF));
      expect(AppPalette.blue50, const Color(0xFF0066FF));
      expect(AppPalette.offway50, const Color(0xFF18D2FE));
      expect(AppPalette.offway10, const Color(0xFF063540));
      expect(AppPalette.offway99, const Color(0xFFF6FDFF));
      expect(AppPalette.coolNeutral50, const Color(0xFF70737C));
      expect(AppPalette.green50, const Color(0xFF00BF40));
      expect(AppPalette.pink46, const Color(0xFFE846CD));
    });
  });

  group('Accent 색상', () {
    test('Foreground는 Background보다 어둡다(대비 확보)', () {
      expect(
        AppAccentColors.foregroundViolet.computeLuminance(),
        lessThan(AppAccentColors.backgroundViolet.computeLuminance()),
      );
      expect(
        AppAccentColors.foregroundCyan.computeLuminance(),
        lessThan(AppAccentColors.backgroundCyan.computeLuminance()),
      );
    });
  });

  group('Opacity 단계', () {
    test('0~1 범위이고 오름차순이다', () {
      const steps = [
        AppOpacity.o5,
        AppOpacity.o8,
        AppOpacity.o12,
        AppOpacity.o16,
        AppOpacity.o22,
        AppOpacity.o28,
        AppOpacity.o35,
        AppOpacity.o43,
        AppOpacity.o52,
        AppOpacity.o61,
        AppOpacity.o74,
        AppOpacity.o88,
        AppOpacity.o97,
        AppOpacity.o100,
      ];
      expect(steps.first, greaterThan(0));
      expect(steps.last, 1.0);
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i], greaterThan(steps[i - 1]));
      }
    });
  });
}
