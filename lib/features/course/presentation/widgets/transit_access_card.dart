import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../domain/transit_access.dart';

/// **무엇을 타고 어디에 내리는지** 알려 주는 줄 (core #97).
///
/// 코스는 "내린 곳"에서 시작한다(core #127). 그런데 화면은 그 지점을 말한
/// 적이 없어, 대중교통으로 가는 사람은 첫 장소가 왜 거기인지 알 수 없었다.
///
/// **시안 없이 먼저 붙인다.** 서버가 내리는 값(수단·도착지·소요시간·대안)을
/// 표로 설명하는 것보다 실제 데이터가 들어간 화면을 띄워 두는 편이 디자이너가
/// 판단하기 빠르다. 갈아끼우기 쉽게 한 위젯에 모아 뒀다.
class TransitAccessCard extends StatelessWidget {
  const TransitAccessCard({super.key, required this.access});

  final TransitAccess access;

  @override
  Widget build(BuildContext context) {
    // 내리는 곳조차 모르면 할 말이 없다 — 자리를 비운다
    if (!access.isPresentable) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundNormalAlternative,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/ic_location_tick.svg',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _headline,
                  style: AppTypography.body2NormalMedium.copyWith(
                    color: AppColors.labelNormal,
                  ),
                ),
              ),
            ],
          ),
          if (_detail != null) ...[
            const SizedBox(height: 6),
            Padding(
              // 아이콘 폭(20)+간격(8)만큼 들여 문장이 한 단으로 읽힌다
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                _detail!,
                style: AppTypography.label1NormalMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
            ),
          ],
          if (access.alternatives.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              // 칩만 늘어놓으면 그게 무엇인지 알 수 없다 — 역이 없는 지역은
              // 이웃 역까지 열차로 가는 경로가 대표가 되어(도착 시각을 아는
              // 유일한 수단이라) "괴산 코스인데 왜 음성?"으로 읽힌다
              child: Text(
                '이렇게도 갈 수 있어요',
                style: AppTypography.caption1Medium.copyWith(
                  color: AppColors.labelAssistive,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final option in access.alternatives)
                    _AlternativeChip(option: option),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// `시외버스로 정선까지` — 수단 이름은 서버가 정한 한글을 그대로 쓴다
  String get _headline => '${access.modeLabel}로 ${access.toPlace}까지';

  /// 둘째 줄 — 아는 만큼만 말한다.
  ///
  /// 버스·여객선은 시간표를 못 물어(요청 시점에 조회가 안 된다) 소요시간이
  /// 없을 수 있다. 그때는 출발지만이라도 알린다.
  String? get _detail {
    final parts = <String>[
      if (access.fromPlace != null) '${access.fromPlace}에서 출발',
      if (access.vehicleType != null) access.vehicleType!,
      if (access.durationLabel != null) '약 ${access.durationLabel}',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

/// 이 지역에 닿는 다른 수단 — `열차 · 대천` · `열차 3시간`
class _AlternativeChip extends StatelessWidget {
  const _AlternativeChip({required this.option});

  final TransitOption option;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundNormal,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label,
        style: AppTypography.caption1Medium.copyWith(
          color: AppColors.labelAlternative,
        ),
      ),
    );
  }

  /// 아는 만큼만 붙인다.
  ///
  /// 버스·여객선은 시간표를 못 물어 소요시간이 비는 일이 흔하다. 그때
  /// 수단 이름만 남으면 `열차`·`여객선`처럼 앙상해서 무엇을 알려 주는지
  /// 흐려진다 — **어디에 내리는지는 아니까** 그것이라도 말한다.
  String get _label {
    final parts = <String>[
      option.modeLabel,
      if (option.durationLabel != null)
        option.durationLabel!
      else if (option.toPlace != null)
        option.toPlace!,
    ];
    return parts.join(' · ');
  }
}
