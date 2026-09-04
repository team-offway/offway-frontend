import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../../core/widgets/place_thumbnail.dart';
import 'dotted_line.dart';

/// 하루치 코스의 장소 목록.
///
/// 번호를 점선으로 잇고, 장소 사이에는 이동 거리를 칩으로 얹는다.
/// 코스 확정 화면과 공유받은 코스 화면이 함께 쓴다.
class CoursePlaceList extends StatelessWidget {
  const CoursePlaceList({
    super.key,
    required this.places,
    required this.regionName,
    this.onTapPlace,
    this.showDistance = false,
  });

  final List<Map<String, dynamic>> places;
  final String regionName;

  /// 누를 수 있는 목록인지 — 공유받은 화면은 보기 전용이라 넘기지 않는다
  final void Function(Map<String, dynamic> place)? onTapPlace;

  /// 장소 사이에 이동 거리를 얹을지. 시안은 **내 코스에만** 둔다 —
  /// 추천 코스는 아직 어떻게 갈지 정해지지 않았다
  final bool showDistance;

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
            onTap: onTapPlace,
            showDistance: showDistance,
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
    this.onTap,
    this.showDistance = false,
  });

  final int index;
  final Map<String, dynamic> place;
  final String regionName;
  final bool isLast;
  final void Function(Map<String, dynamic> place)? onTap;
  final bool showDistance;

  @override
  Widget build(BuildContext context) {
    final imageUrl = place['imageUrl'] as String?;
    final isFirst = index == 1;
    // 숙박은 눈에 띄게 다른 색을 쓴다 — 하루의 마무리라 위치를 빨리 찾게
    final isStay = place['kind'] == 'STAY';
    // 대중교통 코스의 첫·끝 칸 — 역·터미널이다(core #431).
    //
    // 장소 풀에서 온 칸이 아니라 **상세도 사진도 없다.** 다른 칸과 같은
    // 자리를 쓰되(코스의 1번이자 마지막 번호다) 없는 것을 있는 척하지 않는다
    final isTransitPoint =
        place['kind'] == 'ARRIVAL' || place['kind'] == 'DEPARTURE';
    final meters = place['distanceFromPrevMeters'] as int?;

    final row = IntrinsicHeight(
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
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isStay
                              ? AppAccentColors.backgroundPink
                              : AppColors.primaryNormal,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$index',
                          style: AppTypography.label1NormalBold.copyWith(
                            color: AppColors.staticWhite,
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
                            (place['name'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body1NormalBold.copyWith(
                              color: AppColors.labelNormal,
                            ),
                          ),
                          if (place['catchphrase'] case final String phrase
                              when phrase.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            // 시안: '추천'만 파랗고 뒤 설명은 본문색
                            Text.rich(
                              TextSpan(
                                style: AppTypography.label1ReadingMedium
                                    .copyWith(color: AppColors.labelNeutral),
                                children: [
                                  TextSpan(
                                    text: '추천 ',
                                    style: TextStyle(
                                      color: AppColors.primaryStrong,
                                    ),
                                  ),
                                  TextSpan(text: phrase),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          _buildMeta(),
                        ],
                      ),
                    ),
                  ),
                  // 역·터미널은 사진이 없다. 빈 회색 자리를 남기면 '못 불러온
                  // 사진'으로 읽혀, 아예 접고 글이 그 폭을 쓴다
                  if (!isTransitPoint) ...[
                    const SizedBox(width: 16),
                    PlaceThumbnail(imageUrl: imageUrl),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        // 앞 장소에서 여기까지의 거리 — 첫 장소에는 없다
        if (showDistance && index != 1 && meters != null)
          _buildDistanceChip(meters),
        // 역·터미널은 열 상세가 없다 — 누르면 '상세 정보가 아직 없어요'가
        // 뜨는데, 데이터가 빠진 것이 아니라 원래 없는 칸이라 틀린 안내다
        if (onTap case final handler? when !isTransitPoint)
          GestureDetector(
            onTap: () => handler(place),
            behavior: HitTestBehavior.opaque,
            child: row,
          )
        else
          row,
      ],
    );
  }

  /// 카테고리와, 여행 당일 주의할 운영 정보
  Widget _buildMeta() {
    final category = (place['category'] as String?) ?? '';
    // 서버가 줄 때만 나온다 — 없으면 카테고리만 보인다
    final warn = switch (place) {
      {'closedToday': true} => '휴무일',
      {'checkHours': true} => '운영시간 확인',
      _ => null,
    };
    return Row(
      children: [
        Flexible(
          child: Text(
            category.isEmpty ? regionName : category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label2Regular.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ),
        if (warn != null) ...[
          const SizedBox(width: 8),
          Text(
            warn,
            style: AppTypography.label2Regular.copyWith(
              color: AppColors.statusNegative,
            ),
          ),
        ],
      ],
    );
  }

  /// 점선 위에 흰 배경으로 얹히는 거리 칩
  Widget _buildDistanceChip(int meters) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // 점선(x=11.4)을 가운데로 지나가게 두되 칩은 그 폭에 갇히지 않는다
          Transform.translate(
            offset: const Offset(-12, 0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundNormal,
                  border: Border.all(color: AppColors.lineNormalNeutral),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(meters / 1000).toStringAsFixed(1)}km',
                  style: AppTypography.caption1Regular.copyWith(
                    color: AppColors.labelAlternative,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
