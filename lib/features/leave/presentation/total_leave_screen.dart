import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/current_user_provider.dart';
import '../../home/presentation/home_screen.dart' show homeSnapshotProvider;
import '../../onboarding/data/leave_repository.dart';
import '../data/leave_usages_provider.dart';

/// 총 연차일수를 고쳐 쓰는 화면 — 마이 > 내 연차 관리.
///
/// **[MyLeaveScreen]과 다른 자리다.** 그쪽은 언제 며칠을 썼는지(사용 내역)를
/// 보는 곳이고, 여기는 "올해 며칠을 쓸 수 있는가"라는 **기준값**을 고치는
/// 곳이다. 시안이 마이에서 따로 들어가게 그린 이유이기도 하다.
class TotalLeaveScreen extends ConsumerStatefulWidget {
  const TotalLeaveScreen({super.key});

  @override
  ConsumerState<TotalLeaveScreen> createState() => _TotalLeaveScreenState();
}

class _TotalLeaveScreenState extends ConsumerState<TotalLeaveScreen> {
  /// 수정 모드인가 — 카드를 보는 상태와 입력하는 상태를 한 화면이 오간다.
  /// 시안이 화면을 나눠 그렸지만 상단바·안내가 그대로라 오가는 편이 자연스럽다
  bool _editing = false;

  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 손을 떼면 지우기(✕)가 체크(✓)로 바뀐다 — 그리려면 다시 build해야 한다
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 입력한 값이 저장할 수 있는 숫자인가.
  ///
  /// 서버는 0.25 단위(반반차)까지 받는다. 그보다 잘게 쓰면 화면에 안 떨어지는
  /// 잔여가 생기므로 여기서 끊는다
  String? get _error {
    final raw = _input.text.trim();
    if (raw.isEmpty) return null;
    final days = double.tryParse(raw);
    if (days == null) return '숫자만 입력해 주세요.';
    if (days <= 0) return '0일보다 많아야 해요.';
    // 정수·0.25·0.5만 받는다. 0.75는 쓰지 않는 단위라 함께 막는다
    final fraction = days - days.floorToDouble();
    if (fraction != 0 && fraction != 0.25 && fraction != 0.5) {
      return '지원하지 않는 단위입니다.';
    }
    return null;
  }

  bool get _canSubmit =>
      _input.text.trim().isNotEmpty && _error == null && !_submitting;

