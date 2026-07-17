import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Closr brand color palette — 1:1 mirror of the Figma "Semantic" variable
/// collection (file Closr-app). Each token's usage follows the Figma
/// variable description.
///
/// All colors are exposed as `static const Color` so screens can use
/// `ClosrColors.ember` directly without needing a [BuildContext].
class ClosrColors {
  ClosrColors._();

  // ─── Light mode (Figma Semantic / Light) ─────────────────────────────────
  /// color/action/default — Primary buttons, CTAs (ember/500)
  static const Color ember = Color(0xFFED784E);

  /// color/action/hover — Hover/pressed state of CTAs (ember/600)
  static const Color emberHover = Color(0xFFD25E3A);

  /// color/action/subtle — Light backgrounds, premium badges (ember/300)
  static const Color emberSoft = Color(0xFFF8C4AA);

  /// color/bg/page — Main background of light screens (neutral/20)
  static const Color paper = Color(0xFFFEFBF7);

  /// color/bg/surface — Cards, alternating sections (neutral/100)
  static const Color surface = Color(0xFFF5EBDF);

  /// color/white — grouped cards, inputs, incoming bubbles
  static const Color card = Color(0xFFFFFFFF);

  /// color/text/primary — Primary text, headings (neutral/900)
  static const Color ink = Color(0xFF261915);

  /// color/text/muted — Secondary text, captions (neutral/500)
  static const Color muted = Color(0xFF76645E);

  /// color/border/default — Dividers, card outlines (neutral/200)
  static const Color line = Color(0xFFE1D9D3);

  /// Hairline separators inside grouped cards (iOS kit Separators/Vibrant)
  static const Color separator = Color(0xFFE6E6E6);

  /// color/depth/surface — Premium dark sections, locked messages (plum/700)
  static const Color plum = Color(0xFF441B30);

  /// color/feedback/alert — Errors, likes, one-off alerts (rose/500)
  static const Color rose = Color(0xFFEC7090);

  /// Online status (not in Figma variables — UI kit "ONLINE" label)
  static const Color green = Color(0xFF1F8A5B);

  /// Shadows/shadow-xs — cards and small floating elements (light mode only)
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0D101828), offset: Offset(0, 1), blurRadius: 2),
  ];

  // ─── Dark mode (Figma Semantic / Dark) ───────────────────────────────────
  /// color/bg/page (Dark)
  static const Color darkBackground = Color(0xFF231019);

  /// color/bg/surface (Dark) — cards, inputs
  static const Color darkSurface = Color(0xFF3B2433);

  /// color/depth/surface (Dark) — elevated surfaces
  static const Color darkSurfaceElevated = Color(0xFF4A2E40);

  /// color/text/primary (Dark)
  static const Color darkText = Color(0xFFFAF6F0);

  /// color/text/muted (Dark)
  static const Color darkTextMuted = Color(0xFFC0A898);

  /// color/border/default (Dark)
  static const Color darkBorder = Color(0xFF4D2E3C);

  /// Hairline separators (Dark)
  static const Color darkSeparator = Color(0xFF55384A);

  /// color/action/subtle (Dark) — premium badges, disabled CTAs
  static const Color darkEmberSubtle = Color(0xFF5C3226);
}

/// Closr design system themes.
class ClosrTheme {
  ClosrTheme._();

  static const _pillRadius = 999.0;
  static const _cardRadius = 16.0;
  static const _inputRadius = 999.0;

