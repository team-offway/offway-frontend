import 'package:flutter/painting.dart';

/// 디자인 시스템 · Atomic 색상 팔레트 (원시 값).
///
/// Figma DS의 `Atomic/*` 변수를 그대로 옮긴 것으로, **화면에서 직접 쓰지 않는다**.
/// 화면은 용도가 드러나는 [AppColors](color_semantic.dart)를 쓰고,
/// Semantic 토큰이 여기의 값을 가리킨다.
///
/// 숫자는 명도 단계(높을수록 밝음)이며 Figma 이름과 1:1 대응한다.
/// 예: `Atomic/Cool Neutral/10` → [coolNeutral10]
abstract final class AppPalette {
  // ── Common ─────────────────────────────────────────────────────────
  static const common0 = Color(0xFF000000);
  static const common100 = Color(0xFFFFFFFF);

  // ── Neutral (순수 회색) ──────────────────────────────────────────────
  static const neutral5 = Color(0xFF0F0F0F);
  static const neutral10 = Color(0xFF171717);
  static const neutral15 = Color(0xFF1C1C1C);
  static const neutral20 = Color(0xFF2A2A2A);
  static const neutral22 = Color(0xFF303030);
  static const neutral30 = Color(0xFF474747);
  static const neutral40 = Color(0xFF5C5C5C);
  static const neutral50 = Color(0xFF737373);
  static const neutral60 = Color(0xFF8A8A8A);
  static const neutral70 = Color(0xFF9B9B9B);
  static const neutral80 = Color(0xFFB0B0B0);
  static const neutral90 = Color(0xFFC4C4C4);
  static const neutral95 = Color(0xFFDCDCDC);
  static const neutral99 = Color(0xFFF7F7F7);

  // ── Cool Neutral (푸른기 도는 회색) ───────────────────────────────────
  // 서비스 기본 회색 계열. Label·Line·Fill 토큰이 대부분 여기서 나온다.
  static const coolNeutral5 = Color(0xFF0F0F10);
  static const coolNeutral7 = Color(0xFF141415);
  static const coolNeutral10 = Color(0xFF171719);
  static const coolNeutral15 = Color(0xFF1B1C1E);
  static const coolNeutral17 = Color(0xFF212225);
  static const coolNeutral20 = Color(0xFF292A2D);
  static const coolNeutral22 = Color(0xFF2E2F33);
  static const coolNeutral23 = Color(0xFF333438);
  static const coolNeutral25 = Color(0xFF37383C);
  static const coolNeutral30 = Color(0xFF46474C);
  static const coolNeutral40 = Color(0xFF5A5C63);
  static const coolNeutral50 = Color(0xFF70737C);
  static const coolNeutral60 = Color(0xFF878A93);
  static const coolNeutral70 = Color(0xFF989BA2);
  static const coolNeutral80 = Color(0xFFAEB0B6);
  static const coolNeutral90 = Color(0xFFC2C4C8);
  static const coolNeutral95 = Color(0xFFDBDCDF);
  static const coolNeutral96 = Color(0xFFE1E2E4);
  static const coolNeutral97 = Color(0xFFEAEBEC);
  static const coolNeutral98 = Color(0xFFF4F4F5);
  static const coolNeutral99 = Color(0xFFF7F7F8);

  // ── Blue (Primary 계열) ──────────────────────────────────────────────
  static const blue10 = Color(0xFF001536);
  static const blue20 = Color(0xFF002966);
  static const blue30 = Color(0xFF003E9C);
  static const blue40 = Color(0xFF0054D1);
  static const blue45 = Color(0xFF005EEB);
  static const blue50 = Color(0xFF0066FF);
  static const blue55 = Color(0xFF1A75FF);
  static const blue60 = Color(0xFF3385FF);
  static const blue65 = Color(0xFF4F95FF);
  static const blue70 = Color(0xFF69A5FF);
  static const blue80 = Color(0xFF9EC5FF);
  static const blue90 = Color(0xFFC9DEFE);
  static const blue95 = Color(0xFFEAF2FE);
  static const blue99 = Color(0xFFF7FBFF);

