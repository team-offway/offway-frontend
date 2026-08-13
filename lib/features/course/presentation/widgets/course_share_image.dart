import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../../core/utils/leave_format.dart';
import '../../../../core/widgets/place_thumbnail.dart';

/// 사진첩에 저장하는 코스 일정 이미지.
///
/// 공유 웹페이지와 같은 얼굴을 갖되, 한 장으로 끝나는 이미지라 지도와 Day
/// 탭은 넣지 않는다. [day]가 null이면 전체 일정을 이어 붙인다.
///
/// [savedAt]이 있으면 '내 코스'(날짜·연차 뱃지), 없으면 '추천코스'(안내 문구)로
/// 그린다 — 시안이 그렇게 나뉜다.
class CourseShareImage extends StatelessWidget {
  const CourseShareImage({
    super.key,
    required this.saved,
    required this.course,
    this.day,
    this.consumedLeaveDays,
  });

  /// 내 코스 카드 정보. 추천코스에서 저장할 때는 비어 있을 수 있다
  final Map<String, dynamic> saved;
  final Map<String, dynamic> course;
  final int? day;

  /// 사용 연차 — 서버가 계산한 값. null이면 뱃지를 그리지 않는다
  final double? consumedLeaveDays;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// 여행 날짜가 있으면 '내 코스', 없으면 '추천코스'
  bool get _isSaved => saved['startDate'] != null;

