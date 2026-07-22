import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../mock/mock_data_source.dart';
import '../application/course_wizard_provider.dart';

/// 후보지역 mock (서버 연동 시 추천 API 응답으로 교체)
final wizardCandidatesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final data = await MockDataSource.regions();
  return (data['candidates'] as List).cast<Map<String, dynamic>>();
});

/// O-08 · 후보지역 (와이어프레임)
class CandidatesScreen extends ConsumerWidget {
  const CandidatesScreen({super.key});

  // TODO(디자인시스템): 공통 컴포넌트/토큰 확정 후 교체
  static const _labelNormal = Color(0xFF171719);
  static const _textTertiary = Color(0xFFADB1BB);
  static const _metaText = Color(0xFF999999);
  static const _imagePlaceholder = Color(0x806F767E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(wizardCandidatesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 12, 19, 0),
              child: GestureDetector(
                onTap: () {
                  // 위저드 종료: 조건 초기화 후 홈으로
                  ref.read(courseWizardProvider.notifier).reset();
                  context.go(AppRoutes.home);
                },
                child: const Icon(Icons.close, size: 26, color: _labelNormal),
              ),
            ),
            Expanded(
              child: candidates.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('후보지역을 불러오지 못했어요\n$e')),
                data: (list) => ListView(
                  padding: const EdgeInsets.fromLTRB(23, 12, 23, 24),
                  children: [
                    Text(
                      '약 7시간 안에 갈 수 있는\n여행지 ${list.length}곳을 찾았어요',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _labelNormal,
                        letterSpacing: -0.6,
                        height: 32 / 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '지역을 눌러서 코스를 확인해보세요.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: _textTertiary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (var i = 0; i < list.length; i++) ...[
                      _CandidateCard(region: list[i], isTop: i == 0),
                      const SizedBox(height: 28),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({required this.region, required this.isTop});

  final Map<String, dynamic> region;
  final bool isTop;

  String _travelTimeText() {
    final minutes = region['travelMinutesByCar'] as int?;
    if (minutes == null) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h시간' : '$h시간$m분';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = region['imageUrl'] as String?;
    final benefit = region['benefitBadge'] as String?;
    final meta = [
      _travelTimeText(),
      if (benefit != null) benefit.replaceAll(' ', ''),
    ].where((s) => s.isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: () {
        // TODO(wizard): 코스확정(O-09) 화면 작업 시 지역 코스로 연결
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: 200,
              width: double.infinity,
              color: CandidatesScreen._imagePlaceholder,
              child: imageUrl == null
                  ? null
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${region['name']} · ${region['sido']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CandidatesScreen._labelNormal,
                  letterSpacing: -0.6,
                ),
              ),
              if (isTop) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF191B1F),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '추천1위',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            style: const TextStyle(
              fontSize: 15,
              color: CandidatesScreen._metaText,
            ),
          ),
        ],
      ),
    );
  }
}
