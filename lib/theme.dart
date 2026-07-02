import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Closr brand color palette.
///
/// All colors are exposed as `static const Color` so screens can use
/// `ClosrColors.ember` directly without needing a [BuildContext].
class ClosrColors {
  ClosrColors._();

  // ─── Light theme ──────────────────────────────────────────────────────────
  static const Color ember = Color(0xFFEA7A5C); // primary / CTA (coral)
  static const Color emberSoft = Color(0xFFEFCAB4); // soft surfaces
  static const Color paper = Color(0xFFFAF6F0); // background (off-white)
  static const Color cream = Color(0xFFF2EBE0); // card surfaces
  static const Color ink = Color(0xFF2A211C); // primary text (warm brown)
  static const Color plum = Color(0xFF3B2433); // depth / dark (aubergine)
  static const Color muted = Color(0xFF877366); // secondary text
  static const Color line = Color(0xFFE5D8CC); // borders / dividers
  static const Color rose = Color(0xFFE05A72); // errors / alerts
  static const Color green = Color(0xFF1F8A5B); // online

  // ─── Dark theme ───────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF231019); // darkest plum
  static const Color darkSurface = Color(0xFF3B2433); // plum cards
  static const Color darkSurfaceElevated = Color(0xFF4A2E40);
  static const Color darkText = Color(0xFFFAF6F0); // paper
  static const Color darkTextMuted = Color(0xFFC0A898);
  static const Color darkBorder = Color(0xFF4D2E3C);
}

/// Closr design system themes.
class ClosrTheme {
  ClosrTheme._();

  static const _pillRadius = 999.0;
  static const _cardRadius = 20.0;
  static const _inputRadius = 999.0;

