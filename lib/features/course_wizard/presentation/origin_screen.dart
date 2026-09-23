import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';
import '../application/course_wizard_provider.dart';
import 'widgets/wizard_choice_step.dart';
import '../data/origin_search_repository.dart';
import '../domain/origin_hub.dart';

/// O-04-00 · 출발지 입력 (STEP 1/5)
///
/// GPS 를 걷어내면서(core #591) 출발지를 **사용자가 직접 고른다** — 목록에서
/// 고르는 것은 기기 위치를 파악하는 것이 아니라 입력이다. 고른 값은 코드로만
/// 들고 다니고 좌표 해석은 서버가 한다.
class OriginScreen extends ConsumerStatefulWidget {
  const OriginScreen({super.key});

  @override
  ConsumerState<OriginScreen> createState() => _OriginScreenState();
}

class _OriginScreenState extends ConsumerState<OriginScreen> {
  /// 글자마다 부르면 한 단어에 요청이 여럿 나간다 — 손이 멈춘 뒤에 한 번만
  static const _debounce = Duration(milliseconds: 300);

  /// 시안 `line/normal/neutral` 은 16% 인데 앱 토큰은 32% 다. 토큰은 12곳이
  /// 쓰고 있어 전역으로 내리면 다른 화면이 함께 연해진다
  /// TODO(디자인시스템): 토큰 농도가 정리되면 AppColors 로 되돌린다
  static const _fieldBorderColor = Color(0x2970737C);

  /// 입력칸·목록의 좌우 여백. 하단 버튼(20)보다 넓다 — 시안 실측 33.84 로,
  /// 입력칸 폭이 335 가 되는 값이다
  static const _fieldSideMargin = 33.84;

  /// 키보드가 떠 있을 때의 상단 여백 — 시안 1730:40132 (평소는 [kWizardTopGap])
  static const _topGapWithKeyboard = 24.0;

  /// 목록을 입력칸 바로 아래에 붙이려면 그 자리를 알아야 한다. 여백을 더해
  /// 계산하면 글자 크기를 키웠을 때 어긋나 목록이 입력칸을 덮는다
  /// 목록을 입력칸에 **붙여 둔다**. 좌표를 재서 짚으면 키보드가 오르내릴 때
  /// 입력칸은 움직이는데 목록이 옛 자리에 남아 서로 겹친다
  final _fieldLink = LayerLink();

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounceTimer;
  CancelToken? _inFlight;

  List<OriginHub> _results = const [];
  bool _searching = false;

  /// 고른 뒤에는 목록을 닫는다 — 고른 것과 같은 글자가 칸에 남아 있어
  /// 목록을 그대로 두면 이미 끝난 선택을 다시 고르라는 화면이 된다
  OriginHub? _selected;

