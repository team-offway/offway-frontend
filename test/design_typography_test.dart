import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/tokens/tokens.dart';

/// Figma DS의 텍스트 스타일과 코드가 어긋나지 않도록 고정한다.
/// 토큰을 고칠 일이 생기면 Figma를 먼저 확인하고 여기 기대값도 함께 바꾼다.
void main() {
  group('크기 스케일은 Figma와 일치한다', () {
    test('Display · Title', () {
      expect(AppTypography.display1Bold.fontSize, 56);
      expect(AppTypography.display2Bold.fontSize, 40);
      expect(AppTypography.display3Bold.fontSize, 36);
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
    test('Display·Title의 Bold는 700, Heading 이하는 600이다', () {
      // DS가 큰 스케일만 진짜 Bold를 쓰고 나머지는 SemiBold를 쓴다
      expect(AppTypography.display1Bold.fontWeight, FontWeight.w700);
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
      expect(AppTypography.display1Bold.height, closeTo(1.286, 0.0005));
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
      // Figma가 px 값으로 준다. Display는 음수, Caption은 양수.
      expect(AppTypography.display1Bold.letterSpacing, -3.19);
      expect(AppTypography.headline2Bold.letterSpacing, 0);
      expect(AppTypography.caption2Bold.letterSpacing, 3.11);
      expect(
        AppTypography.display1Bold.letterSpacing!,
        lessThan(AppTypography.caption2Bold.letterSpacing!),
      );
    });
  });

  group('fontFamily는 비어 있다', () {
    test('앱에 Pretendard가 없어 시스템 폰트로 렌더된다', () {
      // 폰트를 번들하면 ThemeData(fontFamily:)로 한 번에 적용한다.
      // 여기에 이름만 박아두면 조용히 기본 폰트로 대체돼 혼란스럽다.
      expect(AppTypography.display1Bold.fontFamily, isNull);
      expect(AppTypography.body1NormalRegular.fontFamily, isNull);
      expect(AppTypography.caption2Regular.fontFamily, isNull);
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
