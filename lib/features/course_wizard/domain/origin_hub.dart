/// 사용자가 고른 출발지 — 역·터미널이거나 주소로 찍은 한 지점.
///
/// 앱은 좌표를 갖지 않는다. 위치를 수집하지 않으려고 만든 기능이라
/// (core #591) 고른 곳을 [code] 로만 들고 다니고, 좌표 해석은 서버가 한다.
class OriginHub {
  const OriginHub({
    required this.code,
    required this.name,
    required this.area,
    required this.kind,
  });

  /// `TRAIN:NAT610226` · `BUS:NAEK222` · `GEO:37.42,127.1265`
  final String code;

  /// 표시 이름 (`정선역`)
  final String name;

  /// 시·도 (`강원`)
  final String area;

  /// `TRAIN_STATION` · `BUS_TERMINAL` · 주소·장소
  final String kind;

  factory OriginHub.fromJson(Map<String, dynamic> json) => OriginHub(
    code: json['code'] as String,
    name: json['name'] as String,
    // 주소·장소는 시도가 비어 올 수 있다
    area: (json['area'] as String?) ?? '',
    kind: (json['kind'] as String?) ?? '',
  );

  @override
  bool operator ==(Object other) => other is OriginHub && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
