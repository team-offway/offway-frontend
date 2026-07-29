import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';

/// Figma DS의 텍스트 스타일과 코드가 어긋나지 않도록 고정한다.
/// 토큰을 고칠 일이 생기면 Figma를 먼저 확인하고 여기 기대값도 함께 바꾼다.
void main() {
  group('크기 스케일은 Figma와 일치한다', () {
    test('Title', () {
      // Display(56~36)는 2026-07-30 DS 개편으로 제거됐다
      expect(AppTypography.title1Bold.fontSize, 32);
      expect(AppTypography.title2Bold.fontSize, 28);
      expect(AppTypography.title3Bold.fontSize, 24);
    });

    test('Heading · Headline · Body · Label · Caption', () {
      expect(AppTypography.heading1Bold.fontSize, 22);
      expect(AppTypography.heading2Bold.fontSize, 20);
      expect(AppTypography.headline1Bold.fontSize, 18);
      expect(AppTypography.headline2Bold.fontSize, 17);
      expect(AppTypography.body1NormalBold.fontSize, 16);
      expect(AppTypography.body2NormalBold.fontSize, 15);
      expect(AppTypography.label1NormalBold.fontSize, 14);
      expect(AppTypography.label2Bold.fontSize, 13);
      expect(AppTypography.caption1Bold.fontSize, 12);
      expect(AppTypography.caption2Bold.fontSize, 11);
    });
  });

  group('굵기', () {
    test('Title의 Bold는 700, Heading 이하는 600이다', () {
      // DS가 큰 스케일만 진짜 Bold를 쓰고 나머지는 SemiBold를 쓴다
      expect(AppTypography.title1Bold.fontWeight, FontWeight.w700);
      expect(AppTypography.title3Bold.fontWeight, FontWeight.w700);
      expect(AppTypography.heading1Bold.fontWeight, FontWeight.w600);
      expect(AppTypography.body1NormalBold.fontWeight, FontWeight.w600);
      expect(AppTypography.caption2Bold.fontWeight, FontWeight.w600);
    });

    test('Medium은 500, Regular는 400이다', () {
      expect(AppTypography.title1Medium.fontWeight, FontWeight.w500);
      expect(AppTypography.body1NormalMedium.fontWeight, FontWeight.w500);
      expect(AppTypography.title1Regular.fontWeight, FontWeight.w400);
      expect(AppTypography.body1NormalRegular.fontWeight, FontWeight.w400);
    });
  });

  group('행간·자간', () {
    test('대표 스타일의 행간이 Figma 값과 같다', () {
      expect(AppTypography.title1Bold.height, closeTo(1.375, 0.0005));
      expect(AppTypography.body1NormalRegular.height, closeTo(1.5, 0.0005));
      expect(AppTypography.caption2Regular.height, closeTo(1.273, 0.0005));
    });

    test('Reading 변형은 Normal보다 행간이 넓다', () {
      // 긴 글용이라 줄 간격이 더 크다 — 두 변형을 뒤바꿔 옮기면 여기서 걸린다
      expect(
        AppTypography.body1ReadingRegular.height!,
        greaterThan(AppTypography.body1NormalRegular.height!),
      );
      expect(
        AppTypography.body2ReadingRegular.height!,
        greaterThan(AppTypography.body2NormalRegular.height!),
      );
      expect(
        AppTypography.label1ReadingRegular.height!,
        greaterThan(AppTypography.label1NormalRegular.height!),
      );
    });

    test('자간은 큰 글씨일수록 좁고 작은 글씨일수록 넓다', () {
      // Figma는 em(크기 대비 %)으로 주므로 px로 환산돼 있어야 한다.
      // 예: Title 1 = 32 × -2.53% = -0.8096 (에 -2.53을 그대로 넣으면 자간이 붕 뜬다)
      expect(AppTypography.title1Bold.letterSpacing, closeTo(-0.8096, 0.0001));
      expect(AppTypography.headline2Bold.letterSpacing, 0);
      expect(AppTypography.caption2Bold.letterSpacing, closeTo(0.3421, 0.0001));
      expect(
        AppTypography.title1Bold.letterSpacing!,
        lessThan(AppTypography.caption2Bold.letterSpacing!),
      );
    });
  });

  group('서체는 테마에서 한 번만 지정한다', () {
    // 토큰은 서체를 비워두고 테마가 공급한다. 둘 중 하나만 검사하면
    // 계약이 깨져도(예: 테마에서 fontFamily가 빠져도) 드러나지 않는다.
    test('토큰에는 fontFamily가 없다', () {
      expect(AppTypography.title1Bold.fontFamily, isNull);
      expect(AppTypography.body1NormalRegular.fontFamily, isNull);
      expect(AppTypography.caption2Regular.fontFamily, isNull);
    });

    test('테마가 Pretendard를 공급한다', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Pretendard');
      }
    });
  });

  group('색은 토큰에 포함하지 않는다', () {
    test('스타일에 color가 없어 화면에서 지정한다', () {
      expect(AppTypography.title1Bold.color, isNull);
      expect(AppTypography.body1NormalRegular.color, isNull);
    });

    test('copyWith로 색을 얹어 쓴다', () {
      final styled = AppTypography.title3Bold.copyWith(
        color: AppColors.labelNormal,
      );
      expect(styled.color, AppColors.labelNormal);
      expect(styled.fontSize, 24); // 나머지 속성은 유지된다
      expect(styled.fontWeight, FontWeight.w700);
    });
  });
}
