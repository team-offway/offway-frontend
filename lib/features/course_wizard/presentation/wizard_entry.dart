import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../application/course_wizard_provider.dart';

/// 코스 추천 위저드에 **처음부터** 들어간다 — 홈·내 코스의 '코스 추천받기'.
///
/// 위저드 상태([courseWizardProvider])는 앱이 살아 있는 동안 남는다. 예전에는
/// 날짜·유형까지 고르다 뒤로 나와 홈에서 다시 누르면 그 값이 그대로 선택돼
/// 있었다 — 새로 시작하는 사람에게 지난번 선택은 뜻이 없다.
///
/// **위저드 안에서 뒤로 가는 것은 지킨다.** 이동수단에서 날짜로 되돌아가면
/// 고른 값이 남아야 고쳐 고를 수 있다. 그래서 첫 화면이 아니라 진입점에서
/// 비운다 — 진입점이 늘어도 이 함수를 부르면 된다.
void startCourseWizard(BuildContext context, WidgetRef ref) {
  ref.read(courseWizardProvider.notifier).reset();
  context.push(AppRoutes.wizardDateGate);
}
