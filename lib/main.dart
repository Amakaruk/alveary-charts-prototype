import 'package:flutter/material.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
        ).copyWith(
          surface: kBg,
          onSurface: Colors.white,
          surfaceTint: Colors.transparent,
        ),
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const ChartDemoScreen(),
    );
  }
}