  @override
  Widget build(BuildContext context) {
    final allDays = (course['days'] as List).cast<Map<String, dynamic>>();
    final days = day == null
        ? allDays
        : allDays.where((d) => d['day'] == day).toList();

    return Container(
      width: 1080,
      color: AppColors.backgroundNormal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 시안 히어로 — 웹 공유 페이지와 같은 그림을 쓴다
          Image.asset(
            'assets/images/share_hero.png',
            width: 1080,
            fit: BoxFit.fitWidth,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(77.5, 112, 77.5, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                for (final d in days) ...[
                  const SizedBox(height: 60),
                  // 하루짜리 추천코스에는 시안에 Day 표기가 없다.
                  // 여러 날이거나 내 코스(날짜가 붙는다)면 헤더를 둔다
                  if (_isSaved || days.length > 1) ...[
                    _buildDayHeader(d),
                    const SizedBox(height: 24),
                  ],
                  _buildTimeline(d),
                ],
              ],
            ),
          ),
          const SizedBox(height: 76),
          _buildFooter(),
          const SizedBox(height: 76),
        ],
      ),
    );
  }

  /// 제목·부제 — 추천과 내 코스가 다르다
  Widget _buildHeader() {
    final regionName = saved['regionName'] as String? ?? '';
    final duration = ((saved['durationLabel'] as String?) ?? '').replaceAll(
      ' ',
      '',
    );
    final start = DateTime.tryParse(saved['startDate'] as String? ?? '');
    final end = DateTime.tryParse(saved['endDate'] as String? ?? '');

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          if (_isSaved)
            Text.rich(
              TextSpan(
                style: _title,
                children: [
                  TextSpan(text: '$regionName여행, '),
                  TextSpan(
                    text: duration,
                    style: _title.copyWith(color: AppColors.primaryNormal),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            )
          else
            Text.rich(
              TextSpan(
                style: _title,
                children: [
                  TextSpan(text: '$regionName, '),
                  TextSpan(
                    text: duration,
                    style: _title.copyWith(color: AppColors.primaryNormal),
                  ),
                  const TextSpan(text: '\n추천코스입니다.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 22),
          if (_isSaved) ...[
            if (start != null)
              Text(
                end == null || end == start
                    ? '${start.year}.${start.month}.${start.day}'
                    : '${start.year}.${start.month}.${start.day} - ${end.month}.${end.day}',
                style: _subtitle,
              ),
            const SizedBox(height: 26),
            _buildBadges(start),
          ] else
            Text('맞춤코스로 연차 여행을 떠나보세요.', style: _subtitle),
        ],
      ),
    );
  }

  /// 사용 연차·D-DAY — 내 코스에만 붙는다
  Widget _buildBadges(DateTime? start) {
    final labels = <String>[
      if (consumedLeaveDays != null)
        '사용 연차 일수 ${formatLeaveDays(consumedLeaveDays!)}일',
      if (start != null) _dDayLabel(start),
    ].where((s) => s.isNotEmpty).toList();
    if (labels.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
            decoration: BoxDecoration(
              // 시안: primary 8% 면 위에 primary 글자
              color: AppColors.primaryNormal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: AppTypography.headline1Bold.copyWith(
                color: AppColors.primaryNormal,
                fontSize: 34,
              ),
            ),
          ),
      ],
    );
  }

  /// 지난 여행에는 D-DAY를 붙이지 않는다
  String _dDayLabel(DateTime start) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = DateUtils.dateOnly(start).difference(today).inDays;
    if (diff == 0) return 'D-DAY';
    return diff > 0 ? 'D-$diff' : '';
  }

  Widget _buildDayHeader(Map<String, dynamic> d) {
    final date = DateTime.tryParse(d['date'] as String? ?? '');
    return Row(
      children: [
        Text(
          'Day ${d['day']}',
          style: AppTypography.title3Bold.copyWith(
            color: AppColors.labelNormal,
            fontSize: 40,
          ),
        ),
        // 추천코스는 아직 언제 갈지 정해지지 않았다 — 시안에도 'Day N'만 있다
        if (_isSaved && date != null) ...[
          const SizedBox(width: 24),
          Text(
            '${date.month}.${date.day} ${_weekdays[date.weekday - 1]}',
            style: AppTypography.title3Bold.copyWith(
              color: AppColors.labelAlternative,
              fontSize: 40,
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
        for (var i = 0; i < places.length; i++)
          _buildRow(i + 1, places[i], isLast: i == places.length - 1),
      ],
    );
  }

  Widget _buildRow(
    int index,
    Map<String, dynamic> place, {
    required bool isLast,
  }) {
    final catchphrase = place['catchphrase'] as String?;
    final isStay = place['kind'] == 'STAY';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 번호와 다음 번호를 잇는 선 — 마지막 장소 아래로는 나가지 않는다
          SizedBox(
            width: 60,
            child: Column(
              children: [
                const SizedBox(height: 37.5),
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isStay
                        ? AppAccentColors.backgroundPink
                        : AppColors.primaryNormal,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: AppTypography.title3Bold.copyWith(
                      color: AppColors.staticWhite,
                      fontSize: 35,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: AppColors.lineNormalNeutral,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 45),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place['name'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title3Bold.copyWith(
                      color: AppColors.labelNormal,
                      fontSize: 40,
                    ),
                  ),
                  if (catchphrase != null) ...[
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        style: AppTypography.headline1Bold.copyWith(
                          color: AppColors.labelNeutral,
                          fontSize: 35,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: '추천 ',
                            style: TextStyle(color: AppColors.primaryStrong),
                          ),
                          TextSpan(text: catchphrase),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    (place['category'] as String?) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body1NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                      fontSize: 32.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 42.5),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.5),
            child: PlaceThumbnail(
              imageUrl: place['imageUrl'] as String?,
              size: 175,
              radius: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Text(
            '연차로 떠나는 로컬 여행',
            style: AppTypography.headline1Bold.copyWith(
              color: AppColors.labelAlternative,
              fontSize: 38,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'offway',
            style: AppTypography.title3Bold.copyWith(
              color: AppColors.primaryNormal,
              fontSize: 51,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _title => AppTypography.title3Bold.copyWith(
    color: AppColors.labelNormal,
    fontSize: 57,
    height: 1.33,
  );

  TextStyle get _subtitle => AppTypography.headline1Bold.copyWith(
    color: AppColors.labelAlternative,
    fontSize: 38,
    fontWeight: FontWeight.w500,
  );
}
