import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../../core/widgets/app_icon_button.dart';

/// 코스 공유 바텀시트 묶음 (O-09 공유).
///
/// 첫 시트에서 링크 공유 / 이미지 저장을 고르고, 각각 다음 시트로 이어진다.
/// TODO(share): 실제 공유·저장 동작은 정책 확정 후 연결한다. 지금은 화면만 있다.
abstract final class CourseShareSheets {
  /// 1단계 — 무엇으로 공유할지 고른다
  static Future<void> showEntry(BuildContext context, {required int dayCount}) {
    return _show(
      context,
      title: '공유하기',
      itemsBuilder: (sheetContext) => [
        _SheetItem(
          iconAsset: 'assets/icons/ic_link.svg',
          label: '코스 링크 공유하기 (보기전용)',
          // 앞 시트를 먼저 닫아야 다음 시트가 그 위에 겹쳐 쌓이지 않는다
          onTap: () {
            Navigator.of(sheetContext).pop();
            showLinkShare(context);
          },
        ),
        _SheetItem(
          iconAsset: 'assets/icons/ic_image.svg',
          label: '코스 이미지로 저장하기',
          onTap: () {
            Navigator.of(sheetContext).pop();
            showImageSave(context, dayCount: dayCount);
          },
        ),
      ],
    );
  }

  /// 2단계 — 링크를 어디로 보낼지 고른다
  static Future<void> showLinkShare(BuildContext context) {
    return _show(
      context,
      title: '공유하기 (보기전용)',
      itemsBuilder: (sheetContext) => [
        _SheetItem(
          iconAsset: 'assets/icons/kakao_logo.svg',
          label: '카카오톡으로 링크 공유하기',
          onTap: () => Navigator.of(sheetContext).pop(),
        ),
        _SheetItem(
          iconAsset: 'assets/icons/ic_link.svg',
          label: '링크 복사하기',
          onTap: () => Navigator.of(sheetContext).pop(),
        ),
      ],
    );
  }

  /// 2단계 — 며칠치를 이미지로 저장할지 고른다
  static Future<void> showImageSave(
    BuildContext context, {
    required int dayCount,
  }) {
    return _show(
      context,
      title: '저장하기',
      itemsBuilder: (sheetContext) => [
        _SheetItem(
          label: '전체 일정 저장하기',
          onTap: () => Navigator.of(sheetContext).pop(),
        ),
        // 하루짜리 코스는 '전체'와 'Day 1'이 같아 날짜별 항목을 두지 않는다
        if (dayCount > 1)
          for (var day = 1; day <= dayCount; day++)
            _SheetItem(
              label: 'Day $day 저장',
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
      ],
    );
  }

  static Future<void> _show(
    BuildContext context, {
    required String title,
    required List<_SheetItem> Function(BuildContext) itemsBuilder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      barrierColor: AppColors.materialDimmer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTitleBar(title: title),
            const SizedBox(height: 23),
            ...itemsBuilder(sheetContext),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// 시트 상단 — 가운데 제목, 오른쪽 닫기
class _SheetTitleBar extends StatelessWidget {
  const _SheetTitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: AppTypography.body1NormalBold.copyWith(
              color: AppColors.labelNormal,
            ),
          ),
          Positioned(
            // 버튼이 아이콘보다 넓으므로 여백을 줄여 아이콘 위치를 맞춘다
            right: 6,
            child: AppIconButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
              semanticLabel: '닫기',
            ),
          ),
        ],
      ),
    );
  }
}

/// 시트 항목 한 줄 — 아이콘이 없는 항목은 글자만 왼쪽에 붙는다
class _SheetItem extends StatelessWidget {
  const _SheetItem({required this.label, required this.onTap, this.iconAsset});

  final String label;
  final VoidCallback onTap;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            if (iconAsset case final asset?) ...[
              _RoundIcon(asset: asset),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Text(
                label,
                style: AppTypography.body1NormalMedium.copyWith(
                  color: AppColors.labelNormal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 옅은 원 위에 얹는 항목 아이콘
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.fillNormal,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(asset, width: 14, height: 14),
    );
  }
}
