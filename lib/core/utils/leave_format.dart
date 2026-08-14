/// 연차 일수 표기: 정수는 '15', 반차가 섞이면 '15.5', 반반차는 '0.25'.
///
/// 서버가 연차를 double로 내려주므로(0.25 단위) 그대로 찍으면
/// "15.0일"처럼 보인다. 사람이 읽는 자리에서는 항상 이걸 거친다.
///
/// 자릿수를 고정하지 않는다 — 0.25를 한 자리로 자르면 '0.3'이 되어
/// 시안의 '0.25일' 칩과 어긋난다.
String formatLeaveDays(num days) {
  if (days == days.roundToDouble()) return days.toStringAsFixed(0);
  // 부동소수 오차로 '0.30000000000000004' 같은 꼬리가 붙지 않게 다듬는다
  return days
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
