import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_toast.dart';

/// 오류 화면의 '다시 시도'가 **눌린 것처럼 보이게** 하는 두 규칙.
///
/// 백엔드 피드백: 502 화면에서 다시 시도를 눌러도 화면이 그대로라 눌린 건지,
/// 또 실패한 건지 알 수 없어 서버에 502 요청만 쌓였다. Riverpod은 다시 읽는
/// 동안 이전 오류를 그대로 들고 있어서(`skipLoadingOnRefresh`) 오류 화면이
/// 한 번도 안 바뀌었다.
///
/// 1. 오류에서 다시 읽는 동안은 **로딩**을 보여준다 — [whenRetryable] /
///    [isRetrying]. 데이터가 있는 상태의 새로고침(당겨서 새로고침 등)은
///    지금처럼 이전 화면을 유지한다 — 거기서 로딩으로 바꾸면 스켈레톤이
///    깜빡인다.
/// 2. 다시 읽었는데 **또 실패**하면 토스트로 알린다 — [retryFailureToast].
///    첫 실패에는 안 띄운다. 오류 화면이 이미 말하고 있다.
extension AsyncRetryView<T> on AsyncValue<T> {
  /// [when]과 같되, 오류에서 다시 읽는 동안은 [loading]을 그린다
  R whenRetryable<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
  }) => when(
    skipLoadingOnRefresh: !hasError,
    data: data,
    error: error,
    loading: loading,
  );

  /// 오류 화면에서 '다시 시도'를 눌러 다시 읽는 중인가 — `isLoading`·`hasError`로
  /// 갈라 그리는 화면이 로딩 분기를 먼저 타게 할 때 쓴다
  bool get isRetrying => isLoading && hasError;
}

/// 다시 시도가 또 실패했을 때의 문구
const retryFailedMessage = '아직 불러올 수 없어요. 잠시 후 다시 시도해 주세요.';

/// 오류 → (다시 읽는 중) → 오류 인 전이. 첫 실패(로딩 → 오류)는 아니다
bool isRetryFailure(AsyncValue<Object?>? previous, AsyncValue<Object?> next) {
  if (previous == null) return false;
  return previous.isLoading &&
      previous.hasError &&
      next.hasError &&
      !next.isLoading;
}

/// `ref.listen(provider, retryFailureToast(context))` — 다시 시도가 또
/// 실패하면 오류 화면 위에 토스트를 띄운다
void Function(AsyncValue<T>? previous, AsyncValue<T> next) retryFailureToast<T>(
  BuildContext context,
) => (previous, next) {
  if (!isRetryFailure(previous, next)) return;
  if (context.mounted) showAppToast(context, retryFailedMessage);
};
