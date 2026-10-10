import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Heritage Ledger / Digital Sanctuary Design System
/// Derived from Stitch Design Specs
class AppTheme {
  // --- Stitch Core Color Tokens ---
  static const Color primary = Color(0xFF006972); // Heritage Teal
  static const Color primaryContainer = Color(0xFF68C9D6);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF00535B);

  static const Color secondary = Color(0xFF735C00); // Sunlight Gold
  static const Color secondaryContainer = Color(0xFFFDD34D); // Growth / Warm Milestone
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF725B00);

  static const Color surface = Color(0xFFF8F9FA); // Clean expansive canvas
  static const Color surfaceContainerLow = Color(0xFFF3F4F5); // Grouping / Sectioning
  static const Color surfaceContainer = Color(0xFFEDEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // Pop cards

  static const Color onSurface = Color(0xFF191C1D); // Editorial charcoal (never #000000)
  static const Color onSurfaceVariant = Color(0xFF3E484A);
  static const Color outline = Color(0xFF6F797B);
  static const Color outlineVariant = Color(0xFFBEC8CA);

  static const Color error = Color(0xFFBA1A1A); // Deep sophisticated ruby
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // --- Dark Mode Palette ---
  static const Color darkBackground = Color(0xFF101314);
  static const Color darkSurface = Color(0xFF191C1D);
  static const Color darkSurfaceContainer = Color(0xFF232728);
  static const Color darkSurfaceContainerLowest = Color(0xFF1D2021);
  static const Color darkOnSurface = Color(0xFFF0F1F2);
  static const Color darkOnSurfaceVariant = Color(0xFFB0B9BA);

  // --- Backward Compatibility Aliases ---
  static const Color primaryColor = primary;
  static const Color backgroundColor = surface;
  static const Color darkBackgroundColor = darkBackground;
  static const Color surfaceColor = surface;
  static const Color darkSurfaceColor = darkSurface;
  static const Color onSurfaceColor = onSurface;
  static const Color errorColor = error;

  // --- Stitch Ambient Shadows ---
  static const List<BoxShadow> editorialShadow = [
    BoxShadow(
      color: Color(0x0F191C1D), // 6% opacity
      blurRadius: 40,
      offset: Offset(0, 20),
    ),
  ];

  static const List<BoxShadow> ambientCardShadow = [
    BoxShadow(
      color: Color(0x0D191C1D), // 5% opacity
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> subtleFloatShadow = [
    BoxShadow(
      color: Color(0x0A191C1D),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // --- Stitch Gradients ---
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

  // --- Light Theme ---
  static ThemeData get lightTheme {
    final baseInter = GoogleFonts.interTextTheme();
    final baseManrope = GoogleFonts.manropeTextTheme();

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
        bodyLarge: baseInter.bodyLarge?.copyWith(color: onSurface, fontSize: 16),
        bodyMedium: baseInter.bodyMedium?.copyWith(color: onSurfaceVariant, fontSize: 14),
        bodySmall: baseInter.bodySmall?.copyWith(color: onSurfaceVariant, fontSize: 12),
        labelLarge: baseInter.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelMedium: baseInter.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.0),
        labelSmall: baseInter.labelSmall?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.5),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.inter(color: onSurfaceVariant.withOpacity(0.6), fontSize: 14),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariant.withOpacity(0.15),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // --- Dark Theme ---
  static ThemeData get darkTheme {
    final baseInter = GoogleFonts.interTextTheme();
    final baseManrope = GoogleFonts.manropeTextTheme();

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
        secondary: secondaryContainer,
        onSecondary: onSecondaryContainer,
        surface: darkSurface,
        onSurface: darkOnSurface,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: outline,
        outlineVariant: Color(0xFF3E484A),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
      ),
      textTheme: baseInter.copyWith(
        displayLarge: baseManrope.displayLarge?.copyWith(color: darkOnSurface, fontWeight: FontWeight.w800),
        displayMedium: baseManrope.displayMedium?.copyWith(color: darkOnSurface, fontWeight: FontWeight.w800),
        displaySmall: baseManrope.displaySmall?.copyWith(color: darkOnSurface, fontWeight: FontWeight.w700),
        headlineLarge: baseManrope.headlineLarge?.copyWith(color: darkOnSurface, fontWeight: FontWeight.w800),
        headlineMedium: baseManrope.headlineMedium?.copyWith(color: darkOnSurface, fontWeight: FontWeight.w700),
        titleLarge: baseManrope.titleLarge?.copyWith(color: darkOnSurface, fontWeight: FontWeight.w700),
        titleMedium: baseManrope.titleMedium?.copyWith(color: darkOnSurface, fontWeight: FontWeight.w600),
        bodyLarge: baseInter.bodyLarge?.copyWith(color: darkOnSurface, fontSize: 16),
        bodyMedium: baseInter.bodyMedium?.copyWith(color: darkOnSurfaceVariant, fontSize: 14),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.inter(color: darkOnSurfaceVariant.withOpacity(0.6), fontSize: 14),
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
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimaryContainer,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
