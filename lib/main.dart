import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'demo/app_colors.dart';
import 'demo/chart_demo_screen.dart';

void main() {
  runApp(const CpsChartApp());
}

class CpsChartApp extends StatelessWidget {
  const CpsChartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPS Chart Demo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const ChartDemoScreen(),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  // Mirror Alveary's warm-brown M3 seed so the generated scheme matches.
  const primarySeed = Color(0xff88511d);
  final palette = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: primarySeed,
    brightness: brightness,
  ).copyWith(
    surface: palette.bg,
    onSurface: palette.onSurface,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: palette.bg,
    extensions: [palette],
    textTheme: GoogleFonts.notoSansTextTheme(base.textTheme).copyWith(
      displayLarge:   GoogleFonts.domine(textStyle: base.textTheme.displayLarge,   fontWeight: FontWeight.w600, color: palette.onSurface),
      displayMedium:  GoogleFonts.domine(textStyle: base.textTheme.displayMedium,  fontWeight: FontWeight.w600, color: palette.onSurface),
      displaySmall:   GoogleFonts.domine(textStyle: base.textTheme.displaySmall,   fontWeight: FontWeight.w600, color: palette.onSurface),
      headlineLarge:  GoogleFonts.domine(textStyle: base.textTheme.headlineLarge,  fontWeight: FontWeight.w600, color: palette.onSurface),
      headlineMedium: GoogleFonts.domine(textStyle: base.textTheme.headlineMedium, fontWeight: FontWeight.w600, color: palette.onSurface),
      headlineSmall:  GoogleFonts.domine(textStyle: base.textTheme.headlineSmall,  fontWeight: FontWeight.w600, color: palette.onSurface),
      titleLarge:     GoogleFonts.domine(textStyle: base.textTheme.titleLarge,     fontWeight: FontWeight.w600, color: palette.onSurface),
      titleMedium:    GoogleFonts.domine(textStyle: base.textTheme.titleMedium,    fontWeight: FontWeight.w600, color: palette.onSurface),
      titleSmall:     GoogleFonts.domine(textStyle: base.textTheme.titleSmall,     fontWeight: FontWeight.w600, color: palette.onSurface),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
