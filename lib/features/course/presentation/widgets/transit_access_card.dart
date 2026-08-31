import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../domain/transit_access.dart';
import 'dotted_line.dart';

/// **무엇을 타고 어디에 내리는지** 알려 주는 카드 (core #97).
///
/// 코스는 "내린 곳"에서 시작한다(core #127). 그런데 화면은 그 지점을 말한
/// 적이 없어, 대중교통으로 가는 사람은 첫 장소가 왜 거기인지 알 수 없었다.
///
/// 다른 수단으로도 갈 수 있으면 아래 버튼으로 **갈아끼워 본다.** 예전에는
/// 대안을 칩으로 늘어놓았는데, 시안이 한 번에 하나씩 보여 주는 쪽으로
/// 정리했다 — 나란히 두면 무엇이 지금 기준인지 흐려진다.
class TransitAccessCard extends StatefulWidget {
  const TransitAccessCard({super.key, required this.access});

  final TransitAccess access;

  @override
  State<TransitAccessCard> createState() => _TransitAccessCardState();
}

class _TransitAccessCardState extends State<TransitAccessCard> {
  /// 대안으로 갈아낀 상태 — null이면 서버가 준 대표를 그대로 본다.
  ///
  /// **원본을 덮지 않고 따로 둔다.** 대표를 대안 목록에 접어 넣는 식으로
  /// 맞바꾸면, 서버가 대안에 싣지 않는 출발지·편명이 그때 사라져 두 번 눌러
  /// 돌아왔을 때 첫 화면과 달라진다.
  TransitOption? _picked;

  @override
  void didUpdateWidget(TransitAccessCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 코스를 다시 읽어 새 값이 오면 고른 것을 버리고 대표로 돌아간다
    if (!identical(oldWidget.access, widget.access)) _picked = null;
  }

  /// 지금 화면에 그릴 것
  TransitAccess get _shown =>
      _picked == null ? widget.access : widget.access.swappedWith(_picked!);

  @override
  Widget build(BuildContext context) {
    // 내리는 곳조차 모르면 할 말이 없다 — 자리를 비운다
    if (!_shown.isPresentable) return const SizedBox.shrink();

    // 갈아낀 상태면 '원래대로', 아니면 첫 대안으로 넘어가는 버튼이다
    final next = _picked != null
        ? null
        : (widget.access.alternatives.isEmpty
              ? null
              : widget.access.alternatives.first);

    return Container(
      width: double.infinity,
      // 시안 실측 — 좌우 20.5, 위 14.5, 아래는 버튼 유무로 갈린다
      padding: EdgeInsets.fromLTRB(
        20.5,
        14.5,
        20.5,
        next == null ? 18.5 : 14.5,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundNormalAlternative,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 시안이 이 자리를 브랜드색에서 회색으로 낮췄다 — 무엇을 타는지
              // 알리는 줄이지 강조할 자리는 아니다. 에셋은 코스 저장 안내가
              // 브랜드색 48로 그대로 쓰므로 여기서만 덮는다
              SvgPicture.asset(
                'assets/icons/ic_location_tick.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.labelAlternative,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _headline,
                  style: AppTypography.body2NormalBold.copyWith(
                    color: AppColors.labelNormal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 아이콘 한가운데(24의 절반)에서 아래로 흘리는 점선.
                // 코스 타임라인이 번호를 잇는 것과 같은 뜻이다 — 위 줄에서
                // 이어지는 말임을 선으로 붙든다.
                //
                // **문구가 없어도 그린다.** 서버가 소요시간을 아직 못 잰
                // 구간에서는 둘째 줄이 통째로 비는데, 그때 점선까지 사라지면
                // 같은 카드가 지역마다 다르게 보인다
                SizedBox(
                  width: 24,
                  child: Center(child: DottedVerticalLine.transit()),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    // 아직 모르는 값이라 비워 둔다 — 자리는 점선이 지킨다.
                    // 빈 문자열이라도 줘야 줄 높이가 잡혀 점선이 그려진다
                    _detail ?? '',
                    style: AppTypography.label1NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_swapLabel case final String label) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: _SwapButton(
                label: label,
                // 갈아낀 상태에서 다시 누르면 원본으로 돌아간다
                onTap: () =>
                    setState(() => _picked = _picked == null ? next : null),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 버튼에 쓸 말 — 갈아낄 것도, 돌아갈 곳도 없으면 null이라 버튼을 안 그린다
  String? get _swapLabel {
    if (_picked != null) return '${widget.access.modeLabel}로 보기';
    final first = widget.access.alternatives.firstOrNull;
    return first == null ? null : '${first.modeLabel}로 보기';
  }

  /// `기차로 정선까지` — 수단 이름은 서버가 정한 한글을 그대로 쓴다
  String get _headline => '${_shown.modeLabel}로 ${_shown.toPlace}까지';

  /// 둘째 줄 — 아는 만큼만 말한다.
  ///
  /// 버스·여객선은 시간표를 못 물어(요청 시점에 조회가 안 된다) 소요시간이
  /// 없을 수 있다. 그때는 출발지만이라도 알린다.
  String? get _detail {
    final parts = <String>[
      if (_shown.fromPlace != null) '${_shown.fromPlace}에서 출발',
      if (_shown.vehicleType case final String type)
        if (_shown.durationLabel case final String duration)
          '$type 약 $duration'
        else
          type
      else if (_shown.durationLabel case final String duration)
        '약 $duration',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }
}

/// `시외버스로 보기` — 다른 수단으로 갈아끼우는 버튼.
///
/// 화살표가 서로 엇갈린 아이콘을 앞에 둔다. 바깥으로 나가는 것이 아니라
/// **이 자리에서 바뀐다**는 뜻이라, 쉐브론이나 링크 아이콘은 맞지 않는다.
class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // 시안 실측 — 좌우 8·상하 5, 반경 8. 채우지 않고 테두리만 둔다
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.lineNormalNeutral),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 화살표가 엇갈린 아이콘 — 바깥으로 나가는 것이 아니라
              // 이 자리에서 바뀐다는 뜻이라 쉐브론·링크는 맞지 않는다.
              // 에셋 원본색이 #37383C(Label/Alternative)라 덮지 않는다
              SvgPicture.asset(
                'assets/icons/ic_change.svg',
                width: 16,
                height: 16,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.label2Bold.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
