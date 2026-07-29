import 'package:flutter/painting.dart';

/// 디자인 시스템 · 타이포그래피 토큰.
///
/// Figma DS의 텍스트 스타일을 [TextStyle]로 옮긴 것으로, 크기·굵기·행간·자간
/// 묶음만 정의한다. 색은 [AppColors](color_semantic.dart)를 따로 지정한다.
///
/// ```dart
/// Text('제목', style: AppTypography.title3Bold.copyWith(
///   color: AppColors.labelNormal,
/// ));
/// ```
///
/// **fontFamily는 의도적으로 비워둔다.** DS는 Pretendard를 쓰지만 앱에 폰트가
/// 번들되어 있지 않아, 지금은 시스템 폰트로 렌더된다. 폰트를 추가하면
/// `ThemeData(fontFamily: ...)` 한 곳만 지정하면 전체에 적용된다.
///
/// 스케일은 크기 순으로 Display(56~36) → Title(32~24) → Heading(22~20)
/// → Headline(18~17) → Body(16~15) → Label(14~13) → Caption(12~11).
/// Body·Label에는 행간이 넓은 `Reading` 변형이 있어 긴 글에 쓴다.
abstract final class AppTypography {
  // ── Display · 가장 큰 표시용 ────────────────────────────────────────
  static const display1Bold = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.286,
    letterSpacing: -3.19,
  );
  static const display1Medium = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w500,
    height: 1.286,
    letterSpacing: -3.19,
  );
  static const display1Regular = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w400,
    height: 1.286,
    letterSpacing: -3.19,
  );

  static const display2Bold = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -2.82,
  );
  static const display2Medium = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -2.82,
  );
  static const display2Regular = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: -2.82,
  );

  static const display3Bold = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.334,
    letterSpacing: -2.7,
  );
  static const display3Medium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w500,
    height: 1.334,
    letterSpacing: -2.7,
  );
  static const display3Regular = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.334,
    letterSpacing: -2.7,
  );

  // ── Title · 화면 제목 ───────────────────────────────────────────────
  static const title1Bold = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.375,
    letterSpacing: -2.53,
  );
  static const title1Medium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w500,
    height: 1.375,
    letterSpacing: -2.53,
  );
  static const title1Regular = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: 1.375,
    letterSpacing: -2.53,
  );

  static const title2Bold = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.358,
    letterSpacing: -2.36,
  );
  static const title2Medium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.358,
    letterSpacing: -2.36,
  );
  static const title2Regular = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.358,
    letterSpacing: -2.36,
  );

  static const title3Bold = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.334,
    letterSpacing: -2.3,
  );
  static const title3Medium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.334,
    letterSpacing: -2.3,
  );
  static const title3Regular = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.334,
    letterSpacing: -2.3,
  );

  // ── Heading · 섹션 제목 ─────────────────────────────────────────────
  // Bold는 700이 아니라 SemiBold(600)다. Title 이하는 모두 600을 쓴다.
  static const heading1Bold = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.364,
    letterSpacing: -1.94,
  );
  static const heading1Medium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.364,
    letterSpacing: -1.94,
  );
  static const heading1Regular = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    height: 1.364,
    letterSpacing: -1.94,
  );

  static const heading2Bold = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -1.2,
  );
  static const heading2Medium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: -1.2,
  );
  static const heading2Regular = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -1.2,
  );

  // ── Headline · 소제목 ───────────────────────────────────────────────
  static const headline1Bold = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.445,
    letterSpacing: -0.02,
  );
  static const headline1Medium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.445,
    letterSpacing: -0.02,
  );
  static const headline1Regular = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.445,
    letterSpacing: -0.02,
  );

  static const headline2Bold = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.412,
    letterSpacing: 0,
  );
  static const headline2Medium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.412,
    letterSpacing: 0,
  );
  static const headline2Regular = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.412,
    letterSpacing: 0,
  );

  // ── Body · 본문 ─────────────────────────────────────────────────────
  // Normal은 일반 본문, Reading은 행간이 넓어 긴 글에 쓴다.
  static const body1NormalBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.57,
  );
  static const body1NormalMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.57,
  );
  static const body1NormalRegular = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.57,
  );

  static const body1ReadingBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.625,
    letterSpacing: 0.57,
  );
  static const body1ReadingMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.625,
    letterSpacing: 0.57,
  );
  static const body1ReadingRegular = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.625,
    letterSpacing: 0.57,
  );

  static const body2NormalBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.467,
    letterSpacing: 0.96,
  );
  static const body2NormalMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.467,
    letterSpacing: 0.96,
  );
  static const body2NormalRegular = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.467,
    letterSpacing: 0.96,
  );

  static const body2ReadingBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.6,
    letterSpacing: 0.96,
  );
  static const body2ReadingMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.6,
    letterSpacing: 0.96,
  );
  static const body2ReadingRegular = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0.96,
  );

  // ── Label · 버튼·탭 등 UI 텍스트 ────────────────────────────────────
  static const label1NormalBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.429,
    letterSpacing: 1.45,
  );
  static const label1NormalMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.429,
    letterSpacing: 1.45,
  );
  static const label1NormalRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.429,
    letterSpacing: 1.45,
  );

  // Reading 변형의 행간은 Bold만 1.5714, 나머지는 1.571 (Figma 값 그대로)
  static const label1ReadingBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5714,
    letterSpacing: 1.45,
  );
  static const label1ReadingMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.571,
    letterSpacing: 1.45,
  );
  static const label1ReadingRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.571,
    letterSpacing: 1.45,
  );

  static const label2Bold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.385,
    letterSpacing: 1.94,
  );
  static const label2Medium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.385,
    letterSpacing: 1.94,
  );
  static const label2Regular = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.385,
    letterSpacing: 1.94,
  );

  // ── Caption · 가장 작은 보조 텍스트 ─────────────────────────────────
  // TODO(DS): Figma의 `Caption 1/Bold`가 weight 400(Regular)으로 정의돼 있다.
  // 다른 Bold는 모두 600 이상이라 DS 쪽 오설정으로 보여 여기서는 600을 쓴다.
  // 디자이너 확인 후 Figma가 맞다면 400으로 되돌린다.
  static const caption1Bold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.334,
    letterSpacing: 2.52,
  );
  static const caption1Medium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.334,
    letterSpacing: 2.52,
  );
  static const caption1Regular = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.334,
    letterSpacing: 2.52,
  );

  static const caption2Bold = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.273,
    letterSpacing: 3.11,
  );
  static const caption2Medium = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.273,
    letterSpacing: 3.11,
  );
  static const caption2Regular = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.273,
    letterSpacing: 3.11,
  );
}
