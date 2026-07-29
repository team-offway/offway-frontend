import 'package:flutter/painting.dart';

import 'color_atomic.dart';

/// 디자인 시스템 · Semantic 색상 토큰 (용도별 이름).
///
/// **화면에서는 이 클래스만 쓴다.** 값은 [AppPalette]의 Atomic 색을 가리키며,
/// 반투명 토큰은 Atomic 색 + [AppOpacity] 단계로 만들어진다.
/// 팔레트가 바뀌어도 화면 코드는 그대로 두고 여기 매핑만 고치면 된다.
///
/// Figma DS의 `Semantic/*` 변수와 1:1 대응한다.
/// 예: `Semantic/Label/Normal` → [labelNormal]
///
/// 현재는 라이트 테마 기준이다. 다크 테마 도입 시 같은 이름의 다크 세트를 만들어
/// ThemeExtension으로 전환한다.
abstract final class AppColors {
  // ── Label · 글자색 ──────────────────────────────────────────────────
  /// 본문·제목 기본 글자색
  static const labelNormal = AppPalette.coolNeutral10;

  /// 가장 진한 강조 글자색
  static const labelStrong = AppPalette.common0;

  /// 본문보다 한 단계 약한 글자색 (Cool Neutral/22 · 88%)
  static const labelNeutral = Color(0xE02E2F33);

  /// 보조 설명용 (Cool Neutral/25 · 61%)
  static const labelAlternative = Color(0x9C37383C);

  /// 더 약한 보조 텍스트 (Cool Neutral/25 · 28%)
  static const labelAssistive = Color(0x4737383C);

  /// 비활성 상태 글자색 (Cool Neutral/25 · 16%)
  static const labelDisable = Color(0x2937383C);

  // ── Primary · 브랜드 ────────────────────────────────────────────────
  // 2026-07-30 DS 개편: 진파랑(Blue) → 하늘색(Light Blue) 계열로 변경
  static const primaryNormal = AppPalette.lightBlue60;
  static const primaryStrong = AppPalette.lightBlue50;
  static const primaryHeavy = AppPalette.lightBlue40;

  // ── Background · 화면 배경 ──────────────────────────────────────────
  static const backgroundNormal = AppPalette.common100;
  static const backgroundNormalAlternative = AppPalette.coolNeutral99;

  /// 카드·시트처럼 떠 있는 면
  static const backgroundElevated = AppPalette.common100;
  static const backgroundElevatedAlternative = AppPalette.coolNeutral99;

  // TODO(DS): Figma가 이 두 값을 불투명 #FFFFFF로 내려준다. 이름상 반투명이어야
  // 하는데 변수 alpha가 넘어오지 않은 것으로 보여 디자이너 확인이 필요하다.
  // 확인 전까지는 Figma가 준 값 그대로 둔다.
  static const backgroundTransparent = AppPalette.common100;
  static const backgroundTransparentAlternative = AppPalette.common100;

  // ── Line · 구분선 ───────────────────────────────────────────────────
  /// 반투명 구분선 — 배경색이 비쳐야 하는 곳
  static const lineNormal = Color(0x3870737C); // Cool Neutral/50 · 22%
  static const lineNormalNeutral = Color(0x5270737C); // 32%
  static const lineNormalAlternative = Color(0x1470737C); // 8%
  static const lineNormalStrong = Color(0x8570737C); // 52%

  /// 불투명 구분선 — 배경 위에 얹어 계산된 최종색
  static const lineSolidNormal = AppPalette.coolNeutral96;
  static const lineSolidNeutral = AppPalette.coolNeutral97;
  static const lineSolidAlternative = AppPalette.coolNeutral98;

  // ── Fill · 면 채우기 (버튼 배경 등) ──────────────────────────────────
  static const fillNormal = Color(0x1470737C); // Cool Neutral/50 · 8%
  static const fillStrong = Color(0x2970737C); // 16%
  static const fillAlternative = Color(0x0D70737C); // 5%

  // ── Interaction · 상호작용 상태 ─────────────────────────────────────
  static const interactionInactive = AppPalette.coolNeutral70;
  static const interactionDisable = AppPalette.coolNeutral98;

  // ── Status · 상태 표시 ──────────────────────────────────────────────
  static const statusPositive = AppPalette.green50;
  static const statusCautionary = AppPalette.orange50;
  static const statusNegative = AppPalette.red50;

  // ── Inverse · 반전 (어두운 면 위) ───────────────────────────────────
  static const inversePrimary = AppPalette.blue60;
  static const inverseBackground = AppPalette.coolNeutral15;
  static const inverseLabel = AppPalette.coolNeutral99;

  // ── Static · 테마와 무관하게 고정 ───────────────────────────────────
  static const staticWhite = AppPalette.common100;
  static const staticBlack = AppPalette.common0;

  // ── Material · 오버레이 ─────────────────────────────────────────────
  /// 모달 뒤를 덮는 딤 (Cool Neutral/10 · 52%)
  static const materialDimmer = Color(0x85171719);

  // ── Initial · 테마 전환 전 초기값 ───────────────────────────────────
  /// DS 내부용. 화면에서는 [staticBlack]·[staticWhite]를 쓴다.
  static const initialBlack = AppPalette.common0;
  static const initialWhite = AppPalette.common100;
}

/// 디자인 시스템 · 강조 색상 (배지·태그 등 구분이 필요한 곳).
///
/// `Background`는 면을 채울 때, `Foreground`는 그 위 글자·아이콘에 쓴다.
/// Figma DS의 `Semantic/Accent/*`와 대응한다.
abstract final class AppAccentColors {
  // 면 채우기용
  static const backgroundRedOrange = AppPalette.redOrange50;
  static const backgroundLime = AppPalette.lime50;
  static const backgroundCyan = AppPalette.cyan50;
  static const backgroundLightBlue = AppPalette.lightBlue50;
  static const backgroundViolet = AppPalette.violet50;
  static const backgroundPurple = AppPalette.purple50;
  static const backgroundPink = AppPalette.pink50;

  // 글자·아이콘용 (배경 대비 확보를 위해 한 단계 진한 값)
  static const foregroundRed = AppPalette.red40;
  static const foregroundRedOrange = AppPalette.redOrange48;
  static const foregroundOrange = AppPalette.orange39;
  static const foregroundLime = AppPalette.lime37;
  static const foregroundGreen = AppPalette.green40;
  static const foregroundCyan = AppPalette.cyan40;
  static const foregroundLightBlue = AppPalette.lightBlue40;
  static const foregroundBlue = AppPalette.blue45;
  static const foregroundViolet = AppPalette.violet45;
  static const foregroundPurple = AppPalette.purple40;
  static const foregroundPink = AppPalette.pink46;
}
