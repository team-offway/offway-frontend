import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../application/course_wizard_provider.dart';
import 'widgets/wizard_choice_step.dart';

/// O-06 · 일정 밀도 (STEP 4/4, 와이어프레임)
class DensityScreen extends ConsumerWidget {
  const DensityScreen({super.key});

  static const _densities = [ScheduleDensity.packed, ScheduleDensity.relaxed];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(
      courseWizardProvider.select((draft) => draft.scheduleDensity),
    );

    return WizardChoiceStep(
      stepLabel: '4/4',
      title: '내가 선호하는 스타일은?',
      subtitle: '원하는 스타일을 반영할게요.',
      options: const ['빼곡한 일정', '널널한 일정'],
      selectedIndex: density == null ? null : _densities.indexOf(density),
      onSelect: (i) =>
          ref.read(courseWizardProvider.notifier).selectDensity(_densities[i]),
      onNext: density == null
          ? null
          : () => context.push(AppRoutes.wizardLoading),
    );
  }
}
