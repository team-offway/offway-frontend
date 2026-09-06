import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_config.dart';
import '../data/app_store_listing_repository.dart';
import '../domain/app_update.dart';

/// 스토어에 더 새 버전이 있으면 그것, 없으면 null.
///
/// 세션 동안 한 번만 본다 — 홈에 들어올 때마다 애플을 부를 이유가 없다.
/// 실패는 null과 같다. **자동 재시도는 끈다** — 이 값이 없다고 앱이 못 하는
/// 일은 없고, 되묻는 동안 홈 위젯 테스트에 타이머가 남는다.
///
/// `--dart-define=FORCE_UPDATE_PROMPT=true`면 스토어와 상관없이 있다고
/// 답한다 — 심사 전이라 스토어에 없는 동안 모달을 기기에서 보려는 개발용
/// 스위치다. 스토어 페이지를 모르면 App Store 첫 화면으로 보낸다.
final availableUpdateProvider = FutureProvider<AppUpdate?>((ref) async {
  final listing = await ref.watch(appStoreListingRepositoryProvider).latest();
  if (AppConfig.forceUpdatePrompt) {
    return AppUpdate(
      storeVersion: listing?.version ?? 'forced',
      storeUrl: listing?.url ?? 'https://apps.apple.com/kr/',
    );
  }
  final info = await PackageInfo.fromPlatform();
  return decideUpdate(
    currentVersion: info.version,
    storeVersion: listing?.version,
    storeUrl: listing?.url,
  );
}, retry: (retryCount, error) => null);
