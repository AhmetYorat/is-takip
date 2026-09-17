import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// User's theme preference (açık/koyu/sistem), changeable from Profil.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Design tokens generated for this project (Enterprise SaaS / Mobile style):
/// professional blue primary, green "money" accent for tahsilat amounts,
/// card-based surfaces with soft colored shadows, 12pt radii, Lexend for
/// headings and Source Sans 3 for body text. Light and dark are designed
/// together so semantic meaning (amounts, status) stays consistent.
///
/// Access non-Material tokens (accent, success, warning, soft shadow) via
/// `Theme.of(context).extension<AppColors>()!`.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.onAccent,
    required this.accentMuted,
    required this.warning,
    required this.cardShadow,
    required this.badgeAutomatic,
    required this.danger,
    required this.onDanger,
  });

  final Color accent;
  final Color onAccent;
  final Color accentMuted;
  final Color warning;
  final Color cardShadow;
  final Color badgeAutomatic;

  /// Solid "hero" block red (e.g. Toplam Gider card). Fixed across light/dark
  /// so it stays a rich, corporate red instead of `colorScheme.error`, which
  /// is tuned lighter/brighter in dark mode for legible text/icons and reads
  /// as neon when used as a large fill.
  final Color danger;
  final Color onDanger;

  static const light = AppColors(
    accent: Color(0xFF059669),
    onAccent: Color(0xFFFFFFFF),
    accentMuted: Color(0xFFE1F5EE),
    warning: Color(0xFFD97706),
    cardShadow: Color(0x142563EB),
    badgeAutomatic: Color(0xFF7C3AED),
    danger: Color(0xFFDC2626),
    onDanger: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    accent: Color(0xFF34D399),
    onAccent: Color(0xFF042F1E),
    accentMuted: Color(0xFF113328),
    warning: Color(0xFFFBBF24),
    cardShadow: Color(0x33000000),
    badgeAutomatic: Color(0xFFA78BFA),
    danger: Color(0xFFDC2626),
    onDanger: Color(0xFFFFFFFF),
  );

  @override
  AppColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? accentMuted,
    Color? warning,
    Color? cardShadow,
    Color? badgeAutomatic,
    Color? danger,
    Color? onDanger,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentMuted: accentMuted ?? this.accentMuted,
      warning: warning ?? this.warning,
      cardShadow: cardShadow ?? this.cardShadow,
      badgeAutomatic: badgeAutomatic ?? this.badgeAutomatic,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      badgeAutomatic: Color.lerp(badgeAutomatic, other.badgeAutomatic, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
    );
  }
}

/// Shared spacing scale (8dp rhythm) so every screen uses the same gaps.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  AppRadius._();

  static const double card = 12;
  static const double sheet = 20;
  static const double chip = 100; // pill
}

class AppTheme {
  AppTheme._();

  static const _primary = Color(0xFF2563EB);
  static const _secondary = Color(0xFF3B82F6);
  static const _destructive = Color(0xFFDC2626);

  static ThemeData light() {
    const background = Color(0xFFF8FAFC);
    const foreground = Color(0xFF0F172A);
    const muted = Color(0xFFF1F5FD);
    const border = Color(0xFFE4ECFC);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      primary: _primary,
      secondary: _secondary,
      error: _destructive,
      surface: Colors.white,
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackground: background,
      cardColor: Colors.white,
      foreground: foreground,
      muted: muted,
      border: border,
      extension: AppColors.light,
    );
  }

  static ThemeData dark() {
    const background = Color(0xFF0B1220);
    const foreground = Color(0xFFE2E8F0);
    const muted = Color(0xFF16213A);
    const border = Color(0xFF243149);
    const surface = Color(0xFF121A2C);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
      primary: const Color(0xFF60A5FA),
      secondary: const Color(0xFF93C5FD),
      error: const Color(0xFFF87171),
      surface: surface,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackground: background,
      cardColor: surface,
      foreground: foreground,
      muted: muted,
      border: border,
      extension: AppColors.dark,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color foreground,
    required Color muted,
    required Color border,
    required AppColors extension,
  }) {
    final baseTextTheme = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;

    final textTheme = GoogleFonts.sourceSans3TextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.lexend(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
      headlineMedium: GoogleFonts.lexend(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
      headlineSmall: GoogleFonts.lexend(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      titleLarge: GoogleFonts.lexend(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      titleMedium: GoogleFonts.lexend(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      bodyLarge: GoogleFonts.sourceSans3(fontSize: 16, color: foreground),
      bodyMedium: GoogleFonts.sourceSans3(fontSize: 14, color: foreground),
      labelLarge: GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      extensions: [extension],
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.lexend(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          textStyle: GoogleFonts.sourceSans3(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: extension.accent,
        foregroundColor: extension.onAccent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: muted,
        labelStyle: GoogleFonts.sourceSans3(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        side: BorderSide.none,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.sourceSans3(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? colorScheme.primary
                : foreground.withValues(alpha: 0.6),
          );
        }),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
