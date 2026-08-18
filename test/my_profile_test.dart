import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/my/application/my_profile_provider.dart';
import 'package:offway/features/my/presentation/my_screen.dart';

/// 마이 화면 프로필 — 소셜 닉네임과 프로필 사진을 서버에서 받아 그린다.
void main() {
  // 화면이 무엇을 그리는지만 본다 — 값이 홈에서 왔는지 /users/me에서
  // 왔는지는 my_profile_provider_test.dart가 따로 확인한다
  Widget wrap(Map<String, dynamic> user) => ProviderScope(
    overrides: [myProfileProvider.overrideWith((ref) async => user)],
    child: const MaterialApp(home: MyScreen()),
  );

  testWidgets('닉네임을 인사말에 넣는다', (tester) async {
    await tester.pumpWidget(wrap({'nickname': '영찬'}));
    await tester.pump();

    expect(find.text('영찬님, 반가워요!'), findsOneWidget);
  });

  testWidgets('닉네임이 없으면 이름 없이 인사한다', (tester) async {
    // 로그인 전이나 서버가 이름을 못 준 상태 — "null님"이 보이면 안 된다
    await tester.pumpWidget(wrap({}));
    await tester.pump();

    expect(find.text('반가워요!'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('프로필 사진이 없으면 기본 아이콘을 쓴다', (tester) async {
    await tester.pumpWidget(wrap({'nickname': '영찬'}));
    await tester.pump();

    expect(find.byType(SvgPicture), findsWidgets);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('프로필 사진이 오면 그 사진을 그린다', (tester) async {
    await tester.pumpWidget(
      wrap({'nickname': '영찬', 'profileImageUrl': 'https://example.com/me.jpg'}),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image).first);
    expect((image.image as NetworkImage).url, 'https://example.com/me.jpg');
  });

  testWidgets('빈 문자열은 사진이 없는 것으로 본다', (tester) async {
    // 서버가 값을 비워 보내면 깨진 이미지 자리가 남는다
    await tester.pumpWidget(wrap({'nickname': '영찬', 'profileImageUrl': ''}));
    await tester.pump();

    expect(find.byType(Image), findsNothing);
  });
}