  @override
  void initState() {
    super.initState();
    final chosen = ref.read(courseWizardProvider).origin;
    if (chosen != null) {
      // 뒤로 돌아왔을 때 고른 값이 남아야 고쳐 고를 수 있다
      _selected = chosen;
      _controller.text = chosen.name;
    }
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inFlight?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    // 고른 뒤 글자를 고치면 그 선택은 더 이상 유효하지 않다
    if (_selected != null && _controller.text != _selected!.name) {
      setState(() => _selected = null);
    }
    _debounceTimer?.cancel();
    // 나가 있는 요청도 **여기서** 끊는다. _search 에서만 끊으면 다음 디바운스
    // (300ms)까지 살아 있어, 그 사이 도착한 옛 응답이 새 검색어 화면에 뜬다
    _inFlight?.cancel();
    final query = _controller.text.trim();
    if (query.length < OriginSearchRepository.minQueryLength) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounceTimer = Timer(_debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final token = CancelToken();
    _inFlight = token;
    try {
      final hubs = await ref
          .read(originSearchRepositoryProvider)
          .search(query, cancelToken: token);
      // 취소가 늦게 반영될 수 있어 검색어를 직접 대조한다 — 응답이 지금
      // 칸에 있는 글자의 것일 때만 목록에 올린다
      if (!mounted || token.isCancelled || query != _controller.text.trim()) {
        return;
      }
      setState(() {
        _results = hubs;
        _searching = false;
      });
    } on Object {
      if (!mounted || token.isCancelled || query != _controller.text.trim()) {
        return;
      }
      // 검색 실패로 화면을 막지 않는다 — 다시 치면 또 부른다
      setState(() {
        _results = const [];
        _searching = false;
      });
    }
  }

  void _choose(OriginHub hub) {
    _focusNode.unfocus();
    // 칸의 글자를 **먼저** 맞춘다. 나중에 바꾸면 그 변경이 _onQueryChanged 를
    // 깨워 방금 비운 목록을 다시 열고 검색을 한 번 더 내보낸다
    _controller.text = hub.name;
    _controller.selection = TextSelection.collapsed(offset: hub.name.length);
    // 리스너가 걸어 둔 디바운스·요청까지 걷어낸 뒤에 상태를 확정한다
    _debounceTimer?.cancel();
    _inFlight?.cancel();
    setState(() {
      _selected = hub;
      _results = const [];
      _searching = false;
    });
  }

  void _clear() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _next() {
    ref.read(courseWizardProvider.notifier).selectOrigin(_selected!);
    context.push(AppRoutes.wizardDateGate);
  }

  @override
  Widget build(BuildContext context) {
    // 포커스가 아니라 실제 키보드 높이로 가른다 — 하드웨어 키보드나 포커스만
    // 있고 키보드가 내려간 경우에 안내를 접을 이유가 없다
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardUp = keyboardInset > 0;
    final screenH = MediaQuery.sizeOf(context).height;
    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      // 키보드 밖을 누르면 내린다 (시안 노트). 목록 항목·입력칸은 자기 탭을
      // 먼저 먹으므로 여기까지 오지 않는다 — opaque 라야 빈 곳도 잡힌다
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focusNode.unfocus,
        child: SafeArea(
          // 목록은 Column 위층에 띄운다 — Column 안에 두면 '다음' 버튼 위에서
          // 끊긴다. 시안(1730:40493)은 버튼을 덮고 키보드까지 내려간다
          child: Stack(
            children: [
              // 평소에는 화면을 꽉 채워 '다음' 이 아래에 붙고, 자리가 모자라면
              // (작은 화면 + 키보드) 스크롤된다 — 넘쳐서 잘리는 것을 막는다
              LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Column(
                      children: [
                        _buildTopBar(context),
                        // 키보드가 올라오면 이 여백만 24 로 줄어든다 (시안 1730:40132).
                        //
                        // 화면이 키보드 높이만큼 줄어드는데 위쪽은 전부 고정 크기라, 그
                        // 손실을 목록이 혼자 떠안는다. iPhone 15 Pro 에서는 목록이 **아예
                        // 0** 이었다 — 검색은 되는데 고를 수가 없었다.
                        //
                        // 안내를 지우지는 않는다. 아이콘·제목·부제는 그대로 두고 여백만
                        // 43 을 내놓는 것이 시안이 고른 답이다
                        // 자리가 모자라면 안내부터 줄인다 — 작은 화면(SE)에 키보드가
                        // 올라오면 고정 높이만으로 화면을 넘겼다. 입력칸과 목록은
                        // 끝까지 온전해야 하므로 이 묶음만 스크롤에 둔다
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: SizedBox(
                            height: keyboardUp
                                ? _topGapWithKeyboard
                                : kWizardTopGap,
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/icons/ic_building_blue.svg',
                          width: 48,
                          height: 48,
                        ),
                        // 시안 측정값 — 아이콘과 질문 사이 20
                        const SizedBox(height: 20),
                        Text(
                          '출발지를 입력해주세요',
                          textAlign: TextAlign.center,
                          style: AppTypography.title3Bold.copyWith(
                            color: AppColors.labelNormal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '출발지부터 이동 시간을 고려해\n여행지를 추천해드려요.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body1NormalMedium.copyWith(
                            color: AppColors.labelAlternative,
                          ),
                        ),
                        // 시안 측정값 — 부제(88) 아래 입력칸까지 33
                        const SizedBox(height: 33),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _fieldSideMargin,
                          ),
                          // 목록이 붙을 자리는 여백 **안쪽** 입력칸이다.
                          // 바깥에 두면 목록이 좌우 여백만큼 밀린다
                          child: CompositedTransformTarget(
                            link: _fieldLink,
                            child: _buildField(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 버튼은 늘 화면 아래에 붙는다 — Column 안에 Spacer 로 밀면
              // 스크롤이 걸릴 때 flex 를 못 써 터진다. 목록과 같은 Stack 에
              // 두되 먼저 그려, 목록이 이 위를 덮을 수 있게 한다
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selected == null ? null : _next,
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
                      child: Text('다음', style: AppTypography.body1NormalBold),
                    ),
                  ),
                ),
              ),
              // 입력칸 아래 8 에 **붙어** 따라다닌다. 좌표를 재서 짚으면
              // 키보드가 오르내릴 때 한 박자 늦어 입력칸과 겹친다
              // 목록은 입력칸 아래 8 에 **붙어** 따라다닌다. 좌표를 재서
              // 짚으면 키보드가 오르내릴 때 한 박자 늦어 입력칸과 겹친다.
              //
              // 좌우는 Positioned 로 입력칸과 같은 값을 준다 — Follower 에
              // 폭을 계산해 넘기면 소수점·테두리에서 1~2 어긋난다
              if (_results.isNotEmpty || _searching)
                Positioned(
                  left: _fieldSideMargin,
                  right: _fieldSideMargin,
                  top: 0,
                  bottom: 0,
                  child: CompositedTransformFollower(
                    link: _fieldLink,
                    targetAnchor: Alignment.bottomLeft,
                    followerAnchor: Alignment.topLeft,
                    offset: const Offset(0, 8),
                    // Follower 는 부모 제약을 받지 않아 스스로 막지 않으면
                    // 목록이 키보드 밖으로 넘어간다. 입력칸 위쪽은 전부
                    // 고정값이라 그 합으로 남은 자리를 짚는다
                    child: _buildSuggestions(
                      maxHeight:
                          screenH -
                          keyboardInset -
                          topPad -
                          (44 +
                              (keyboardUp
                                  ? _topGapWithKeyboard
                                  : kWizardTopGap) +
                              48 +
                              20 +
                              32 +
                              8 +
                              48 +
                              33 +
                              48 +
                              8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 335×48 · radius 12. 글자가 있으면 지우기, 없으면 돋보기 (시안 세 장)
  Widget _buildField() {
    final hasText = _controller.text.isNotEmpty;
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        style: AppTypography.body1NormalRegular.copyWith(
          color: AppColors.labelNormal,
        ),
        decoration: InputDecoration(
          hintText: '어디서 출발할까요?',
          hintStyle: AppTypography.body1NormalRegular.copyWith(
            color: AppColors.labelAssistive,
          ),
          filled: true,
          fillColor: AppColors.backgroundNormal,
          isDense: true,
          // 시안은 글자가 테두리에서 16 에 선다. TextField 가 자체 여백을
          // 더해 16 을 그대로 주면 21 에서 시작한다(실측)
          contentPadding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          suffixIcon: hasText
              ? IconButton(
                  onPressed: _clear,
                  tooltip: '지우기',
                  // 에셋의 fill-opacity 가 이미 시안 농도(#37383C 28%)다 —
                  // 반투명 토큰을 srcIn 으로 씌우면 두 값이 곱해진다(#226)
                  icon: SvgPicture.asset(
                    'assets/icons/ic_circle_close.svg',
                    width: 22,
                    height: 22,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(13),
                  // 같은 이유로 필터를 씌우지 않는다 — 에셋이 #37383C 61%다
                  child: SvgPicture.asset(
                    'assets/icons/ic_search.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
          suffixIconConstraints: const BoxConstraints.tightFor(
            width: 48,
            height: 48,
          ),
          border: _fieldBorder(_fieldBorderColor),
          enabledBorder: _fieldBorder(_fieldBorderColor),
          focusedBorder: _fieldBorder(AppColors.primaryNormal),
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );

  /// 자동완성 목록 — radius 16, 최대 높이 404 (시안 실측 y 411~814).
  ///
  /// [maxHeight] 는 입력칸 아래로 남은 자리다. Follower 는 부모 제약을 받지
  /// 않아 스스로 막지 않으면 키보드 위로 넘어간다
  Widget _buildSuggestions({required double maxHeight}) {
    // Align 을 씌우면 자식이 느슨한 제약을 받아 폭이 내용만큼 줄어든다 —
    // 입력칸과 좌우가 어긋난다
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight < 404 ? maxHeight : 404),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            // 배경을 여기서 칠한다. Material 에만 색을 주면 이 Container 의
            // decoration 이 위를 덮어 회색 판이 된다
            color: AppColors.backgroundElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lineSolidNeutral),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F171717),
                offset: Offset(0, 4),
                blurRadius: 6,
                spreadRadius: -1,
              ),
              BoxShadow(
                color: Color(0x0F171717),
                offset: Offset(0, 2),
                blurRadius: 4,
                spreadRadius: -2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _results.isEmpty
              // 찾는 동안 빈 판을 띄우면 '결과 없음' 처럼 보인다
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : ListView.builder(
                  // 시안 실측 — 테두리에서 첫 글자까지 21
                  // (이 6 + 셀 세로패딩 10 + 글자 여백 5)
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, i) => _buildCell(_results[i]),
                ),
        ),
      ),
    );
  }

  /// 친 부분은 굵게, 나머지는 옅게 (시안 '작성영역/자동완성영역')
  ///
  /// **검색어가 이름 가운데 있어도 굵게 한다.** '충주' 를 치면 서충주터미널·
  /// 건국대(충주)터미널도 함께 오는데, 앞자리만 보면 이 둘은 통째로 옅어져
  /// 왜 걸렸는지 알 수 없는 줄이 된다
  Widget _buildCell(OriginHub hub) {
    final typed = _controller.text.trim();
    final at = typed.isEmpty
        ? -1
        : hub.name.toLowerCase().indexOf(typed.toLowerCase());
    final spans = at < 0
        // 서버가 별칭·구두점으로 찾아 준 경우다 — 굵게 할 자리가 없다
        ? [_plain(hub.name)]
        : [
            if (at > 0) _plain(hub.name.substring(0, at)),
            _strong(hub.name.substring(at, at + typed.length)),
            if (at + typed.length < hub.name.length)
              _plain(hub.name.substring(at + typed.length)),
          ];
    return InkWell(
      onTap: () => _choose(hub),
      child: Padding(
        // 시안 실측 — 셀 간격 44, 글자는 목록 테두리에서 15
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                TextSpan(children: spans),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _strong(String text) => TextSpan(
    text: text,
    style: AppTypography.body1NormalBold.copyWith(color: AppColors.labelNormal),
  );

  TextSpan _plain(String text) => TextSpan(
    text: text,
    style: AppTypography.body1NormalRegular.copyWith(
      color: AppColors.labelAlternative,
    ),
  );

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      // 버튼이 아이콘보다 넓으므로 좌측 여백을 줄여 아이콘 위치를 맞춘다
      padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
      child: Row(
        children: [
          AppBackButton(
            onTap: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.home),
          ),
          const Spacer(),
          Text(
            '1/5',
            style: AppTypography.body1NormalBold.copyWith(
              color: AppColors.labelAssistive,
            ),
          ),
        ],
      ),
    );
  }
}
