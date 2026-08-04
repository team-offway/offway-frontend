/// 연차 일수 표기: 정수는 '15', 반차가 섞이면 '15.5'.
///
/// 서버가 연차를 double로 내려주므로(반차 0.5 단위) 그대로 찍으면
/// "15.0일"처럼 보인다. 사람이 읽는 자리에서는 항상 이걸 거친다.
String formatLeaveDays(num days) => days == days.roundToDouble()
    ? days.toStringAsFixed(0)
    : days.toStringAsFixed(1);