  // ── Red ────────────────────────────────────────────────────────────
  static const red10 = Color(0xFF3B0101);
  static const red20 = Color(0xFF730303);
  static const red30 = Color(0xFFB00C0C);
  static const red40 = Color(0xFFE52222);
  static const red50 = Color(0xFFFF4242);
  static const red60 = Color(0xFFFF6363);
  static const red70 = Color(0xFFFF8C8C);
  static const red80 = Color(0xFFFFB5B5);
  static const red90 = Color(0xFFFED5D5);
  static const red95 = Color(0xFFFEECEC);
  static const red99 = Color(0xFFFFFAFA);

  // ── Green ──────────────────────────────────────────────────────────
  static const green10 = Color(0xFF00240C);
  static const green20 = Color(0xFF004517);
  static const green30 = Color(0xFF006E25);
  static const green40 = Color(0xFF009632);
  static const green50 = Color(0xFF00BF40);
  static const green60 = Color(0xFF1ED45A);
  static const green70 = Color(0xFF49E57D);
  static const green80 = Color(0xFF7DF5A5);
  static const green90 = Color(0xFFACFCC7);
  static const green95 = Color(0xFFD9FFE6);
  static const green99 = Color(0xFFF2FFF6);

  // ── Orange ─────────────────────────────────────────────────────────
  static const orange10 = Color(0xFF361E00);
  static const orange20 = Color(0xFF663A00);
  static const orange30 = Color(0xFF9C5800);
  static const orange39 = Color(0xFFD17600);
  static const orange40 = Color(0xFFD47800);
  static const orange50 = Color(0xFFFF9200);
  static const orange60 = Color(0xFFFFA938);
  static const orange70 = Color(0xFFFFC06E);
  static const orange80 = Color(0xFFFFD49C);
  static const orange90 = Color(0xFFFEE6C6);
  static const orange95 = Color(0xFFFEF4E6);
  static const orange99 = Color(0xFFFFFCF7);

  // ── Red Orange ─────────────────────────────────────────────────────
  static const redOrange10 = Color(0xFF290F00);
  static const redOrange20 = Color(0xFF592100);
  static const redOrange30 = Color(0xFF913500);
  static const redOrange40 = Color(0xFFC94A00);
  static const redOrange48 = Color(0xFFF55A00);
  static const redOrange50 = Color(0xFFFF5E00);
  static const redOrange60 = Color(0xFFFF7B2E);
  static const redOrange70 = Color(0xFFFF9B61);
  static const redOrange80 = Color(0xFFFFBD96);
  static const redOrange90 = Color(0xFFFED9C4);
  static const redOrange95 = Color(0xFFFEEEE5);
  static const redOrange99 = Color(0xFFFFFAF7);

  // ── Lime ───────────────────────────────────────────────────────────
  static const lime10 = Color(0xFF112900);
  static const lime20 = Color(0xFF225200);
  static const lime30 = Color(0xFF347D00);
  static const lime37 = Color(0xFF429E00);
  static const lime40 = Color(0xFF48AD00);
  static const lime50 = Color(0xFF58CF04);
  static const lime60 = Color(0xFF6BE016);
  static const lime70 = Color(0xFF88F03E);
  static const lime80 = Color(0xFFAEF779);
  static const lime90 = Color(0xFFCCFCA9);
  static const lime95 = Color(0xFFE6FFD4);
  static const lime99 = Color(0xFFF8FFF2);

