# Chart UX/UI Prototype — Agent Handoff Report

This document is written for a Claude Code agent beginning a new session. It captures every significant UX/UI decision made during the `alveary-charts-prototype` build, with direct pointers to where each pattern should be implemented in the production app at `/Users/aaronmakaruk/Desktop/alveary-mvp`.

---

## Context

We built a standalone Flutter chart prototype (`alveary-charts-prototype`) to prove out and refine the chart UX for Alveary — a beekeeping app that displays Colony Performance Score (CPS), a 0–100 acoustic health metric for honeybee hives. The goal was to arrive at a set of validated, tested decisions that can be ported into the production chart implementation.

**Prototype entry point:** `lib/demo/chart_demo_screen.dart`  
**Production chart to update:** `/Users/aaronmakaruk/Desktop/alveary-mvp/lib/widgets/cps_chart.dart`

---

## Production App — Key Facts

Before making any changes, read these files:

| File | Why |
|------|-----|
| `lib/widgets/cps_chart.dart` (848 lines) | Main chart widget — straight-segment `LineChart`, 5 time ranges, KPI section, anomaly markers |
| `lib/models/log_entry.dart` | Rich `LogEntry` model — 7 types (inspection, treatment, feeding, harvest, swarm, queen, observation) |
| `lib/models/cps_reading.dart` | CPS reading model with `score`, `anomalyFlag`, `recordedAt` |
| `lib/services/firestore_service.dart` | `getCpsReadings()` and `getLogEntriesForHive()` streams |
| `lib/screens/home_screen.dart` | Where the chart is currently embedded |

The production app uses **Firebase Firestore streams** — no mock data. The chart and log entries currently live on **separate screens** with no connection between them.

---

## Overarching Platform Directives

These apply to every decision below:

1. **Material 3 first.** Use M3 widgets wherever available (`FilledButton`, `NavigationDrawer`, `BottomSheet`, `SideSheet`, `Card`, etc.). Defer colors and typography to the M3 theme — do not hardcode colors unless specifically called out below.

2. **Chart line color is an exception.** The chart line and area gradient should be **white on dark theme, black on light theme** — not an M3 theme color. This is intentional for sharpness and contrast. All other UI elements defer to M3 theming.

3. **Platform-adaptive log detail sheet.** When the user taps the chevron on a log row to open the detail view:
   - **Mobile:** `showModalBottomSheet` (M3 bottom sheet)
   - **Desktop/wide:** M3 `SideSheet` anchored to the right edge of the screen
   - Use `MediaQuery.of(context).size.width > 600` (or `adaptive_breakpoints` package) to select the variant.

4. **Colors and fonts defer to M3 theme.** Do not replicate `app_colors.dart` into production. Instead wire to `Theme.of(context).colorScheme` and `Theme.of(context).textTheme`. The prototype's `kAccent`, `kSurface`, `kBg` are stand-ins — map them to `colorScheme.primary`, `colorScheme.surface`, `colorScheme.background` etc.

---

## Decision 1: Viewport Slicing for Performance

**What we built:** `chart_viewport_controller.dart` — `visibleSpots` getter  
**Pattern:** Never pass all data to `LineChart`. Slice a window and re-index x from 0 on every render.

```dart
List<FlSpot> get visibleSpots {
  final start = _viewportStart.floor();
  final end = (start + _visiblePoints + 1).clamp(0, totalPoints);
  return data.sublist(start, end)
      .asMap().entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.score))
      .toList();
}
```

**Why:** Keeps render cost O(visiblePoints), not O(totalPoints). Critical for 5000-reading streams.  
**Where to apply:** `cps_chart.dart` — replace `_buildDayData()` with this slicing pattern.

---

## Decision 2: Zoom Levels and Visible Window Sizes

| Zoom | Dataset | Visible window | Scrollable |
|------|---------|---------------|------------|
| Intraday | Raw readings (~34 pts, 06:30–20:00) | All (~34) | No |
| Weekly | Daily averages | 7 pts | Yes |
| Monthly | Daily averages | 30 pts | Yes |

