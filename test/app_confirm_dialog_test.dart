import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/app_confirm_dialog.dart';

/// 공통 확인 모달(회원탈퇴·로그아웃·사용 내역 삭제가 함께 쓴다)의 시안 치수.
void main() {
  /// 모달을 띄우고, 안에 그려진 흰 카드의 실제 폭을 돌려준다
  Future<double> showAndMeasure(WidgetTester tester, {Size? screen}) async {
    if (screen != null) {
      await tester.binding.setSurfaceSize(screen);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppConfirmDialog(
              context,
              title: '사용 내역을 삭제할까요?',
              message: '삭제하면 차감된 연차가 복구돼요.',
              confirmLabel: '삭제하기',
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    // Dialog 자체는 화면 슬롯 전체를 차지한다 — 폭을 정하는 건 그 안의
    // ConstrainedBox다
    return tester
        .getSize(
          find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        )
        .width;
  }

  testWidgets('모달 폭은 시안대로 320이다', (tester) async {
    // 넓은 기기에서도 늘어나지 않아야 글줄이 시안과 같게 끊긴다
    expect(await showAndMeasure(tester, screen: const Size(430, 932)), 320);
  });

  testWidgets('좁은 기기에서는 화면을 넘지 않는다', (tester) async {
    // iPhone SE(375)에서도 insetPadding 24×2를 빼고 320이 들어간다
    final width = await showAndMeasure(tester, screen: const Size(375, 667));
    expect(width, 320);
  });

  testWidgets('제목과 본문 간격은 8이다', (tester) async {
    await showAndMeasure(tester);
    final title = tester.getRect(find.text('사용 내역을 삭제할까요?'));
    final message = tester.getRect(find.text('삭제하면 차감된 연차가 복구돼요.'));
    expect(message.top - title.bottom, 8);
  });

  testWidgets('긴 확인 문구도 한 줄로 들어간다', (tester) async {
    // 회원탈퇴가 쓰는 '탈퇴할게요'는 '삭제하기'보다 길다 — 접히면 안 된다
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppConfirmDialog(
              context,
              title: '정말 탈퇴할까요?',
              message: '모든 정보가 사라져요.',
              confirmLabel: '탈퇴할게요',
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('탈퇴할게요'));
    expect(text.maxLines, 1);
    // 한 줄 높이(16×1.5=24)를 넘지 않아야 접히지 않은 것이다
    expect(tester.getSize(find.text('탈퇴할게요')).height, 24);
  });

  testWidgets('본문 한 줄이면 카드 높이가 시안 166이다', (tester) async {
    await showAndMeasure(tester, screen: const Size(402, 874));

    final card = tester.getRect(
      find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    // 28 + 제목 28 + 8 + 본문 22 + 28 + 버튼 32 + 20 = 166
    expect(card.height, 166);
    expect(tester.getRect(find.text('삭제하면 차감된 연차가 복구돼요.')).height, 22);
  });

  testWidgets('버튼은 글자 폭대로 줄고 시안 간격·여백을 지킨다', (tester) async {
    await showAndMeasure(tester, screen: const Size(402, 874));

    final card = tester.getRect(
      find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    final cancel = tester.getRect(find.text('취소'));
    final confirm = tester.getRect(find.text('삭제하기'));

    // 짧은 '취소'가 60으로 부풀면 두 버튼 사이가 시안보다 벌어진다
    expect(cancel.width, lessThan(40));
    expect(confirm.left - cancel.right, 24);
    expect(card.right - confirm.right, 28);
    // 버튼 아래 여백 24 = 버튼 자체 4 + 카드 하단 20
    expect(card.bottom - confirm.bottom, 24);
  });

  testWidgets('버튼 탭 영역은 글자보다 넓다', (tester) async {
    await showAndMeasure(tester);
    // 글자만 눌리면 '취소'(32px)는 손가락에 좁다
    final tap = tester.getRect(
      find.ancestor(of: find.text('취소'), matching: find.byType(Padding)).first,
    );
    expect(tap.width, greaterThan(tester.getSize(find.text('취소')).width));
  });
}
