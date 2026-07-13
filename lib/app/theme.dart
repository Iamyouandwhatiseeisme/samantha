import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _mono = 'monospace';
  static const _sans = null;

  static const Duration motionShort = Duration(milliseconds: 200);
  static const Duration motionMed = Duration(milliseconds: 300);
  static const Duration motionLong = Duration(milliseconds: 400);

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  static const Color accent = Color(0xFFF97316);
  static const Color accentDim = Color(0xFFB45309);
  static const Color successAdd = Color(0xFF22C55E);
  static const Color errorRemove = Color(0xFFEF4444);

  static ThemeData dark() {
    final scheme = const ColorScheme.dark(
      surface: Color(0xFF0B0B0D),
      onSurface: Color(0xFFE4E4E7),
      surfaceContainerLowest: Color(0xFF08080A),
      surfaceContainerLow: Color(0xFF111114),
      surfaceContainer: Color(0xFF16161A),
      surfaceContainerHigh: Color(0xFF1E1E24),
      surfaceContainerHighest: Color(0xFF26262E),
      onSurfaceVariant: Color(0xFF71717A),
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF331C0A),
      onPrimaryContainer: Color(0xFFFED7AA),
      secondary: Color(0xFF8B8B96),
      onSecondary: Color(0xFF16161A),
      secondaryContainer: Color(0xFF1E1E24),
      onSecondaryContainer: Color(0xFFA1A1AA),
      tertiary: Color(0xFF22D3EE),
      onTertiary: Color(0xFF16161A),
      tertiaryContainer: Color(0xFF083344),
      onTertiaryContainer: Color(0xFF67E8F9),
      error: errorRemove,
      onError: Colors.white,
      errorContainer: Color(0xFF450A0A),
      onErrorContainer: Color(0xFFFCA5A5),
      outline: Color(0xFF3F3F46),
      outlineVariant: Color(0xFF27272A),
      scrim: Color(0xFF000000),
    );

    return _base(scheme, Brightness.dark);
  }

  static ThemeData light() {
    final scheme = const ColorScheme.light(
      surface: Color(0xFFFAFAFA),
      onSurface: Color(0xFF18181B),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF4F4F5),
      surfaceContainer: Color(0xFFE4E4E7),
      surfaceContainerHigh: Color(0xFFD4D4D8),
      surfaceContainerHighest: Color(0xFFA1A1AA),
      onSurfaceVariant: Color(0xFF52525B),
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFEDD5),
      onPrimaryContainer: Color(0xFF7C2D12),
      secondary: Color(0xFF52525B),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE4E4E7),
      onSecondaryContainer: Color(0xFF3F3F46),
      tertiary: Color(0xFF0891B2),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFCFFAFE),
      onTertiaryContainer: Color(0xFF164E63),
      error: errorRemove,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      outline: Color(0xFFD4D4D8),
      outlineVariant: Color(0xFFE4E4E7),
      scrim: Color(0xFF000000),
    );

    return _base(scheme, Brightness.light);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      brightness: brightness,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,

      textTheme: TextTheme(
        bodyLarge: TextStyle(fontFamily: _sans, fontSize: 15, height: 1.5, color: scheme.onSurface),
        bodyMedium: TextStyle(fontFamily: _sans, fontSize: 14, height: 1.5, color: scheme.onSurface),
        bodySmall: TextStyle(fontFamily: _sans, fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
        labelLarge: TextStyle(fontFamily: _sans, fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
        labelMedium: TextStyle(fontFamily: _sans, fontSize: 11, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
        labelSmall: TextStyle(fontFamily: _mono, fontSize: 10, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
        titleLarge: TextStyle(fontFamily: _sans, fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurface),
        titleMedium: TextStyle(fontFamily: _sans, fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
        titleSmall: TextStyle(fontFamily: _sans, fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 0.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: TextStyle(fontFamily: _sans, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: TextStyle(fontFamily: _sans, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          iconSize: 20,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(fontFamily: _sans, fontSize: 13, color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        modalBackgroundColor: scheme.surfaceContainer,
        modalBarrierColor: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outline,
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: Colors.transparent,
      ),

      extensions: <ThemeExtension<dynamic>>[
        AppColors(
          accent: scheme.primary,
          accentDim: accentDim,
          agentSurface: isDark ? const Color(0xFF111114) : const Color(0xFFF4F4F5),
          agentBorder: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          userSurface: isDark ? const Color(0xFF331C0A) : const Color(0xFFFFEDD5),
          userBorder: isDark ? const Color(0xFF7C2D12) : const Color(0xFFFDBA74),
          codeSurface: isDark ? const Color(0xFF08080A) : const Color(0xFFFFFFFF),
          codeBorder: isDark ? const Color(0xFF1E1E24) : const Color(0xFFE4E4E7),
          diffAdd: successAdd,
          diffAddBg: isDark ? const Color(0xFF0D2818) : const Color(0xFFDCFCE7),
          diffRemove: errorRemove,
          diffRemoveBg: isDark ? const Color(0xFF2A0808) : const Color(0xFFFEE2E2),
          success: successAdd,
          error: errorRemove,
          mono: _mono,
        ),
      ],
    );
  }
}

class AppColors extends ThemeExtension<AppColors> {
  final Color accent;
  final Color accentDim;
  final Color agentSurface;
  final Color agentBorder;
  final Color userSurface;
  final Color userBorder;
  final Color codeSurface;
  final Color codeBorder;
  final Color diffAdd;
  final Color diffAddBg;
  final Color diffRemove;
  final Color diffRemoveBg;
  final Color success;
  final Color error;
  final String mono;

  const AppColors({
    required this.accent,
    required this.accentDim,
    required this.agentSurface,
    required this.agentBorder,
    required this.userSurface,
    required this.userBorder,
    required this.codeSurface,
    required this.codeBorder,
    required this.diffAdd,
    required this.diffAddBg,
    required this.diffRemove,
    required this.diffRemoveBg,
    required this.success,
    required this.error,
    required this.mono,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? accent,
    Color? accentDim,
    Color? agentSurface,
    Color? agentBorder,
    Color? userSurface,
    Color? userBorder,
    Color? codeSurface,
    Color? codeBorder,
    Color? diffAdd,
    Color? diffAddBg,
    Color? diffRemove,
    Color? diffRemoveBg,
    Color? success,
    Color? error,
    String? mono,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      accentDim: accentDim ?? this.accentDim,
      agentSurface: agentSurface ?? this.agentSurface,
      agentBorder: agentBorder ?? this.agentBorder,
      userSurface: userSurface ?? this.userSurface,
      userBorder: userBorder ?? this.userBorder,
      codeSurface: codeSurface ?? this.codeSurface,
      codeBorder: codeBorder ?? this.codeBorder,
      diffAdd: diffAdd ?? this.diffAdd,
      diffAddBg: diffAddBg ?? this.diffAddBg,
      diffRemove: diffRemove ?? this.diffRemove,
      diffRemoveBg: diffRemoveBg ?? this.diffRemoveBg,
      success: success ?? this.success,
      error: error ?? this.error,
      mono: mono ?? this.mono,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      agentSurface: Color.lerp(agentSurface, other.agentSurface, t)!,
      agentBorder: Color.lerp(agentBorder, other.agentBorder, t)!,
      userSurface: Color.lerp(userSurface, other.userSurface, t)!,
      userBorder: Color.lerp(userBorder, other.userBorder, t)!,
      codeSurface: Color.lerp(codeSurface, other.codeSurface, t)!,
      codeBorder: Color.lerp(codeBorder, other.codeBorder, t)!,
      diffAdd: Color.lerp(diffAdd, other.diffAdd, t)!,
      diffAddBg: Color.lerp(diffAddBg, other.diffAddBg, t)!,
      diffRemove: Color.lerp(diffRemove, other.diffRemove, t)!,
      diffRemoveBg: Color.lerp(diffRemoveBg, other.diffRemoveBg, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      mono: other.mono,
    );
  }
}
