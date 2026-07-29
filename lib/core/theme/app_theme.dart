import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF2962FF);

  /// 디자인 시스템 본문 서체. 타이포 토큰은 fontFamily를 비워두고 여기서
  /// 한 번만 지정해 앱 전체에 적용한다.
  static const _fontFamily = 'Pretendard';

  static ThemeData get light => _base(Brightness.light);

  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: _fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
    );
  }
}
