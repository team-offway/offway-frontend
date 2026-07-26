import 'package:flutter/material.dart';

// TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
const _labelNormal = Color(0xFF171719);
const _metaGray = Color(0xFF999999);
const _stayAccent = Color(0xFFB55B45);
const _benefitBg = Color(0xFFF6E3D5);
const _benefitText = Color(0xFFB55B45);
const _timeline = Color(0xFFE5E8EB);

/// 하루치 장소를 번호·연결선과 함께 세로로 늘어놓는 목록.
/// 코스 추천 결과·저장한 코스 화면이 공유한다.
class CoursePlaceList extends StatelessWidget {
  const CoursePlaceList({
    super.key,
    required this.places,
    required this.regionName,
  });

  final List<Map<String, dynamic>> places;
  final String regionName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < places.length; i++)
          _PlaceRow(
            index: i + 1,
            place: places[i],
            regionName: regionName,
            isLast: i == places.length - 1,
          ),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.index,
    required this.place,
    required this.regionName,
    required this.isLast,
  });

  final int index;
  final Map<String, dynamic> place;
  final String regionName;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isStay = place['category'] == '숙박';
    final circleColor = isStay ? _stayAccent : _labelNormal;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: _timeline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place['name'] as String,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _labelNormal,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${place['category']} · $regionName',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _metaGray,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (isStay) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _benefitBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '숙박비 30% 지원',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _benefitText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
