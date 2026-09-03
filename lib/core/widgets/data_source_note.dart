import 'package:flutter/material.dart';

import '../network/api_envelope.dart';
import '../theme/tokens/tokens.dart';

/// 이 화면이 빌려 쓴 공공데이터의 출처 한 줄 (core #417).
///
/// 공모전 규정이 요구한다.
///
/// > `[O]` 출처: ⓒ한국관광공사 / `[X]` TourAPI (API 서비스명만 단독 표기 지양).
/// > 기관명 표기 시 공식 CI/BI 로고 이미지는 무단 사용할 수 없으며,
/// > **텍스트 형태의 출처 표기만 허용**
///
/// **기관명은 서버가 준다.** 앱이 매핑 표를 들면 출처가 하나 늘었을 때 표에
/// 없는 값을 그리지 못해, 앱 배포 전까지 그 화면의 표기가 빈다 — 그 공백이
/// 그대로 규정 위반이다. 앱은 `출처: ⓒ` 접두와 여러 기관을 잇는 방식만 정한다.
///
/// **응답 단위다.** 카드마다 붙이지 않는다. 표기 의무는 "이 화면에 어느 기관
/// 데이터가 쓰였나"이고, 항목 단위는 오히려 나쁘다 — 인허가 식당 카드에
/// 사진만 공사 것인데 그 카드에 한국관광공사가 붙으면 오인을 키운다.
class DataSourceNote extends StatelessWidget {
  const DataSourceNote({
    super.key,
    required this.sources,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 24),
  });

  final List<DataSource> sources;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // 서버가 실제로 쓴 기관만 내려준다 — 없으면 표기할 것도 없다.
    // 고정 문구로 채우면 안 쓴 출처를 표기하게 되고, 그것도 잘못된 표기다
    if (sources.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Text(
        label,
        style: AppTypography.caption1Regular.copyWith(
          color: AppColors.labelAlternative,
        ),
      ),
    );
  }

  /// `출처: ©한국관광공사 · ©지방행정인허가데이터개방`
  ///
  /// **규정 문서의 ⓒ(U+24D2)가 아니라 ©(U+00A9)를 쓴다.** 본문 서체
  /// (Pretendard)에 원문자 소문자 글리프가 없어 두부(□)로 깨진다 — 규정이
  /// 요구하는 표기가 화면에서 안 보이면 표기가 없는 것과 같다. ©는 저작권
  /// 표시의 표준 기호이고 같은 뜻이다.
  ///
  /// 기관마다 붙인다 — 한 번만 붙이면 뒤쪽 기관이 앞 기관의 부속처럼 읽힌다.
  /// 순서는 서버가 정한 대로 둔다(가장 무겁게 표기해야 하는 한국관광공사가
  /// 늘 앞이다)
  String get label => '출처: ${sources.map((s) => '©${s.label}').join(' · ')}';
}