**Zoom switching preserves the focal date.** The centre date of the current viewport is captured before switching datasets, then the new viewport is centred on that same date. See `setZoom()` in `chart_viewport_controller.dart`.

**Default zoom:** Monthly. Users need historical context on first open.

**Production mapping:** Current `cps_chart.dart` has 5 ranges (1D, 7D, 14D, 30D, 90D). Map Intraday=1D, Weekly=7D, Monthly=30D. The 14D and 90D can follow the same pattern.

---

## Decision 3: Horizontal Swipe + Momentum Pan

```dart
// 1.5× sensitivity multiplier validated as the right feel
void onDragUpdate(double localX, double chartWidth) {
  final pixelDelta = _dragStartX - localX;
  final dataDelta = pixelDelta / chartWidth * _visiblePoints * 1.5;
  ...
}

// Momentum fling on release
void onDragEnd(double velocityPx, double chartWidth) {
  final dataDelta = -(velocityPx / chartWidth) * _visiblePoints * 0.35;
  _animateTo(_viewportStart + dataDelta);
}
```

**Animation:** `AnimationController` + `CurvedAnimation(Curves.easeOutCubic)`, 400ms.

---

## Decision 4: Gesture Conflict Fix — handleBuiltInTouches: false

**Problem:** `fl_chart` registers its own internal `GestureDetector` to show tooltips. When the user starts a drag near the chart line, fl_chart wins the gesture arena and the outer `GestureDetector` never sees a drag start. Drag works in the empty area below the line but not on or above it.

**Fix:**
```dart
lineTouchData: const LineTouchData(handleBuiltInTouches: false),
```

This removes fl_chart from the gesture arena entirely. Our outer `GestureDetector` handles all drags uniformly across the full chart surface.

**Tap tooltip is then implemented manually** — `onTapUp` on the outer `GestureDetector` calculates the nearest spot index and sets it as `showingIndicators` on the bar data. Tapping the same spot again dismisses. Drag start clears the tooltip.

```dart
void _onTapUp(TapUpDetails details) {
  final fraction = (details.localPosition.dx / _chartWidth).clamp(0.0, 1.0);
  final idx = (fraction * c.visiblePoints).round().clamp(0, spots.length - 1);
  setState(() => _tooltipSpotIndex = _tooltipSpotIndex == idx ? null : idx);
}
```

**Guard against stale index on zoom change:**
```dart
final tipIdx = (_tooltipSpotIndex != null && _tooltipSpotIndex! < spots.length)
    ? _tooltipSpotIndex : null;
```

---

## Decision 5: Right-Edge Rubber Band Bounce

**Behaviour:** When the user drags past the most recent data (right edge), the chart resists with a 0.3 damping factor. On release it snaps back with `easeOutCubic` over 350ms. Matches iOS-style overscroll feel.

**Implementation:** `_overscrollPixels` field in the controller. During drag, overscroll is calculated in pixel space and exposed as a getter. The chart widget applies it as a `Transform.translate` inside a `ClipRect`. A separate `AnimationController _bounceController` handles the snap-back animation.

```dart
if (rawTarget > maxViewportStart) {
  final excessPx = (rawTarget - maxViewportStart) / _visiblePoints * chartWidth;
  _overscrollPixels = excessPx * 0.3;
  _viewportStart = maxViewportStart;
}
```

---

## Decision 6: Haptic Feedback on Scroll

Use the `vibration` package (`vibration: ^2.0.0`). `HapticFeedback.lightImpact()` is silent on many Android devices.

```dart
Vibration.vibrate(duration: 15, amplitude: 80);
```

Fire ~30 haptics per full screen swipe. Scale threshold by zoom level — see `_onViewportChanged` in `cps_line_chart.dart`.

---

## Decision 7: Y-Axis Removal — Edge-to-Edge Chart