  Future<void> _submit() async {
    final days = double.tryParse(_input.text.trim());
    if (days == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(leaveRepositoryProvider).updateTotalDays(days);
      if (!mounted) return;
      // 잔여 연차를 읽는 곳이 셋이다 — 이 화면, 홈 카드, 마이의 사용자 정보.
      // 하나만 고치면 화면마다 다른 숫자를 말한다
      ref
        ..invalidate(myLeaveProvider)
        ..invalidate(homeSnapshotProvider)
        ..invalidate(currentUserProvider);
      setState(() {
        _editing = false;
        _submitting = false;
      });
      _input.clear();
      showAppToast(context, '연차 정보를 업데이트했어요.', kind: AppToastKind.success);
    } on Object {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppToast(
        context,
        '수정하지 못했어요. 잠시 후 다시 시도해 주세요',
        kind: AppToastKind.cautionary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leave = ref.watch(myLeaveProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      // 키보드가 올라올 때 본문을 밀지 않는다 — 안내 문구가 입력 위에
      // 붙어 있어, 밀면 그 문구부터 화면 밖으로 나간다
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            Expanded(
              child: leave.when(
                loading: () => const AppCircularLoadingView(),
                error: (_, _) => AppErrorView(
                  onRetry: () => ref.invalidate(myLeaveProvider),
                ),
                data: (data) => _editing
                    ? _buildEditor()
                    : _buildSummary(data.remainingDays),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 시안: 뒤로가기 + 가운데 제목
  Widget _buildTopBar() {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            // 버튼이 아이콘보다 넓어 좌측 여백을 줄여야 잉크가 다른 화면과
            // 같은 자리에 온다
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: AppBackButton(onTap: () => context.pop()),
            ),
          ),
          Text(
            '내 연차 관리',
            style: AppTypography.headline2Bold.copyWith(
              color: AppColors.labelStrong,
            ),
          ),
        ],
      ),
    );
  }

  /// 잔여 연차 카드 + '총 연차일수란?' 안내
  Widget _buildSummary(double remainingDays) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RemainingCard(
            remainingDays: remainingDays,
            onEdit: () {
              setState(() => _editing = true);
              // 들어오자마자 입력할 수 있게 — 한 번 더 눌러야 하면 수정하러
              // 온 사람에게 걸음이 하나 는다
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _focus.requestFocus(),
              );
            },
          ),
          // 시안 실측: 카드~안내 36
          const SizedBox(height: 36),
          const _Notice(
            title: '총 연차일수란?',
            body: '올해 사용할 수 있는 전체 연차일수예요.\n연차가 갱신되거나 잘못 입력했다면 수정할 수 있어요.',
          ),
        ],
      ),
    );
  }

  /// 새 총 연차일수를 받는 상태
  Widget _buildEditor() {
    final error = _error;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
          child: _DaysField(
            controller: _input,
            focusNode: _focus,
            error: error,
            onChanged: (_) => setState(() {}),
            onClear: () => setState(_input.clear),
          ),
        ),
        const Spacer(),
        // 안내와 버튼은 키보드 위에 붙는다 — 시안이 하단에 고정해 뒀다
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: _Notice(
            title: '확인해주세요',
            body: '재설정하면 지금까지의 사용 내역은 유지되지만,\n잔여일수가 새 기준으로 다시 계산돼요',
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            // 키보드가 있으면 그 위로, 없으면 홈 인디케이터 위로
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNormal,
                disabledBackgroundColor: AppColors.interactionDisable,
                foregroundColor: AppColors.staticWhite,
                disabledForegroundColor: AppColors.labelAssistive,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('등록하기', style: AppTypography.body1NormalBold),
            ),
          ),
        ),
      ],
    );
  }
}

/// 잔여 연차를 크게 보여주고 수정으로 보내는 카드.
///
/// 반짝이(StarFour) 셋은 시안 좌표 그대로 둔다 — 타이머 주변에 흩어져
/// 있어야 '남은 시간'이라는 인상이 산다
class _RemainingCard extends StatelessWidget {
  const _RemainingCard({required this.remainingDays, required this.onEdit});

  final double remainingDays;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // 시안 실측: 좌우 71 · 상하 20 — 안쪽 내용이 220px로 좁게 모인다
      padding: const EdgeInsets.symmetric(horizontal: 71, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.backgroundNormalAlternative,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 시안 좌표(카드 안쪽 기준) — 타이머를 둘러싸듯 흩어 둔다.
          // 패딩 71을 뺀 자리라 왼쪽 값이 시안보다 그만큼 작다
          const Positioned(left: 131, top: 14, child: _Sparkle(size: 9)),
          const Positioned(left: 70, top: -5, child: _Sparkle(size: 7.3)),
          const Positioned(left: 81, top: 40, child: _Sparkle(size: 9)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/ic_timer.svg',
                width: 49,
                height: 49,
              ),
              // 시안 실측: 아이콘~'잔여 연차' 12
              const SizedBox(height: 12),
              Text(
                '잔여 연차',
                style: AppTypography.label1NormalMedium.copyWith(
                  color: AppColors.labelNeutral,
                ),
              ),
              Text(
                // 서버가 double로 준다(반차 0.5) — 15.0일로 보이지 않게 다듬는다
                '${formatLeaveDays(remainingDays)}일',
                style: AppTypography.title2Bold.copyWith(
                  color: AppColors.labelStrong,
                ),
              ),
              // 시안 실측: 숫자~버튼 20
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryNormal,
                  foregroundColor: AppColors.staticWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  // 글자에 맞춘 폭 — 카드 폭을 다 쓰면 시안보다 무거워진다
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '총 연차일수 수정하기',
                  style: AppTypography.body1NormalBold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 카드 위 반짝이 — 브랜드색이 SVG에 박혀 있어 색을 덧씌우지 않는다
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/ic_star_four.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

/// ⓘ 제목 + 본문 두 줄짜리 안내.
///
/// [AppInlineNotice]는 한 줄짜리 배너라 제목·본문 두 단이 필요한 이 자리에
/// 맞지 않는다
class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/icons/ic_circle_info.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppColors.labelNeutral,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTypography.body2NormalMedium.copyWith(
                color: AppColors.labelNeutral,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: AppTypography.label1ReadingMedium.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
      ],
    );
  }
}

