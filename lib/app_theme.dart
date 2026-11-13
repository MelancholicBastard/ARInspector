import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static final light = _theme(
    const ColorScheme.light(
      primary: Color(0xFF245C46),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD9F4A7),
      onPrimaryContainer: Color(0xFF193325),
      secondary: Color(0xFF56634D),
      secondaryContainer: Color(0xFFE5ECD9),
      onSecondaryContainer: Color(0xFF263721),
      tertiary: Color(0xFF89622C),
      tertiaryContainer: Color(0xFFFFE8BA),
      surface: Color(0xFFF7F8F2),
      // ignore: deprecated_member_use
      surfaceVariant: Color(0xFFE8ECE2),
      onSurface: Color(0xFF1A211C),
      onSurfaceVariant: Color(0xFF526052),
      outline: Color(0xFF778375),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF1F4EB),
      surfaceContainer: Color(0xFFEBEFE4),
      surfaceContainerHigh: Color(0xFFE5EADD),
      surfaceContainerHighest: Color(0xFFDFE5D6),
    ),
  );

  static final dark = _theme(
    const ColorScheme.dark(
      primary: Color(0xFFBADD95),
      onPrimary: Color(0xFF193325),
      primaryContainer: Color(0xFF304D37),
      onPrimaryContainer: Color(0xFFD9F4A7),
      secondaryContainer: Color(0xFF354333),
      onSecondaryContainer: Color(0xFFE5ECD9),
      tertiary: Color(0xFFFFD699),
      tertiaryContainer: Color(0xFF59431F),
      surface: Color(0xFF121914),
      // ignore: deprecated_member_use
      surfaceVariant: Color(0xFF263128),
      onSurface: Color(0xFFE4EBDD),
      onSurfaceVariant: Color(0xFFBAC8B5),
      surfaceContainerLowest: Color(0xFF0C130E),
      surfaceContainerLow: Color(0xFF18211A),
      surfaceContainer: Color(0xFF1D2820),
      surfaceContainerHigh: Color(0xFF27332A),
      surfaceContainerHighest: Color(0xFF313E33),
    ),
  );

  static ThemeData _theme(ColorScheme colors) => ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 64),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