Remove Y-axis labels. Add ghost "0" and "100" anchors at the left edge via `extraLinesData.horizontalLines` with `color: Colors.transparent` and a `HorizontalLineLabel` at ~20% white opacity.

---

## Decision 8: X-Axis Labels — Center-Anchored

Use `interval: 1` and filter in `getTitlesWidget` based on alignment to the viewport centre:

```dart
final centerAbs = viewportStart.floor() + visiblePoints ~/ 2;
final interval = zoom == ZoomLevel.monthly ? 5 : 1;
if ((absIdx - centerAbs) % interval != 0) return SizedBox.shrink();
```

Centre label stays anchored to the middle of the chart as the user pans.

---

## Decision 9: Straight Lines — No Curve Smoothing

`isCurved: false` on `LineChartBarData`. The CPS data has real sharp transitions (weather events, treatments) — smoothing obscures the story. Point-to-point lines preserve the signal.

---

## Decision 10: Log Entries as Chart Event Markers

**The core UX insight:** Connecting log entries to the CPS timeline shows beekeepers the impact of their actions. This incentivises logging.

**Current implementation:** `extraLinesData.verticalLines` — thin solid lines at 18% opacity spanning the full chart height. Type-specific unicode icons at the base:

| Type | Icon | Color |
|------|------|-------|
| Inspection | `◆` | white |
| Weather | `◈` | sky blue `#64B5F6` |
| Seasonal | `◉` | soft green `#81C784` |

No dash arrays — dashes made the lines look shorter and were visually noisy.

**Color-coding in production** for `LogEntry`'s 7 types — map to colors and icons following the same pattern. Suggested:

| Type | Color |
|------|-------|
| inspection / full_inspection | `colorScheme.onSurface` (white/black per theme) |
| treatment | warm orange |
| feeding | soft green |
| harvest | amber |
| swarm | red-orange |
| queen | purple |
| observation / weather / seasonal | sky blue |

---

## Decision 11: Tap Log Row → Chart Scrolls to That Date

Tapping a log row animates the chart to centre that date. If in Intraday zoom, auto-switches to Weekly first.

```dart
void scrollToDate(DateTime date) {
  if (zoom == ZoomLevel.intraday) { zoom = ZoomLevel.weekly; visiblePoints = 7; }
  final idx = _indexForDate(data, date);
  _animateTo((idx - visiblePoints / 2).clamp(0, maxViewportStart));
}
```

---

## Decision 12: Active Log Row Highlighting

As the user pans the chart, the log row closest to the viewport centre highlights via `controller.visibleCentreDate`. The controller notifies on every pan frame; the list rebuilds via `ListenableBuilder`.

---

## Decision 13: Inspection Log Row Visual Hierarchy

Row layout (left → right):

1. **2px left accent bar** — type color at 35–90% opacity, stretches full row height via `IntrinsicHeight`. Gives immediate type identification without a separate dot.
2. **Date** (`MMM d`) — `12sp, w600` — primary temporal anchor
3. **Type label** — small, dimmed at type color — secondary metadata beside the date
4. **Note text** — `13sp, 54% white` — primary body content
5. **CPS badge** — compact right-side reference number
6. **Chevron** — `Icons.expand_more`, 25% white — clearly a control, lowest visual weight

**CPS delta badge was removed** from the row. It added visual noise without enough payoff at the row level. The delta is still computable from `cpsDeltaAfterDate()` in the controller — consider showing it inside the detail sheet instead.

---

## Decision 14: Log Detail Sheet — Platform Adaptive

Tapping the chevron on a log row opens a detail sheet with:
- Drag handle pill
- Header: type dot + label, date (`MMM d`), CPS badge, close `IconButton`
- Placeholder body (to be filled with full log data in production)

**Platform behaviour:**
- **Mobile** (`width < 600`): `showModalBottomSheet` — M3 bottom sheet, `isScrollControlled: true`, `useSafeArea: true`
- **Desktop/tablet** (`width ≥ 600`): M3 `SideSheet` anchored right

