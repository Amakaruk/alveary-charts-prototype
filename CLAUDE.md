# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CPS Chart Demo — a self-contained Flutter demo screen for a scrollable time-series line/area chart displaying Colony Performance Score (CPS), a 0–100 health metric for honeybee hives. All data is mocked locally. No backend, Firestore, or auth.

## Commands

```bash
flutter pub get          # install dependencies
flutter run              # launch on connected device/emulator
flutter analyze          # static analysis
flutter test             # run tests
flutter build apk        # Android production build
flutter build ios        # iOS production build
```

## Dependencies

- `fl_chart: ^0.70.0` — charting
- `intl: ^0.19.0` — date/time formatting for x-axis labels

All moon phase math and data generation are pure Dart (no additional packages).

## Architecture

All source lives under `lib/demo/`. The full spec is in `project_spec.md`, `chart_demo_spec.md`, and `mock_data.md`.

### File Responsibilities

| File | Role |
|------|------|
| `chart_demo_screen.dart` | Root screen + layout (Scaffold, Column, Stack) |
| `cps_mock_data.dart` | `CpsReading` model + three data generators |
| `chart_viewport_controller.dart` | `ChangeNotifier` owning pan/zoom state + animation |
| `cps_line_chart.dart` | `fl_chart` `LineChart` configuration widget |
| `night_overlay.dart` | Night shading Stack layer (intraday only) |
| `zoom_toggle.dart` | `SegmentedButton<ZoomLevel>` widget |
| `moon_phase.dart` | `moonPhase(date)` + `moonIcon(phase)` pure functions |

### State Management

`ChartViewportController` (extends `ChangeNotifier`) is the single source of truth:
- `viewportStart: double` — left edge data index
- `visiblePoints: int` — data points visible at current zoom
- `totalPoints: int` — full dataset length
- `progress: double` — normalized position (`viewportStart / maxViewportStart`)

### Critical: Viewport Slicing

**Never pass all data to `LineChart`.** Always slice a window and re-index x from 0:

```dart
List<FlSpot> get visibleSpots {
  final start = viewportStart.floor();
  final end = (start + visiblePoints + 1).clamp(0, totalPoints);
  return data.sublist(start, end)
      .asMap().entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.score))
      .toList();
}
```

This keeps render cost flat regardless of dataset size.

### Zoom Levels

| Zoom | Data | `visiblePoints` | X-axis format |
|------|------|----------------|---------------|
| Intraday | Raw readings (~34 pts, `Random(42)` seeded) | all (~34) | `HH:mm` |
| Week | Hourly averages (98 pts, 7 days × 14 hrs) | 14 | `EEE` |
| Month | Daily averages (30 pts) | 14 | `MMM d` |

Zoom switching resets `viewportStart` to `maxViewportStart` (most recent data).

### Interactions

- **Swipe pan**: pixel delta → data units via `delta / chartWidth * visiblePoints`
- **Momentum fling**: `target = viewportStart − (velocity / chartWidth * visiblePoints * 0.35)`
- **Button nav**: shift ±60% of `visiblePoints`, `AnimationController` with `easeOutCubic` 400ms
- **Haptics**: `HapticFeedback.lightImpact()` on button tap

### Colour Palette

| Token | Hex |
|-------|-----|
| Background | `#0D0F14` |
| Surface / tooltip bg | `#161920` |
| Accent (line, progress) | `#4FFFB0` |
| Night shoulder | `#0D1B3E` |
| Text secondary / axis | `#FFFFFF89` |
| Grid lines | `#FFFFFF1A` |

### Night Overlay (Intraday Only)

Rendered as a `Stack` child over the chart. Left/right shoulders are dark blue `Container`s (~14% chart width each) with ☀️ icons. Moon icon is positioned top-centre of the right shoulder using `moonPhase(DateTime(2024, 6, 15))`.

### Mock Data

All generators use `Random(42)` for deterministic output. Demo date is `2024-06-15`. Intraday daylight window: `06:30–20:00`, 25 min ± 5 min jitter.