  // ── Cyan ───────────────────────────────────────────────────────────
  static const cyan10 = Color(0xFF00252B);
  static const cyan20 = Color(0xFF004854);
  static const cyan30 = Color(0xFF006F82);
  static const cyan40 = Color(0xFF0098B2);
  static const cyan50 = Color(0xFF00BDDE);
  static const cyan60 = Color(0xFF28D0ED);
  static const cyan70 = Color(0xFF57DFF7);
  static const cyan80 = Color(0xFF8AEDFF);
  static const cyan90 = Color(0xFFB5F4FF);
  static const cyan95 = Color(0xFFDEFAFF);
  static const cyan99 = Color(0xFFF7FEFF);

  // ── Light Blue ─────────────────────────────────────────────────────
  static const lightBlue10 = Color(0xFF002130);
  static const lightBlue20 = Color(0xFF004261);
  static const lightBlue30 = Color(0xFF006796);
  static const lightBlue40 = Color(0xFF008DCF);
  static const lightBlue50 = Color(0xFF00AEFF);
  static const lightBlue60 = Color(0xFF3DC2FF);
  static const lightBlue70 = Color(0xFF70D2FF);
  static const lightBlue80 = Color(0xFFA1E1FF);
  static const lightBlue90 = Color(0xFFC4ECFE);
  static const lightBlue95 = Color(0xFFE5F6FE);
  static const lightBlue99 = Color(0xFFF7FDFF);

  // ── Violet ─────────────────────────────────────────────────────────
  static const violet10 = Color(0xFF11024D);
  static const violet20 = Color(0xFF23098F);
  static const violet30 = Color(0xFF3A16C9);
  static const violet40 = Color(0xFF4F29E5);
  static const violet45 = Color(0xFF5B37ED);
  static const violet50 = Color(0xFF6541F2);
  static const violet60 = Color(0xFF7D5EF7);
  static const violet70 = Color(0xFF9E86FC);
  static const violet80 = Color(0xFFC0B0FF);
  static const violet90 = Color(0xFFDBD3FE);
  static const violet95 = Color(0xFFF0ECFE);
  static const violet99 = Color(0xFFFBFAFF);

  // ── Purple ─────────────────────────────────────────────────────────
  static const purple10 = Color(0xFF290247);
  static const purple20 = Color(0xFF580A7D);
  static const purple30 = Color(0xFF861CB8);
  static const purple40 = Color(0xFFAD36E3);
  static const purple50 = Color(0xFFCB59FF);
  static const purple60 = Color(0xFFD478FF);
  static const purple70 = Color(0xFFDE96FF);
  static const purple80 = Color(0xFFE9BAFF);
  static const purple90 = Color(0xFFF2D6FF);
  static const purple95 = Color(0xFFF9EDFF);
  static const purple99 = Color(0xFFFEFBFF);

  // ── Pink ───────────────────────────────────────────────────────────
  static const pink10 = Color(0xFF3D0133);
  static const pink20 = Color(0xFF730560);
  static const pink30 = Color(0xFFA81690);
  static const pink40 = Color(0xFFD331B8);
  static const pink46 = Color(0xFFE846CD);
  static const pink50 = Color(0xFFF553DA);
  static const pink60 = Color(0xFFFA73E3);
  static const pink70 = Color(0xFFFF94ED);
  static const pink80 = Color(0xFFFFB8F3);
  static const pink90 = Color(0xFFFED3F7);
  static const pink95 = Color(0xFFFEECFB);
  static const pink99 = Color(0xFFFFFAFE);
}

/// 디자인 시스템 · 투명도 단계 (0~100).
///
/// Semantic 토큰이 Atomic 색에 이 값을 곱해 만들어진다.
/// 예: `Fill/Normal` = Cool Neutral/50 + [o8]
abstract final class AppOpacity {
  static const o5 = 0.05;
  static const o8 = 0.08;
  static const o12 = 0.12;
  static const o16 = 0.16;
  static const o22 = 0.22;
  static const o28 = 0.28;
  static const o35 = 0.35;
  static const o43 = 0.43;
  static const o52 = 0.52;
  static const o61 = 0.61;
  static const o74 = 0.74;
  static const o88 = 0.88;
  static const o97 = 0.97;
  static const o100 = 1.0;
}