```dart
void _showDetailSheet(BuildContext context) {
  if (MediaQuery.of(context).size.width >= 600) {
    // TODO: open M3 SideSheet
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogDetailSheet(log: log),
    );
  }
}
```

**Critical:** Use a `Container` with explicit background color as the root child of the sheet — do not rely on `showModalBottomSheet`'s `backgroundColor` parameter, which can be overridden by the M3 theme and render as nearly invisible on dark backgrounds.

---

## Decision 15: Weather on Weekly X-Axis

Weekly zoom shows stacked x-axis: date → weather emoji → high/low temp. Monthly and Intraday use minimal labels. Reserved height: 76px weekly, 42px monthly, 26px intraday.

**In production:** Wire to a weather API keyed by `apiaryId` and date. Accept `Map<String, WeatherDay>? weather` — null-safe, degrades to date-only labels.

---

## Decision 16: Night Overlay (Intraday)

Two shoulder gradients over the chart at the start and end of the daylight window. Left shoulder shows `🌅` (sunrise). Right shoulder shows only the moon phase icon (no sun — having two sun icons was confusing). Moon phase calculated from `moonPhase(DateTime)` in `moon_phase.dart`.

---

## Decision 17: Progress Bar Inside Chart Stack

The viewport progress bar (showing scroll position) lives inside the chart `Stack` as a `Positioned` element, flush against the top of the x-axis reserved area:

```dart
Positioned(
  left: 0, right: 0,
  bottom: xAxisHeight, // 26 / 76 / 42 depending on zoom
  child: IgnorePointer(
    child: SizedBox(height: 2, child: LinearProgressIndicator(...)),
  ),
),
```

No separate nav buttons. No extra padding. The bar is 2px tall and `IgnorePointer` so it doesn't interfere with chart gestures.

---

## Decision 18: Custom Header — No AppBar

The screen uses no `AppBar`. Instead, the first item in the `SingleChildScrollView` column is a custom header row:

```
[back IconButton] [Expanded: apiary label / CPS number + "CPS" label + trend badge] [ZoomToggle] [PopupMenuButton]
```

The CPS number is `52sp / w800` — visually dominant. The trailing controls (zoom + menu) are vertically centred against it. This saves ~56px vs the previous AppBar + separate hero section, and puts the most important data (the score) at the very top of the screen.

`SafeArea` wraps the body directly (no AppBar to handle status bar insets).

---

## Decision 19: Mock Data — Seasonal Arc for Y-Axis Drama

The original mock data had a ~16pt Y-axis range (all readings 58–74). Rewritten to span ~55pts:

- **December** (start): ~44–50 (winter cluster)
- **February polar vortex**: drops to ~30–38
- **March–April**: rises to ~55–75 with frost and storm dips
- **May–June peak**: ~78–88

The generator uses a `_seasonCurve(t)` ease-in-out over the 180 days, layered with `_narrativeShock(date)` dips that align with the log entry dates, plus a 14-day sinusoidal undulation for brood/foraging cycle realism.

---

## Suggested Implementation Order for Production Agent

1. **Read** `lib/widgets/cps_chart.dart`, `lib/models/log_entry.dart`, `lib/services/firestore_service.dart` before touching anything
2. **Wire M3 theme** — set up `ColorScheme` and `TextTheme` in `main.dart` if not already present
3. **Extract viewport controller** → create alongside `cps_chart.dart`, wire to Firestore streams
4. **Swipe + momentum + bounce** → add `GestureDetector`, set `handleBuiltInTouches: false`
5. **Y-axis removal + ghost anchors**
6. **Center-anchored x labels**
7. **Straight lines** (`isCurved: false`)
8. **Log markers on chart** → `visibleLogMarkers()` → `extraLinesData.verticalLines`
9. **Tap log → scroll chart** → `scrollToDate()`, wire from log list
10. **Active row highlighting** → `visibleCentreDate` comparison in `ListenableBuilder`
11. **Log row redesign** → left accent bar, date prominent, note as body, CPS badge right
12. **Log detail sheet** → bottom sheet mobile, side sheet desktop
13. **Weather x-axis** → wire to weather data source
14. **Tap tooltip** → `onTapUp` + `showingIndicators`
15. **Custom header** → replace `AppBar` with header row: back | CPS | zoom | menu

