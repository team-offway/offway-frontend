import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 사진첩에 저장하는 코스 일정 이미지 (전체 또는 하루치).
///
/// 상세 화면의 타임라인을 따르되 캡처가 네트워크를 기다리지 않도록
/// 글자만으로 구성한다. [day]가 null이면 전체 일정을 담는다.
class CourseShareImage extends StatelessWidget {
  const CourseShareImage({
    super.key,
    required this.saved,
    required this.course,
    this.day,
  });

  final Map<String, dynamic> saved;
  final Map<String, dynamic> course;
  final int? day;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final allDays = (course['days'] as List).cast<Map<String, dynamic>>();
    final days = day == null
        ? allDays
        : allDays.where((d) => d['day'] == day).toList();
    final regionName = saved['regionName'] as String? ?? '';
    final start = DateTime.tryParse(saved['startDate'] as String? ?? '');
    final end = DateTime.tryParse(saved['endDate'] as String? ?? '');

    return Container(
      color: AppColors.backgroundNormal,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: AppTypography.title3Bold.copyWith(
                color: AppColors.labelNormal,
              ),
              children: [
                TextSpan(text: '$regionName 여행, '),
                TextSpan(
                  text: ((saved['durationLabel'] as String?) ?? '').replaceAll(
                    ' ',
                    '',
                  ),
                  style: AppTypography.title3Bold.copyWith(
                    color: AppColors.primaryNormal,
                  ),
                ),
              ],
            ),
          ),
          if (start != null && end != null) ...[
            const SizedBox(height: 4),
            Text(
              '${start.year}.${start.month}.${start.day} - ${end.month}.${end.day}',
              style: AppTypography.body2NormalMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ],
          for (final d in days) ...[
            const SizedBox(height: 20),
            _buildDayHeader(d),
            const SizedBox(height: 4),
            _buildTimeline(d),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: Text(
              'OffWay',
              style: AppTypography.label1NormalBold.copyWith(
                color: AppColors.primaryNormal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(Map<String, dynamic> d) {
    final date = DateTime.tryParse(d['date'] as String? ?? '');
    return Row(
      children: [
        Text(
          '여행 ${d['day']}일차',
          style: AppTypography.headline2Bold.copyWith(
            color: AppColors.labelNeutral,
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: 8),
          Text(
            '${date.month}.${date.day} ${_weekdays[date.weekday - 1]}',
            style: AppTypography.headline2Bold.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeline(Map<String, dynamic> d) {
    final places = (d['places'] as List).cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < places.length; i++) _buildRow(i + 1, places[i]),
      ],
    );
  }

  Widget _buildRow(int index, Map<String, dynamic> place) {
    final catchphrase = place['catchphrase'] as String?;
    final isStay = place['kind'] == 'STAY';
    final meters = place['distanceFromPrevMeters'] as int?;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isStay
                  ? AppAccentColors.backgroundPink
                  : AppColors.primaryNormal,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: AppTypography.label1NormalBold.copyWith(
                color: AppColors.staticWhite,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        place['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body1NormalBold.copyWith(
                          color: AppColors.labelNormal,
                        ),
                      ),
                    ),
                    if (index > 1 && meters != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${(meters / 1000).toStringAsFixed(1)}km',
                        style: AppTypography.caption1Regular.copyWith(
                          color: AppColors.labelAlternative,
                        ),
                      ),
                    ],
                  ],
                ),
                if (catchphrase != null)
                  Text(
                    catchphrase,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label1ReadingMedium.copyWith(
                      color: AppColors.labelNeutral,
                    ),
                  ),
                Text(
                  (place['category'] as String?) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label2Regular.copyWith(
                    color: AppColors.labelAlternative,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