  // ─── LIGHT ──────────────────────────────────────────────────────────────
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: ClosrColors.ember,
      onPrimary: Colors.white,
      primaryContainer: ClosrColors.emberSoft,
      onPrimaryContainer: ClosrColors.ink,
      secondary: ClosrColors.plum,
      onSecondary: Colors.white,
      surface: ClosrColors.card,
      onSurface: ClosrColors.ink,
      surfaceContainerHighest: ClosrColors.surface,
      onSurfaceVariant: ClosrColors.muted,
      error: ClosrColors.rose,
      onError: Colors.white,
      outline: ClosrColors.line,
    );

    final textTheme = _textTheme(ClosrColors.ink, ClosrColors.muted);

    return _base(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackground: ClosrColors.paper,
      appBarBg: ClosrColors.paper,
      appBarFg: ClosrColors.ink,
      cardColor: ClosrColors.card,
      cardBorder: ClosrColors.line,
      inputFill: ClosrColors.card,
      inputBorder: ClosrColors.line,
      inputHint: ClosrColors.muted,
      disabledButtonBg: ClosrColors.emberSoft,
      buttonBorder: ClosrColors.emberSoft,
      outlinedFill: ClosrColors.card,
      separatorColor: ClosrColors.separator,
      chipBg: ClosrColors.card,
      snackBg: ClosrColors.ink,
      snackFg: ClosrColors.paper,
      brightness: Brightness.light,
    );
  }

  // ─── DARK ───────────────────────────────────────────────────────────────
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ClosrColors.ember,
      onPrimary: Colors.white,
      primaryContainer: ClosrColors.darkEmberSubtle,
      onPrimaryContainer: ClosrColors.darkText,
      secondary: ClosrColors.emberSoft,
      onSecondary: ClosrColors.ink,
      surface: ClosrColors.darkSurface,
      onSurface: ClosrColors.darkText,
      surfaceContainerHighest: ClosrColors.darkSurfaceElevated,
      onSurfaceVariant: ClosrColors.darkTextMuted,
      error: ClosrColors.rose,
      onError: Colors.white,
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
      cardBorder: ClosrColors.darkBorder,
      inputFill: ClosrColors.darkSurface,
      inputBorder: ClosrColors.darkBorder,
      inputHint: ClosrColors.darkTextMuted,
      disabledButtonBg: ClosrColors.darkEmberSubtle,
      buttonBorder: ClosrColors.darkEmberSubtle,
      outlinedFill: ClosrColors.darkSurface,
      separatorColor: ClosrColors.darkSeparator,
      chipBg: ClosrColors.darkSurface,
      snackBg: ClosrColors.darkSurfaceElevated,
      snackFg: ClosrColors.darkText,
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
    required Color cardBorder,
    required Color inputFill,
    required Color inputBorder,
    required Color inputHint,
    required Color disabledButtonBg,
    required Color buttonBorder,
    required Color outlinedFill,
    required Color separatorColor,
    required Color chipBg,
    required Color snackBg,
    required Color snackFg,
    required Brightness brightness,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      primaryColor: ClosrColors.ember,
      // Figma sizes are exact px. Flutter's default adaptivePlatformDensity
      // shrinks tappable controls on web/desktop below their intrinsic
      // padding-derived size — pin it to standard so buttons/inputs render
      // at the spec'd height instead of a compacted one.
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: appBarFg,
        ),
        iconTheme: IconThemeData(color: appBarFg),
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(color: cardBorder, width: 1),
        ),
      ),

      // Figma "Button": px-16 py-10 → 42px pill, 1px action/subtle stroke,
      // no shadow. action/hover drives the hovered/pressed overlay only.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ClosrColors.ember,
          foregroundColor: Colors.white,
          disabledBackgroundColor: disabledButtonBg,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide(color: buttonBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_pillRadius),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 20 / 15,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return ClosrColors.emberHover.withAlpha(90);
            }
            return null;
          }),
        ),
      ),

      // Figma ghost button ("View wallet"): white bg, action/subtle stroke,
      // ember text, same 42px pill metrics, no shadow.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClosrColors.ember,
          backgroundColor: outlinedFill,
          side: BorderSide(color: buttonBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_pillRadius),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 20 / 15,
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
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      // Figma "Input": 42px tall, white fill, border/default stroke, pl-18.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: GoogleFonts.poppins(color: inputHint, fontWeight: FontWeight.w400, fontSize: 14),
        labelStyle: GoogleFonts.poppins(color: inputHint, fontWeight: FontWeight.w400, fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: inputBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: inputBorder, width: 1),
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
        backgroundColor: scaffoldBackground,
        selectedItemColor: ClosrColors.ember,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return brightness == Brightness.dark ? ClosrColors.darkTextMuted : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return ClosrColors.ember;
          return brightness == Brightness.dark ? ClosrColors.darkBorder : ClosrColors.line;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      dividerTheme: DividerThemeData(
        color: separatorColor,
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
        side: BorderSide(color: cardBorder, width: 1),
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
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: GoogleFonts.poppins(color: snackFg, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ─── Typography (Figma text styles, all Poppins) ─────────────────────────
  //  Heading      → headlineLarge  34/w600/lh1.1
  //  Body large   → titleMedium    17/w600
  //  Body         → bodyMedium     14/w400/lh1.23
  //  Button text  → labelLarge     15/w600/lh1.33
  //  Menu item    → titleSmall     14/w500
  //  Meta uppercase (time labels, ONLINE) → labelSmall 11/w600/ls+0.8
  static TextTheme _textTheme(Color textColor, Color mutedColor) {
    final base = GoogleFonts.poppinsTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: -0.04 * 57, color: textColor),
      displayMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: -0.04 * 45, color: textColor),
      displaySmall: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: -0.03 * 36, color: textColor),
      headlineLarge: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w600, height: 1.1, letterSpacing: -0.5, color: textColor),
      headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: -0.03 * 28, color: textColor),
      headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: -0.02 * 24, color: textColor),
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: -0.02 * 22, color: textColor),
      titleMedium: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: textColor),
      titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
      bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400, color: textColor),
      bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, height: 1.23, color: textColor),
      bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: mutedColor),
      labelLarge: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, height: 20 / 15, color: textColor),
      labelMedium: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: mutedColor),
      labelSmall: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: mutedColor),
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
    final dots = dotColor ?? Colors.white;
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
