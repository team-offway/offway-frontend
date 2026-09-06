import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/app_update_provider.dart';
import '../data/update_prompt_snooze_storage.dart';
import '../domain/app_update.dart';
import 'update_prompt_sheet.dart';

/// 스토어에 더 새 버전이 있으면 업데이트 시트를 띄운다 — 홈 진입 때.
///
/// "다녀오셨나요?"([TripOutcomePrompt])와 같은 구조다. [build] 안에서
/// [watchUpdatePrompt]를 한 번 부르면 되고, 한 진입에 한 번만 묻는다.
/// '나중에'·닫기는 그날 하루 접어 둔다. '업데이트'는 App Store를 **앱 밖**으로
/// 연다 — 앱 안 브라우저로는 스토어가 열리지 않는다.
mixin UpdatePrompt<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _updateAsked = false;

  void watchUpdatePrompt() {
    final update = ref.watch(availableUpdateProvider).value;
    if (update == null || _updateAsked) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_updateAsked) _askUpdate(update);
    });
  }

  Future<void> _askUpdate(AppUpdate update) async {
    _updateAsked = true;
    final snooze = ref.read(updatePromptSnoozeProvider);
    // 개발용 강제 모드에서는 미룬 기록을 안 본다 — '나중에'를 눌러 봐도
    // 다음 진입에 또 떠야 눌러 볼 수 있다
    if (!AppConfig.forceUpdatePrompt &&
        await snooze.isSnoozedToday(update.storeVersion, DateTime.now())) {
      return;
    }
    if (!mounted) return;

    final answer = await showUpdatePromptSheet(context);
    if (!mounted) return;

    if (answer != UpdatePromptAnswer.update) {
      await snooze.snooze(update.storeVersion, DateTime.now());
      return;
    }
    final uri = Uri.tryParse(update.storeUrl);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on Exception {
        opened = false;
      }
    }
    if (!opened && mounted) {
      showAppToast(context, 'App Store를 열지 못했어요. 스토어에서 OffWay를 찾아 주세요.');
    }
  }
}
