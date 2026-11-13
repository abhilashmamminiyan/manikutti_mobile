import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Supported Design Theme Styles
enum ThemeStyle { modern, paper }

/// Paper Morph Page Transitions Builder
class PaperMorphPageTransitionsBuilder extends PageTransitionsBuilder {
  const PaperMorphPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeInOutCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
        ),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

/// The Heritage Ledger & Paper Diary Design System
class AppTheme {
  // Current active global theme style
  static ThemeStyle currentStyle = ThemeStyle.modern;

  static bool isPaper(BuildContext context) {
    return currentStyle == ThemeStyle.paper;
  }

  // ==========================================
  // --- Modern (Heritage Teal) Color Tokens ---
  // ==========================================
  static const Color primary = Color(0xFF006972); // Heritage Teal
  static const Color primaryContainer = Color(0xFF68C9D6);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF00535B);

  static const Color secondary = Color(0xFF735C00); // Sunlight Gold
  static const Color secondaryContainer = Color(
    0xFFFDD34D,
  ); // Growth / Warm Milestone
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF725B00);

  static const Color surface = Color(0xFFF8F9FA); // Clean expansive canvas
  static const Color surfaceContainerLow = Color(
    0xFFF3F4F5,
  ); // Grouping / Sectioning
  static const Color surfaceContainer = Color(0xFFEDEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // Pop cards

  static const Color onSurface = Color(
    0xFF191C1D,
  ); // Editorial charcoal (never #000000)
  static const Color onSurfaceVariant = Color(0xFF3E484A);
  static const Color outline = Color(0xFF6F797B);
  static const Color outlineVariant = Color(0xFFBEC8CA);

  static const Color error = Color(0xFFBA1A1A); // Deep sophisticated ruby
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Modern Dark Mode Palette
  static const Color darkBackground = Color(0xFF101314);
  static const Color darkSurface = Color(0xFF191C1D);
  static const Color darkSurfaceContainer = Color(0xFF232728);
  static const Color darkSurfaceContainerLowest = Color(0xFF1D2021);
  static const Color darkOnSurface = Color(0xFFF0F1F2);
  static const Color darkOnSurfaceVariant = Color(0xFFB0B9BA);

  // Backward Compatibility Aliases
  static const Color primaryColor = primary;
  static const Color backgroundColor = surface;
  static const Color darkBackgroundColor = darkBackground;
  static const Color surfaceColor = surface;
  static const Color darkSurfaceColor = darkSurface;
  static const Color onSurfaceColor = onSurface;
  static const Color errorColor = error;

  // ==========================================
  // --- Paper Diary & Fountain Pen Palette ---
  // ==========================================
  static const Color paperSurface = Color(0xFFF8F5EE); // Warm cream stationery
  static const Color paperCard = Color(0xFFFFFDF9); // Crisp lined paper sheet
  static const Color paperContainerLow = Color(
    0xFFF2ECE1,
  ); // Secondary parchment
  static const Color paperRuled = Color(0xFFE2E8F0); // Faint blue ruled line
  static const Color paperMargin = Color(0xFFF09898); // Red vertical margin
  static const Color paperInkNavy = Color(
    0xFF0F2038,
  ); // Fountain pen blue-black ink
  static const Color paperInkSlate = Color(0xFF334155);
  static const Color paperInkMuted = Color(0xFF64748B);
  static const Color paperLeatherDark = Color(
    0xFF3F2110,
  ); // Saddle leather cover
  static const Color paperLeatherMid = Color(0xFF5A3119);
  static const Color paperTabBlue = Color(0xFFBCD7EF); // Thumb index blue
  static const Color paperTabPeach = Color(0xFFF6CEBF); // Thumb index peach
  static const Color paperTabGreen = Color(0xFFC6E6CD); // Thumb index green
  static const Color paperTabPurple = Color(0xFFE2D1E8); // Thumb index lavender
  static const Color paperStampGreen = Color(0xFF1B5E34); // Forest credit stamp
  static const Color paperStampRed = Color(
    0xFFA31D1D,
  ); // Terracotta debit stamp

  // Paper Dark Mode (Midnight Notebook / Sepia Night)
  static const Color paperDarkBackground = Color(0xFF191A1C);
  static const Color paperDarkSurface = Color(0xFF212326);
  static const Color paperDarkCard = Color(0xFF282A2E);
  static const Color paperDarkInk = Color(0xFFE6E8EB);
  static const Color paperDarkMuted = Color(0xFF94A3B8);

  // Ambient Shadows
  static const List<BoxShadow> editorialShadow = [
    BoxShadow(color: Color(0x0F191C1D), blurRadius: 40, offset: Offset(0, 20)),
  ];

  static const List<BoxShadow> ambientCardShadow = [
    BoxShadow(color: Color(0x0D191C1D), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> subtleFloatShadow = [
    BoxShadow(color: Color(0x0A191C1D), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // Paper Diary Card Shadows (Soft, Physical Desk Elevation)
  static const List<BoxShadow> paperCardShadow = [
    BoxShadow(color: Color(0x0A2B1D0E), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x082B1D0E), blurRadius: 2, offset: Offset(0, 1)),
  ];

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF00838F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF006972), Color(0xFF004F56)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGrowthGradient = LinearGradient(
    colors: [Color(0xFFFDD34D), Color(0xFFFFE087)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient leatherGradient = LinearGradient(
    colors: [paperLeatherDark, paperLeatherMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==========================================
  // --- Modern Light Theme ---
  // ==========================================
  static ThemeData get lightTheme {
    final lightBase = ThemeData(brightness: Brightness.light).textTheme;
    final baseInter = GoogleFonts.interTextTheme(lightBase);
    final baseManrope = GoogleFonts.manropeTextTheme(lightBase);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
      ),
      textTheme: baseInter.copyWith(
        displayLarge: baseManrope.displayLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        displayMedium: baseManrope.displayMedium?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displaySmall: baseManrope.displaySmall?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: baseManrope.headlineLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseManrope.headlineMedium?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: baseManrope.headlineSmall?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseManrope.titleLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseManrope.titleMedium?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: baseManrope.titleSmall?.copyWith(
          color: onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseInter.bodyLarge?.copyWith(
          color: onSurface,
          fontSize: 16,
        ),
        bodyMedium: baseInter.bodyMedium?.copyWith(
          color: onSurfaceVariant,
          fontSize: 14,
        ),
        bodySmall: baseInter.bodySmall?.copyWith(
          color: onSurfaceVariant,
          fontSize: 12,
        ),
        labelLarge: baseInter.labelLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelMedium: baseInter.labelMedium?.copyWith(
          color: onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
        labelSmall: baseInter.labelSmall?.copyWith(
          color: onSurfaceVariant,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: GoogleFonts.manrope(
          color: onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outlineVariant.withOpacity(0.2), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: GoogleFonts.inter(
          color: onSurfaceVariant.withOpacity(0.6),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outlineVariant.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outlineVariant.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: onSurfaceVariant,
        textColor: onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariant.withOpacity(0.15),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==========================================
  // --- Modern Dark Theme ---
  // ==========================================
  static ThemeData get darkTheme {
    final darkBase = ThemeData(brightness: Brightness.dark).textTheme;
    final baseInter = GoogleFonts.interTextTheme(darkBase);
    final baseManrope = GoogleFonts.manropeTextTheme(darkBase);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryContainer,
        onPrimary: onPrimaryContainer,
        primaryContainer: primary,
        onPrimaryContainer: onPrimary,
        secondary: Color(0xFFFFE087),
        onSecondary: Color(0xFF3E2E00),
        secondaryContainer: Color(0xFF574500),
        onSecondaryContainer: Color(0xFFFFE087),
        surface: darkSurface,
        onSurface: darkOnSurface,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: Color(0xFF899294),
        outlineVariant: Color(0xFF3F484A),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
      ),
      textTheme: baseInter.copyWith(
        displayLarge: baseManrope.displayLarge?.copyWith(
          color: darkOnSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        displayMedium: baseManrope.displayMedium?.copyWith(
          color: darkOnSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displaySmall: baseManrope.displaySmall?.copyWith(
          color: darkOnSurface,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: baseManrope.headlineLarge?.copyWith(
          color: darkOnSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseManrope.headlineMedium?.copyWith(
          color: darkOnSurface,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: baseManrope.headlineSmall?.copyWith(
          color: darkOnSurface,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseManrope.titleLarge?.copyWith(
          color: darkOnSurface,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseManrope.titleMedium?.copyWith(
          color: darkOnSurface,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: baseManrope.titleSmall?.copyWith(
          color: darkOnSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseInter.bodyLarge?.copyWith(
          color: darkOnSurface,
          fontSize: 16,
        ),
        bodyMedium: baseInter.bodyMedium?.copyWith(
          color: darkOnSurfaceVariant,
          fontSize: 14,
        ),
        bodySmall: baseInter.bodySmall?.copyWith(
          color: darkOnSurfaceVariant,
          fontSize: 12,
        ),
        labelLarge: baseInter.labelLarge?.copyWith(
          color: darkOnSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelMedium: baseInter.labelMedium?.copyWith(
          color: darkOnSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
        labelSmall: baseInter.labelSmall?.copyWith(
          color: darkOnSurfaceVariant,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: darkOnSurface),
        titleTextStyle: GoogleFonts.manrope(
          color: darkOnSurface,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2C3233), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: GoogleFonts.inter(
          color: darkOnSurfaceVariant.withOpacity(0.6),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2C3233)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2C3233)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryContainer, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimaryContainer,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: 'Manrope',
        ),
        contentTextStyle: TextStyle(
          color: darkOnSurfaceVariant,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: darkOnSurfaceVariant,
        textColor: darkOnSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2C3233),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==========================================
  // --- Paper Diary Light Theme ---
  // ==========================================
  static ThemeData get paperLightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: paperInkNavy,
      scaffoldBackgroundColor: paperSurface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PaperMorphPageTransitionsBuilder(),
          TargetPlatform.iOS: PaperMorphPageTransitionsBuilder(),
          TargetPlatform.macOS: PaperMorphPageTransitionsBuilder(),
          TargetPlatform.windows: PaperMorphPageTransitionsBuilder(),
          TargetPlatform.linux: PaperMorphPageTransitionsBuilder(),
        },
      ),
      colorScheme: const ColorScheme.light(
        primary: paperInkNavy,
        onPrimary: Colors.white,
        primaryContainer: paperTabBlue,
        onPrimaryContainer: Color(0xFF15365A),
        secondary: paperLeatherMid,
        onSecondary: Colors.white,
        secondaryContainer: paperTabPeach,
        onSecondaryContainer: Color(0xFF5C2518),
        tertiary: paperStampGreen,
        onTertiary: Colors.white,
        surface: paperSurface,
        onSurface: paperInkNavy,
        onSurfaceVariant: paperInkSlate,
        outline: Color(0xFFCBD5E1),
        outlineVariant: paperRuled,
        error: paperStampRed,
        onError: Colors.white,
        errorContainer: Color(0xFFFFE5E5),
        onErrorContainer: Color(0xFF8B1212),
      ),
      textTheme: baseKalam.copyWith(
        displayLarge: GoogleFonts.caveat(
          color: paperInkNavy,
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.caveat(
          color: paperInkNavy,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: GoogleFonts.caveat(
          color: paperInkNavy,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.kalam(
          color: paperInkNavy,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        headlineMedium: GoogleFonts.kalam(
          color: paperInkNavy,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.kalam(
          color: paperInkNavy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.kalam(
          color: paperInkNavy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.kalam(
          color: paperInkNavy,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: GoogleFonts.patrickHand(
          color: paperInkSlate,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.kalam(color: paperInkNavy, fontSize: 16),
        bodyMedium: GoogleFonts.kalam(color: paperInkSlate, fontSize: 14),
        bodySmall: GoogleFonts.patrickHand(color: paperInkMuted, fontSize: 13),
        labelLarge: GoogleFonts.jetBrainsMono(
          color: paperInkNavy,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: GoogleFonts.jetBrainsMono(
          color: paperInkNavy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          color: paperInkMuted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: paperInkNavy),
        titleTextStyle: GoogleFonts.kalam(
          color: paperInkNavy,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: paperCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2DDD5), width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.patrickHand(
          color: paperInkMuted.withOpacity(0.7),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2DDD5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2DDD5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: paperInkNavy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: paperStampRed, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: paperInkNavy,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.patrickHand(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: paperInkNavy,
        foregroundColor: Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paperCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2DDD5), width: 1.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paperCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          side: BorderSide(color: Color(0xFFE2DDD5), width: 1.2),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: paperInkNavy,
        textColor: paperInkNavy,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2DDD5),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==========================================
  // --- Paper Diary Dark Theme (Midnight Notebook) ---
  // ==========================================
  static ThemeData get paperDarkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: paperTabBlue,
      scaffoldBackgroundColor: paperDarkBackground,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PaperMorphPageTransitionsBuilder(),
          TargetPlatform.iOS: PaperMorphPageTransitionsBuilder(),
          TargetPlatform.macOS: PaperMorphPageTransitionsBuilder(),
          TargetPlatform.windows: PaperMorphPageTransitionsBuilder(),
          TargetPlatform.linux: PaperMorphPageTransitionsBuilder(),
        },
      ),
      colorScheme: const ColorScheme.dark(
        primary: paperTabBlue,
        onPrimary: paperInkNavy,
        primaryContainer: Color(0xFF1E3A5F),
        onPrimaryContainer: Colors.white,
        secondary: Color(0xFFE6A67E),
        onSecondary: Color(0xFF3F2110),
        surface: paperDarkSurface,
        onSurface: paperDarkInk,
        onSurfaceVariant: paperDarkMuted,
        outline: Color(0xFF3E434A),
        outlineVariant: Color(0xFF2E3238),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
      ),
      textTheme: baseKalam.copyWith(
        displayLarge: GoogleFonts.caveat(
          color: paperDarkInk,
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.kalam(
          color: paperDarkInk,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.kalam(
          color: paperDarkInk,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.kalam(color: paperDarkInk, fontSize: 16),
        bodyMedium: GoogleFonts.kalam(color: paperDarkMuted, fontSize: 14),
        labelLarge: GoogleFonts.jetBrainsMono(
          color: paperDarkInk,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: paperDarkInk),
        titleTextStyle: GoogleFonts.kalam(
          color: paperDarkInk,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: paperDarkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF3E434A), width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperDarkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3E434A)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: paperTabBlue,
          foregroundColor: paperInkNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.patrickHand(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
