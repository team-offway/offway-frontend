import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../../core/widgets/place_thumbnail.dart';
import 'dotted_line.dart';

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
    final imageUrl = place['imageUrl'] as String?;
    final isFirst = index == 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 순번과 이어지는 점선 — 선은 행 경계를 넘어 다음 번호까지 통으로
          // 이어지고, 번호가 흰 배경으로 선을 가려 위아래 같은 틈이 생긴다
          SizedBox(
            width: 24,
            child: Stack(
              children: [
                if (!(isFirst && isLast))
                  Positioned(
                    left: 11.4,
                    // 첫 번호 위·마지막 번호 아래로는 선이 나가지 않는다
                    top: isFirst ? 27 : 0,
                    bottom: isLast ? null : 0,
                    height: isLast ? 27 : null,
                    child: const DottedVerticalLine(),
                  ),
                Column(
                  children: [
                    const SizedBox(height: 9),
                    Container(
                      width: 24,
                      color: AppColors.backgroundNormal,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(
                        height: 24,
                        child: Center(
                          child: Text(
                            '$index',
                            style: AppTypography.body1NormalBold.copyWith(
                              color: AppColors.primaryNormal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body1NormalBold.copyWith(
                              color: AppColors.labelNormal,
                            ),
                          ),
                          // 혜택이 있으면 왜 이 곳을 추천하는지 먼저 알린다.
                          // TODO(server): 장소별 추천 문구가 생기면 혜택 대신 그걸 쓴다
                          if (place['category'] == '숙박') ...[
                            const SizedBox(height: 4),
                            Text(
                              '추천 숙박비 30% 지원',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label1ReadingMedium.copyWith(
                                color: AppColors.primaryNormal,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${place['category']} · $regionName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label2Regular.copyWith(
                              color: AppColors.labelAlternative,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  PlaceThumbnail(
                    imageUrl: imageUrl,
                    mapSearchUrl: place['mapSearchUrl'] as String?,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
