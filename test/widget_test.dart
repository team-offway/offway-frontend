import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/app/app.dart';

void main() {
  testWidgets('앱이 정상적으로 실행되고 홈 화면이 보인다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();

    expect(find.text('Offway'), findsOneWidget);
  });
}