/// 새 총 연차일수 입력 칸.
///
/// 시안의 다섯 상태(빈 값·입력 중·유효·오류·완료)를 한 위젯이 낸다 —
/// 테두리 색과 오른쪽 아이콘이 그 상태를 말한다
class _DaysField extends StatelessWidget {
  const _DaysField({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final focused = focusNode.hasFocus;
    final empty = controller.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '새로운 총 연차일수를 입력해주세요',
          style: AppTypography.label1NormalMedium.copyWith(
            color: AppColors.labelNeutral,
          ),
        ),
        const SizedBox(height: 8),
        // 연차 사용 등록의 차감 일수 칸과 같은 방식이다 — 숫자 폭만큼만
        // TextField를 두고 단위는 그 옆에 붙인다. 칸 어디를 눌러도 수정으로
        // 들어가게 전체를 탭 영역으로 둔다
        GestureDetector(
          onTap: focusNode.requestFocus,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundNormal,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? AppColors.statusNegative
                    : focused
                    ? AppColors.primaryNormal
                    : AppColors.lineNormalNeutral,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 숫자만 편집한다 — 단위까지 지워지지 않도록
                        Flexible(
                          child: IntrinsicWidth(
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: onChanged,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              // 숫자와 소수점만 — 단위를 적어 넣는 사람이 있다
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              style: AppTypography.body1NormalRegular.copyWith(
                                color: AppColors.labelNormal,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        // 단위는 화면에만 붙는다 (값에는 들어가지 않는다).
                        // 빈 칸에까지 '일'만 떠 있으면 무엇을 넣으라는 것인지
                        // 흐려진다
                        if (!empty)
                          Text(
                            '일',
                            style: AppTypography.body1NormalRegular.copyWith(
                              color: AppColors.labelNormal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _TrailingIcon(
                  hasError: hasError,
                  focused: focused,
                  valid: !empty && !hasError,
                  onClear: onClear,
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: AppTypography.caption1Regular.copyWith(
              color: AppColors.statusNegative,
            ),
          ),
        ],
      ],
    );
  }
}

/// 입력 칸 오른쪽 표식 — 오류면 경고, 입력 중이면 지우기, 다 됐으면 체크.
///
/// 연차 사용 등록의 같은 자리와 아이콘 세트를 맞춘다(22px DS 에셋).
class _TrailingIcon extends StatelessWidget {
  const _TrailingIcon({
    required this.hasError,
    required this.focused,
    required this.valid,
    required this.onClear,
  });

  final bool hasError;
  final bool focused;
  final bool valid;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      // 에셋이 회색이라 오류 색을 입힌다
      return SvgPicture.asset(
        'assets/icons/ic_circle_exclamation_solid.svg',
        width: 22,
        height: 22,
        colorFilter: const ColorFilter.mode(
          AppColors.statusNegative,
          BlendMode.srcIn,
        ),
      );
    }
    if (focused) {
      // 시안은 민 ✕가 아니라 동그라미 안의 ✕다 (DS Icon/Normal/Circle Close)
      return GestureDetector(
        onTap: onClear,
        behavior: HitTestBehavior.opaque,
        child: SvgPicture.asset(
          'assets/icons/ic_circle_close.svg',
          width: 22,
          height: 22,
        ),
      );
    }
    if (!valid) return const SizedBox(width: 22);
    // 에셋이 브랜드색을 품고 있다
    return SvgPicture.asset(
      'assets/icons/ic_check_circle_fill.svg',
      width: 22,
      height: 22,
    );
  }
}
