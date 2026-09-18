import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 위쪽을 가리키는 말풍선 툴팁 (DS Tooltip/Tooltip · Position=Bottom).
///
/// 어떤 버튼이 무엇을 하는지 한 번 알려 주고 사라지는 자리다. 어두운 배경에
/// 흰 글씨라 화면 위에 떠 있어도 뒤 내용과 섞이지 않는다.
class AppTooltipBubble extends StatelessWidget {
  const AppTooltipBubble({
    super.key,
    required this.text,
    this.onClose,
    this.arrowAtBottom = false,
  });

  final String text;

  /// 화살표를 **말풍선 아래**에 두어 밑을 가리킨다.
  ///
  /// 기본은 위를 가리키는 모양(DS Position=Bottom)이다. 가리킬 대상이
  /// 말풍선보다 아래에 있을 때만 뒤집는다
  final bool arrowAtBottom;

  /// 닫기(X)를 누르면 부른다. null이면 버튼을 두지 않는다 —
  /// 눌러도 아무 일이 없는 자리를 남기지 않는다
  final VoidCallback? onClose;

  /// 시안 실측 — 화살표가 차지하는 자리는 20×8이고, 에셋 도형 자체는
  /// 20×5.92다(1274:37978의 프레임 8 안에 도형이 아래로 붙어 있다)
  static const _arrowWidth = 20.0;
  static const _arrowHeight = 8.0;

  /// 에셋 도형 자체의 높이 — 자리(8)보다 낮고 아래에 붙는다
  static const _arrowShapeHeight = 5.92412;

  /// 화살표가 차지한 자리를 테스트에서 집기 위한 키.
  ///
  /// 예전에는 `CustomPaint`를 크기(20×8)로 가려냈는데, 그림을 에셋으로
  /// 바꾸면 그 방법이 조용히 깨진다 — 찾는 기준을 겉모습이 아니라 키로 둔다
  @visibleForTesting
  static const arrowKey = ValueKey('tooltip-arrow');
  static const _bubbleRadius = 8.0;

  /// 시안 실측 — 닫기 아이콘 19.2
  static const _closeSize = 19.2;

  @override
  Widget build(BuildContext context) {
    // 시안 실측: 화살표 오른쪽 끝이 말풍선 오른쪽에서 8이다.
    // 코너 곡선(반지름 8)이 끝나는 자리와 정확히 만나 겹치지 않는다
    // 시안 컴포넌트(1274:37981)를 그대로 딴 에셋이다. 손으로 그린
    // 삼각형은 밑변이 말풍선에 닿는 '어깨'가 없어 결이 달랐다.
    //
    // 에셋의 꼭짓점은 위를 향한다 — 아래를 가리킬 때만 뒤집는다
    //
    // **늘리지 않는다.** 시안은 8짜리 자리 안에서 도형이 아래(말풍선 쪽)에
    // 붙고 위로 2.08이 빈다. fill로 8까지 늘리면 꼭짓점이 그만큼 올라가
    // 사진과의 간격이 어긋난다
    final arrowAsset = SizedBox(
      key: arrowKey,
      width: _arrowWidth,
      height: _arrowHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SvgPicture.asset(
          'assets/icons/ic_tooltip_arrow.svg',
          width: _arrowWidth,
          height: _arrowShapeHeight,
          excludeFromSemantics: true,
          colorFilter: ColorFilter.mode(_opaqueColor, BlendMode.srcIn),
        ),
      ),
    );
    final arrow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // **말풍선 쪽으로 반 픽셀 밀어 넣는다.** 딱 맞대면 맞닿는 줄이 서로를
      // 덮지 못해 가는 선이 남는다. 자리(높이 8)는 그대로라 시안 간격은
      // 달라지지 않는다 — 그리는 위치만 옮긴다
      child: Transform.translate(
        offset: Offset(0, arrowAtBottom ? -0.5 : 0.5),
        child: arrowAtBottom
            ? Transform.rotate(angle: math.pi, child: arrowAsset)
            : arrowAsset,
      ),
    );

    // **바탕만** 한 겹으로 합성한다. 화살표와 말풍선을 불투명으로 그린 뒤
    // 투명도를 한 번 주면 맞닿는 줄이 생기지 않는다.
    //
    // 글자와 닫기 아이콘은 이 레이어 **밖**이다 — 같이 감싸면 글자까지
    // 88.6%로 흐려진다
    final background = Opacity(
      opacity: _bubbleOpacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 화살표는 제 폭(20)만 차지하고 오른쪽에 붙는다
          if (!arrowAtBottom)
            Align(alignment: Alignment.centerRight, child: arrow),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _opaqueColor,
                borderRadius: BorderRadius.circular(_bubbleRadius),
              ),
            ),
          ),
          if (arrowAtBottom)
            Align(alignment: Alignment.centerRight, child: arrow),
        ],
      ),
    );

    return Stack(
      children: [
        // 바탕은 내용이 정한 크기를 그대로 채운다
        Positioned.fill(child: background),
        Column(
          mainAxisSize: MainAxisSize.min,
          // 글자만큼만 넓어진다 — stretch로 두면 부모 폭을 다 먹어 시안(191)과
          // 어긋나고, 화살표도 붙일 자리를 잃는다
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!arrowAtBottom) const SizedBox(height: _arrowHeight),
            Container(
              constraints: const BoxConstraints(minWidth: 64, maxWidth: 256),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      style: AppTypography.label1NormalMedium.copyWith(
                        color: AppColors.inverseLabel,
                      ),
                    ),
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.opaque,
                      child: Semantics(
                        button: true,
                        label: '안내 닫기',
                        child: SvgPicture.asset(
                          'assets/icons/ic_circle_close.svg',
                          width: _closeSize,
                          height: _closeSize,
                          excludeFromSemantics: true,
                          colorFilter: const ColorFilter.mode(
                            AppColors.inverseLabel,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (arrowAtBottom) const SizedBox(height: _arrowHeight),
          ],
        ),
      ],
    );
  }

  /// 시안은 어두운 배경(88%) 위에 브랜드색을 5% 얹는다 — 그 둘을 미리 섞어
  /// 한 겹으로 칠한다. 두 겹을 그대로 쌓으면 화살표에서 경계가 비친다
  static final _bubbleColor = Color.alphaBlend(
    AppColors.primaryNormal.withValues(alpha: AppOpacity.o5),
    AppColors.inverseBackground.withValues(alpha: AppOpacity.o88),
  );

  /// 같은 색의 **불투명** 판 — 화살표와 말풍선은 이것으로 그리고, 투명도는
  /// 둘을 합친 뒤 [_bubbleOpacity]로 **한 번만** 준다.
  ///
  /// 반투명으로 각각 칠하면 맞닿는 줄이 부분 커버리지로 남아(측정값: 꽉 찬
  /// 26 대비 12) 뒤 배경이 더 비친다 — 그게 화살표 밑에 보이던 가는 선이다
  static final _opaqueColor = _bubbleColor.withValues(alpha: 1);

  /// 말풍선 전체에 한 번 적용할 투명도
  static final _bubbleOpacity = _bubbleColor.a;
}