  // ─── LIGHT ──────────────────────────────────────────────────────────────
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: ClosrColors.ember,
      onPrimary: ClosrColors.paper,
      primaryContainer: ClosrColors.emberSoft,
      onPrimaryContainer: ClosrColors.ink,
      secondary: ClosrColors.plum,
      onSecondary: ClosrColors.paper,
      surface: ClosrColors.cream,
      onSurface: ClosrColors.ink,
      surfaceContainerHighest: ClosrColors.paper,
      onSurfaceVariant: ClosrColors.muted,
      background: ClosrColors.paper,
      onBackground: ClosrColors.ink,
      error: ClosrColors.rose,
      onError: ClosrColors.paper,
      outline: ClosrColors.line,
    );

    final textTheme = _textTheme(ClosrColors.ink, ClosrColors.muted);

    return _base(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackground: ClosrColors.paper,
      appBarBg: ClosrColors.paper,
      appBarFg: ClosrColors.ink,
      cardColor: ClosrColors.cream,
      inputFill: ClosrColors.cream,
      inputHint: ClosrColors.muted,
      secondaryButtonColor: ClosrColors.ink,
      secondaryButtonText: ClosrColors.paper,
      ghostBorder: ClosrColors.ink,
      bottomNavBg: ClosrColors.paper,
      dividerColor: ClosrColors.line,
      chipBg: ClosrColors.cream,
      brightness: Brightness.light,
    );
  }

  // ─── DARK ───────────────────────────────────────────────────────────────
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ClosrColors.ember,
      onPrimary: ClosrColors.paper,
      primaryContainer: ClosrColors.darkSurfaceElevated,
      onPrimaryContainer: ClosrColors.darkText,
      secondary: ClosrColors.emberSoft,
      onSecondary: ClosrColors.ink,
      surface: ClosrColors.darkSurface,
      onSurface: ClosrColors.darkText,
      surfaceContainerHighest: ClosrColors.darkSurfaceElevated,
      onSurfaceVariant: ClosrColors.darkTextMuted,
      background: ClosrColors.darkBackground,
      onBackground: ClosrColors.darkText,
      error: ClosrColors.rose,
      onError: ClosrColors.paper,
      outline: ClosrColors.darkBorder,
    );

    final textTheme = _textTheme(ClosrColors.darkText, ClosrColors.darkTextMuted);

    return _base(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackground: ClosrColors.darkBackground,
      appBarBg: ClosrColors.darkBackground,
      appBarFg: ClosrColors.darkText,
      cardColor: ClosrColors.darkSurface,
      inputFill: ClosrColors.darkSurface,
      inputHint: ClosrColors.darkTextMuted,
      secondaryButtonColor: ClosrColors.darkText,
      secondaryButtonText: ClosrColors.ink,
      ghostBorder: ClosrColors.darkText,
      bottomNavBg: ClosrColors.darkBackground,
      dividerColor: ClosrColors.darkBorder,
      chipBg: ClosrColors.darkSurface,
      brightness: Brightness.dark,
    );
  }

  // ─── Shared builder ───────────────────────────────────────────────────────
  static ThemeData _base({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required Color scaffoldBackground,
    required Color appBarBg,
    required Color appBarFg,
    required Color cardColor,
    required Color inputFill,
    required Color inputHint,
    required Color secondaryButtonColor,
    required Color secondaryButtonText,
    required Color ghostBorder,
    required Color bottomNavBg,
    required Color dividerColor,
    required Color chipBg,
    required Brightness brightness,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      primaryColor: ClosrColors.ember,

      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: appBarFg,
          letterSpacing: -0.02 * 18,
        ),
        iconTheme: IconThemeData(color: appBarFg),
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ClosrColors.ember,
          foregroundColor: ClosrColors.paper,
          disabledBackgroundColor: ClosrColors.emberSoft,
          disabledForegroundColor: ClosrColors.paper,
          elevation: 0,
          shadowColor: ClosrColors.ember.withAlpha(90),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_pillRadius),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.01 * 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ghostBorder,
          side: BorderSide(color: ghostBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_pillRadius),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ClosrColors.ember,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ClosrColors.ember,
        foregroundColor: ClosrColors.paper,
        elevation: 2,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: GoogleFonts.poppins(color: inputHint, fontWeight: FontWeight.w400),
        labelStyle: GoogleFonts.poppins(color: inputHint, fontWeight: FontWeight.w500),
        floatingLabelStyle: GoogleFonts.poppins(color: ClosrColors.ember, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: const BorderSide(color: ClosrColors.ember, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: const BorderSide(color: ClosrColors.rose, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: const BorderSide(color: ClosrColors.rose, width: 1.5),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomNavBg,
        selectedItemColor: ClosrColors.ember,
        unselectedItemColor: brightness == Brightness.dark
            ? ClosrColors.darkTextMuted
            : ClosrColors.muted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return ClosrColors.paper;
          return brightness == Brightness.dark ? ClosrColors.darkTextMuted : ClosrColors.paper;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return ClosrColors.ember;
          return dividerColor;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: chipBg,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_pillRadius),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ClosrColors.ember,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scaffoldBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_cardRadius)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ClosrColors.plum,
        contentTextStyle: GoogleFonts.poppins(color: ClosrColors.paper, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: brightness == Brightness.dark
            ? ClosrColors.darkTextMuted
            : ClosrColors.muted,
      ),
    );
  }

  // ─── Typography ─────────────────────────────────────────────────────────
  static TextTheme _textTheme(Color textColor, Color mutedColor) {
    final base = GoogleFonts.poppinsTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: -0.04 * 57, color: textColor),
      displayMedium: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: -0.04 * 45, color: textColor),
      displaySmall: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: -0.03 * 36, color: textColor),
      headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: -0.03 * 32, color: textColor),
      headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: -0.03 * 28, color: textColor),
      headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: -0.02 * 24, color: textColor),
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: -0.02 * 22, color: textColor),
      titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor),
      titleSmall: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: textColor),
      bodyLarge: GoogleFonts.poppins(fontWeight: FontWeight.w400, color: textColor),
      bodyMedium: GoogleFonts.poppins(fontWeight: FontWeight.w400, color: textColor),
      bodySmall: GoogleFonts.poppins(fontWeight: FontWeight.w400, color: mutedColor),
      labelLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor),
      labelMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: 0.14 * 12, color: mutedColor),
      labelSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: 0.14 * 11, color: mutedColor),
    );
  }
}

/// A reusable Closr logo mark: a speech bubble with two dots.
class ClosrLogoMark extends StatelessWidget {
  final double size;
  final Color? bubbleColor;
  final Color? dotColor;

  const ClosrLogoMark({
    Key? key,
    this.size = 64,
    this.bubbleColor,
    this.dotColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = bubbleColor ?? ClosrColors.ember;
    final dots = dotColor ?? ClosrColors.paper;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size * 0.34),
          topRight: Radius.circular(size * 0.34),
          bottomRight: Radius.circular(size * 0.34),
          bottomLeft: Radius.circular(size * 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: bg.withAlpha(90),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dot(dots, size),
          SizedBox(width: size * 0.12),
          _dot(dots, size),
        ],
      ),
    );
  }

  Widget _dot(Color color, double size) => Container(
        width: size * 0.14,
        height: size * 0.14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