---

## Prototype Source Reference

All patterns above are implemented and working in:

```
alveary-charts-prototype/lib/demo/
  app_colors.dart                ← prototype color palette (map to M3 colorScheme in production)
  chart_viewport_controller.dart ← viewport, pan, zoom, bounce, scrollToDate, markers, weather
  cps_line_chart.dart            ← fl_chart config, gesture fix, tooltip, weather axis
  cps_mock_data.dart             ← data models (LogType, InspectionLog, CpsReading) + seasonal arc
  weather_data.dart              ← WeatherCondition, WeatherDay, generator
  inspection_table.dart          ← log list, row hierarchy, accent bar, detail sheet
  zoom_toggle.dart               ← dropdown zoom selector
  chart_demo_screen.dart         ← custom header, screen layout, no AppBar
  night_overlay.dart             ← intraday night shoulders + moon/sunrise icons
  moon_phase.dart                ← moonPhase() + moonIcon()
  hive_task.dart                 ← HiveTask model, Recommendation model, deriveRecommendations()
  plan_tab.dart                  ← Plan tab: recommended cards + to-do checklist
```

---

## Decisions — Screen Architecture & Information Architecture

### 19. Screen layout — unified single scrollview (tabs removed)

**Decision (supersedes earlier tab-split design):** No `TabBar`. Single `Column`: sticky header + 280px chart, then one `SingleChildScrollView` with everything below.

```
Column
├── Header row (sticky)
├── SizedBox(height: 280) — chart, always visible, fixed height
└── Expanded > SingleChildScrollView
    ├── UPCOMING — planned inspections + suggested task cards
    ├── Today divider (temporal anchor)
    └── LOG — InspectionTable (past entries)
```

**Chart height fixed at 280px** — never changes between zoom levels to prevent UI jump. The `SizedBox` is outside the `ListenableBuilder`.

**Why tabs were removed:** The tab design added UI chrome without meaningful benefit. A single chronological timeline (upcoming → now → past) is simpler and more scannable.

---

### 20. Information architecture — UPCOMING / LOG split

**UPCOMING (above today divider):** planned inspections (compact row, date + task count, no individual tasks shown) + suggested task cards (tappable → KB-article detail sheet).

**LOG (below today divider):** past `InspectionLog` rows — 2px accent bar, date, type label, note, CPS badge, chevron → detail sheet.

---

### 21. Recommendations are server-driven only

Recommendations come from a server-side rules engine considering the full hive profile. The app renders whatever it receives — no client-side derivation.

**Prototype:** `mockRecommendations` in `hive_task.dart` (3 static items). `Recommendation` model: `title`, `detail`, `actionItems: List<String>`, `urgency`, `source`.

**Do not recreate `deriveRecommendations()` in production.** That function was prototyped and removed.

---

### 22. Suggested task detail sheet — KB article pattern

Tapping a task card opens a detail sheet with full description + action items.

**Platform adaptive:** `showGeneralDialog` + `SlideTransition` for desktop (≥600px) → `SizedBox(width: 400, height: MediaQuery.of(context).size.height)`. `showModalBottomSheet` on mobile.

**Critical:** The desktop side panel `SizedBox` needs explicit `height`. Without it, `Expanded` children throw unbounded constraint errors.

---

### 23. Map belongs on apiary profile only — never on hive profile

**Decision:** A map showing hive location belongs on the **apiary profile**, not the hive profile.

**Rationale:** A single hive has no distinct GPS coordinate — it's *at* the apiary. All hives in Spring Apiary share the same pin, which adds no value on the hive screen. The apiary profile is where location is meaningful: forage radius, terrain, multiple hives in one yard. The hive name header already implies location via its parent apiary.

