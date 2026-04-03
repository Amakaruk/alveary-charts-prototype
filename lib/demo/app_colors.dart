import 'package:flutter/material.dart';

// Night overlay (semantic – same regardless of theme)
const kNightBlue = Color(0xFF0D1B3E);

// Log marker colors (work in both modes except inspection which is theme-aware)
const kMarkerWeather  = Color(0xFF64B5F6); // sky blue
const kMarkerSeasonal = Color(0xFF81C784); // soft green

// ---------------------------------------------------------------------------
// AppPalette — custom theme extension carrying all mode-sensitive tokens.
// Access via AppPalette.of(context) anywhere in the widget tree.
// ---------------------------------------------------------------------------
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.accent,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.onSurface,
    required this.onSurfaceMed,
    required this.onSurfaceLow,
    required this.onSurfaceSubtle,
    required this.markerInspection,
  });

  /// Chart line / primary accent. White on dark, near-black on light.
  final Color accent;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color onSurface;
  final Color onSurfaceMed;    // ~60% opacity equivalent
  final Color onSurfaceLow;    // ~30% opacity equivalent
  final Color onSurfaceSubtle; // ~10% opacity equivalent (dividers)
  final Color markerInspection;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  // Alveary dark palette — warm brown M3 (seed: 0xff88511d, dark)
  static const dark = AppPalette(
    accent:             Color(0xFFFFFFFF),
    bg:                 Color(0xFF160F0A),
    surface:            Color(0xFF2B1D14),
    surface2:           Color(0xFF1F1410),
    onSurface:          Color(0xFFEDE0D4),
    onSurfaceMed:       Color(0x99EDE0D4),
    onSurfaceLow:       Color(0x4DEDE0D4),
    onSurfaceSubtle:    Color(0x1AEDE0D4),
    markerInspection:   Color(0xFFFFFFFF),
  );

  // Alveary light palette — warm brown M3 (seed: 0xff88511d, light)
  static const light = AppPalette(
    accent:             Color(0xFF201A16), // near-black warm brown = "black on white"
    bg:                 Color(0xFFFFF8F5),
    surface:            Color(0xFFEEE4DB),
    surface2:           Color(0xFFF3EAE2),
    onSurface:          Color(0xFF201A16),
    onSurfaceMed:       Color(0x99201A16),
    onSurfaceLow:       Color(0x4D201A16),
    onSurfaceSubtle:    Color(0x1A201A16),
    markerInspection:   Color(0xFF201A16),
  );

  @override
  AppPalette copyWith({
    Color? accent,
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? onSurface,
    Color? onSurfaceMed,
    Color? onSurfaceLow,
    Color? onSurfaceSubtle,
    Color? markerInspection,
  }) => AppPalette(
    accent:             accent             ?? this.accent,
    bg:                 bg                 ?? this.bg,
    surface:            surface            ?? this.surface,
    surface2:           surface2           ?? this.surface2,
    onSurface:          onSurface          ?? this.onSurface,
    onSurfaceMed:       onSurfaceMed       ?? this.onSurfaceMed,
    onSurfaceLow:       onSurfaceLow       ?? this.onSurfaceLow,
    onSurfaceSubtle:    onSurfaceSubtle    ?? this.onSurfaceSubtle,
    markerInspection:   markerInspection   ?? this.markerInspection,
  );

  @override
  AppPalette lerp(AppPalette other, double t) => AppPalette(
    accent:             Color.lerp(accent,             other.accent,             t)!,
    bg:                 Color.lerp(bg,                 other.bg,                 t)!,
    surface:            Color.lerp(surface,            other.surface,            t)!,
    surface2:           Color.lerp(surface2,           other.surface2,           t)!,
    onSurface:          Color.lerp(onSurface,          other.onSurface,          t)!,
    onSurfaceMed:       Color.lerp(onSurfaceMed,       other.onSurfaceMed,       t)!,
    onSurfaceLow:       Color.lerp(onSurfaceLow,       other.onSurfaceLow,       t)!,
    onSurfaceSubtle:    Color.lerp(onSurfaceSubtle,    other.onSurfaceSubtle,    t)!,
    markerInspection:   Color.lerp(markerInspection,   other.markerInspection,   t)!,
  );
}
