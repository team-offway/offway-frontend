/// 디자인 시스템 토큰 모음.
///
/// 화면에서는 이 파일 하나만 import 한다.
/// ```dart
/// import 'package:offway/core/theme/tokens/tokens.dart';
///
/// Text('제목', style: TextStyle(color: AppColors.labelNormal));
/// ```
///
/// - [AppColors] · [AppAccentColors] — 용도별 색 (화면에서 쓰는 것)
/// - [AppPalette] · [AppOpacity] — 원시 팔레트 (Semantic 정의용, 화면에서 직접 쓰지 않음)
library;

export 'color_atomic.dart';
export 'color_semantic.dart';