**Future:** If within-apiary layout (showing where *this* hive sits relative to others in the yard) is needed, that's a distinct "yard map" component, not a geo map — and still belongs on the apiary profile, not the hive profile.

---

### 24. Theming — AppPalette ThemeExtension (light + dark)

**Decision:** Replaced compile-time `const kX` color constants with `AppPalette extends ThemeExtension<AppPalette>`. Two presets (`AppPalette.dark`, `AppPalette.light`) registered on `darkTheme` and `theme` respectively in `main.dart`. All widgets resolve via `AppPalette.of(context)`.

**Why:** Allows `ThemeMode.system` to switch palettes automatically. `lerp()` implemented for animated theme transitions. `cps_line_chart.dart` resolves palette in `build()` and passes it as a parameter into `_buildChart()` because fl_chart callbacks lack `BuildContext`.

**Palette tokens:** `accent` (chart line: white dark / near-black light), `bg`, `surface`, `surface2`, `onSurface`, `onSurfaceMed`, `onSurfaceLow`, `onSurfaceSubtle`, `markerInspection`.

**Fonts:** `google_fonts` package. Domine w600 for display/headline/title roles. Noto Sans for body/label. Applied at `ThemeData.textTheme` level + explicitly on the CPS display number.

**CPS score font:** Noto Sans w800 (not Domine — serif was too antiquated for a numeric display).

---

### 25. LayoutBuilder inside IntrinsicHeight — FORBIDDEN

**Never use `LayoutBuilder` as a descendant of `IntrinsicHeight`.** This causes the entire widget subtree to render blank on iOS with no error in debug mode.

**Pattern to use instead:**
```dart
// WRONG — causes blank render on iOS
IntrinsicHeight(
  child: LayoutBuilder(builder: (context, constraints) { ... })
)

// RIGHT
Builder(builder: (context) {
  final isWide = MediaQuery.of(context).size.width >= 600;
  return IntrinsicHeight(child: ...);
})
```

This affects any responsive row that uses `IntrinsicHeight` to stretch a left accent bar to full row height (e.g., `_InspectionRow`, `_PlannedInspectionRow`).

---

### 26. Vibration on web — kIsWeb guard required

```dart
if (!kIsWeb) Vibration.vibrate(duration: 15, amplitude: 80);
```

Without the guard, `Vibration.vibrate()` throws `MissingPluginException` on every pan frame and corrupts the Chrome UI. Import `package:flutter/foundation.dart` for `kIsWeb`.

---

### 27. Log markers — thin solid lines only, no type differentiation

**Decision:** All log markers on the chart are identical thin solid vertical lines. Single color: `p.onSurface.withValues(alpha: 0.15)`. No per-type colors, no unicode icons at the base.

**Why previous version was removed:** Per-type colors (blue for weather, green for seasonal) were unreadable on the warm brown surface. Unicode symbols (◆ ◈ ◉) at the bottom added visual noise. The lines alone convey "something happened here" sufficiently — the LOG section below provides the detail.

---

### 28. X-axis labels — final validated formats

**Intraday:** Every 3 hours only (every-hour labels collide on narrow screens). Format: `DateFormat('ha').format(ts).toLowerCase()` → "6am", "12pm". Guard against duplicates within the same hour when multiple data points share an hour.

**Weekly:** `DateFormat('EEEEE\nd').format(ts)` → "M\n3" (narrow weekday letter + newline + day number). Month name removed. Weather block below: emoji at 14px, temp at 11px `onSurfaceMed`.

**Monthly:** Show label only at month boundary (`prevTs.month != ts.month`). Format: `DateFormat('MMM').format(ts)` → "Feb", "Mar". Previous "MMM d" was too busy and too small to read.

**Vertical centering:** `SideTitleWidget(space: s)` where `s = (reservedSize - contentHeight) / 2`. Values: intraday=6, weekly=10, monthly=8.

**Separator:** 1px `Divider(color: p.onSurfaceSubtle)` at the bottom of the chart `Column`, separating x-axis from the scrollable content below.
