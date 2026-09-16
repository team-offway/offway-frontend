import 'package:flutter/widgets.dart';

/// 화면 맨 아래 **홈 인디케이터가 차지하는 높이**.
///
/// 스크롤이 끝인 화면은 `SafeArea(bottom: false)` 로 두어 내용이 인디케이터
/// **아래로 흘러가게** 하고, 목록 끝 여백에만 이 값을 더한다. 그래야 마지막
/// 항목이 인디케이터에 가리지 않으면서도 배경이 끊기지 않는다.
///
/// `SafeArea` 를 그냥 두면 iOS 가 그 자리를 잘라내고 Scaffold 배경만 남겨,
/// 화면 아래에 **흰 띠가 하나 더 있는 것처럼** 보인다(이슈 #300).
///
/// ```dart
/// body: SafeArea(
///   bottom: false,
///   child: ListView(padding: EdgeInsets.only(bottom: 32 + context.bottomInset)),
/// )
/// ```
///
/// **하단 탭이 있는 화면(홈·내 코스·마이)은 쓰지 않는다** — 그쪽은 탭 바
/// 높이까지 합친 값이 필요해 `bottom: 120` 을 그대로 둔다.
///
/// 기기마다 다르다(노치 없는 기기는 0). 상수로 박으면 그 기기에서 여백이 뜬다.
extension BottomInset on BuildContext {
  double get bottomInset => MediaQuery.paddingOf(this).bottom;
}
