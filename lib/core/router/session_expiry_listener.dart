import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../storage/secure_storage.dart';
import '../widgets/app_toast.dart';
import 'app_router.dart';

/// 세션이 끊기면 로그인 화면으로 되돌린다.
///
/// 액세스 토큰이 만료되면 인터셉터가 리프레시로 되살린다. 그것마저 실패하는
/// 경우(리프레시도 만료·서버가 폐기·재사용 감지)에는 다시 로그인하는 수밖에
/// 없다. 그때 화면에 오류만 띄우면 사용자가 나갈 길을 찾지 못한다.
///
/// 인터셉터가 직접 화면을 옮기지 않는 이유는 네트워크 계층이 라우터를 알게
/// 되기 때문이다 — [sessionExpiredProvider]로 신호만 받아 여기서 옮긴다.
class SessionExpiryListener extends ConsumerWidget {
  const SessionExpiryListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionExpiredProvider, (previous, expired) {
      if (!expired) return;
      _handleExpiry(context, ref);
    });
    return child;
  }

  Future<void> _handleExpiry(BuildContext context, WidgetRef ref) async {
    try {
      // 못 쓰는 토큰이 남아 있으면 앱을 다시 켤 때 또 홈으로 들어가 같은 일이
      // 되풀이된다
      await ref.read(secureStorageProvider).clear();
    } on Exception catch (e) {
      // Keychain이 실패해도 로그인 화면으로는 보내야 한다 — 여기서 멈추면
      // 사용자는 아무 안내 없이 만료된 화면에 갇힌다
      debugPrint('세션 만료 처리 중 토큰 삭제 실패: $e');
    } finally {
      // 신호를 내려 둔다 — 남아 있으면 다시 로그인해도 곧장 튕긴다
      ref.read(sessionExpiredProvider.notifier).reset();
    }

    if (!context.mounted) return;
    ref.read(appRouterProvider).go(AppRoutes.login);
    showAppToast(context, '로그인이 만료됐어요. 다시 로그인해 주세요');
  }
}
