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
**Where to apply:** `cps_chart.dart` — replace the current `LineChartData` data prep with this pattern. The current implementation calls `_buildDayData()` which aggregates but still passes all aggregated results to fl_chart.

---

## Decision 2: Zoom Levels and Visible Window Sizes

**What we validated:**

| Zoom | Dataset | Visible window | Scrollable |
|------|---------|---------------|------------|
| Intraday | Raw readings (~34 pts, 06:30–20:00) | All (~34) | No |
| Weekly | Daily averages | 7 pts | Yes — week to week |
| Monthly | Daily averages | 30 pts | Yes — month to month |

**Production mapping:** The current `cps_chart.dart` has 5 ranges (1D, 7D, 14D, 30D, 90D). Map to: Intraday = 1D, Weekly = 7D (1 pt/day), Monthly = 30D (1 pt/day). The 14D and 90D ranges are not in the prototype but can follow the same pattern.

**Default zoom:** Monthly. Users need historical context more than intraday detail on first open.

---

## Decision 3: Horizontal Swipe + Momentum Pan

**What we built:** Drag handling in `chart_viewport_controller.dart`

```dart
// Pixel delta → data units
void onDragUpdate(double localX, double chartWidth) {
  final pixelDelta = _dragStartX - localX;
  final dataDelta = pixelDelta / chartWidth * _visiblePoints;
  _viewportStart = (_dragStartViewport + dataDelta).clamp(0, maxViewportStart);
  notifyListeners();
}

// Momentum fling on release
void onDragEnd(double velocityPx, double chartWidth) {
  final dataDelta = -(velocityPx / chartWidth) * _visiblePoints * 0.35;
  _animateTo(_viewportStart + dataDelta);
}
```

**Animation:** `AnimationController` + `CurvedAnimation(Curves.easeOutCubic)`, 400ms.  
**Where to apply:** Wrap `LineChart` in a `GestureDetector` in `cps_chart.dart`. The current chart has no pan — only button/tab navigation.

---

## Decision 4: Haptic Feedback on Scroll

**What we learned:** `HapticFeedback.lightImpact()` and `selectionClick()` are silent on many Android devices. Only `HapticFeedback.vibrate()` fires reliably, but it's too long (500ms buzz).

**Solution:** Use the `vibration` package (`vibration: ^2.0.0`):
```dart
Vibration.vibrate(duration: 15, amplitude: 80);
```

**Tick density:** Fire ~30 haptics per full screen swipe regardless of zoom level. Scale the trigger threshold:
```dart
final step = switch (zoom) {
  ZoomLevel.weekly  => 7 / 30.0,  // 7 pts visible → fire every 0.23 pts
  ZoomLevel.monthly => 1.0,        // 30 pts visible → fire every 1 pt
  _                 => 1.0,
};
if ((viewportStart / step).floor() != _lastBucket) {
  Vibration.vibrate(duration: 15, amplitude: 80);
}
```

**Where to apply:** Add listener on `ChartViewportController` from the chart widget's `initState`.

---

## Decision 5: Y-Axis Removal — Edge-to-Edge Chart

**Decision:** Remove Y-axis labels entirely. CPS is 0–100 — the public has intuition for percentage-like scores. The chart should flow edge to edge.

```dart
leftTitles: const AxisTitles(
    sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
rightTitles: const AxisTitles(
    sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
```

**Anchors:** Instead of axis labels, show "100" and "0" as ghost text inside the chart at the left edge using `extraLinesData.horizontalLines` with `color: Colors.transparent` and a `HorizontalLineLabel`. These are subtle — opacity ~20% — just enough to orient a first-time user.

**Where to apply:** `cps_chart.dart` — remove `reservedSize` on left titles. Production currently reserves 32–40px for Y labels.

---

## Decision 6: X-Axis Labels — Center-Anchored

**Problem:** fl_chart places x-axis labels at fixed intervals from x=0. As the user scrolls, labels can drift to the edges, leaving a dead zone in the centre.

**Solution:** Use `interval: 1` and filter inside `getTitlesWidget` based on alignment to the viewport centre:

```dart
// In getTitlesWidget:
final absIdx = viewportStart.floor() + v.toInt();
final centerAbs = viewportStart.floor() + visiblePoints ~/ 2;
final interval = zoom == ZoomLevel.monthly ? 5 : 1;
if ((absIdx - centerAbs) % interval != 0) return SizedBox.shrink();
```

**Effect:** The centre date label stays anchored to the middle of the chart as you scroll. Labels don't drift.

**Intraday:** Show one label per hour at the first data point in each hour, formatted as `HH:00`.

---

## Decision 7: Log Entries as Chart Event Markers

**The core UX insight:** Connecting inspection logs to the CPS timeline shows beekeepers the impact of their actions — "I treated for varroa on March 28, CPS went up 8 points over the next week." This incentivizes more logging.

**Implementation:** `extraLinesData.verticalLines` in `LineChartData` — thin dashed vertical lines at log entry dates within the visible viewport.

```dart
// In controller — map log dates to local x positions
List<({double x, LogEntry log})> visibleLogMarkers(List<LogEntry> logs) {
  if (zoom == ZoomLevel.intraday) return [];
  return logs.map((log) {
    final idx = _indexForDate(data, log.date);
    final localX = idx - viewportStart.floor().toDouble();
    if (localX < -0.5 || localX > visiblePoints + 0.5) return null;
    return (x: localX, log: log);
  }).whereNotNull().toList();
}
```

**Color-coding by log type:**

| Type | Color | Dash pattern |
|------|-------|-------------|
| Inspection / full_inspection | `#F5C33B` (honey gold) | `[3, 4]` |
| Treatment | `#FF8A65` (warm orange) | `[2, 3]` |
| Feeding | `#81C784` (soft green) | `[5, 3]` |
| Harvest | `#FFD54F` (amber) | `[4, 4]` |
| Weather / automated | `#64B5F6` (sky blue) | `[2, 3]` |
| Seasonal / automated | `#81C784` (soft green) | `[5, 3]` |

**In production:** `LogEntry.type` is already an enum with 7 values. Map each to a color + dash pattern. Read log entries via `getLogEntriesForHive()` stream alongside `getCpsReadings()`.

---

## Decision 8: CPS Delta on Log Rows

**What it does:** Each log row shows the CPS change in the 7 days following that log entry. Green `▲ +8.4 pts / 7d` or red `▼ -2.1 pts / 7d`.

**Calculation:**
```dart
double? cpsDeltaAfterDate(DateTime date, {int days = 7}) {
  final baseIdx = _indexForDate(dailyData, date);
  final futureIdx = _indexForDate(dailyData, date.add(Duration(days: days)));
  if ((futureIdx - baseIdx).abs() < 3) return null; // too close
  return dailyData[futureIdx].score - dailyData[baseIdx].score;
}
```

**Why `< 3` guard:** Avoids noise from readings taken on adjacent days that happen to be the "closest" to the target date.

**In production:** The same calculation works against Firestore daily aggregates from `getCpsReadings()`. Pre-compute deltas when the log list loads; cache them. Don't recompute on every rebuild.

---

## Decision 9: Tap Log Row → Chart Scrolls to That Date

**Behaviour:** Tapping a log row animates the chart to centre that date. If in Intraday zoom, auto-switches to Weekly first.

```dart
void scrollToDate(DateTime date) {
  if (zoom == ZoomLevel.intraday) {
    zoom = ZoomLevel.weekly;
    visiblePoints = 7;
  }
  final idx = _indexForDate(data, date);
  _animateTo((idx - visiblePoints / 2).clamp(0, maxViewportStart));
}
```

**In production:** The log list and chart currently live on separate screens. This feature requires co-locating them — either on the hive profile screen or a dedicated chart+log screen. The prototype puts both in a single `SingleChildScrollView` which works well on mobile.

---

## Decision 10: Active Log Row Highlighting

**Behaviour:** As the user pans the chart, the log row whose date is closest to the viewport centre highlights with a subtle `kAccent.withValues(alpha: 0.08)` background and accent-colored text.

**Implementation:** `controller.visibleCentreDate` — compare against each log's date in the list's `ListenableBuilder`. The controller notifies on every pan frame; the list rebuilds accordingly.

**Performance note:** `ListView.builder` with `shrinkWrap: true` inside a `SingleChildScrollView` is acceptable for 8–20 log entries. For longer lists, use `AutomaticKeepAliveClientMixin` or limit to the 20 most recent entries.

---

## Decision 11: Weather on Weekly X-Axis

**Decision:** Weekly zoom (7 visible days) shows a stacked x-axis: date label → weather emoji → high/low temp. Monthly and Intraday leave the x-axis minimal.

**Why weekly only:** 7 stacked items at ~45px each is readable. 30 items at monthly scale would be 11px each — illegible. Intraday shows hours, not days.

**Data model:**
```dart
enum WeatherCondition { sunny, partlyCloudy, cloudy, rainy, stormy, snowy }

class WeatherDay {
  final DateTime date;
  final WeatherCondition condition;
  final int highC;
  final int lowC;
}
```

**Reserved x-axis height:** 68px in weekly (vs 36px for monthly, 22px for intraday).

**In production:** Wire to a real weather API (OpenWeatherMap historical data works well) keyed by `apiaryId` and date. Store weather as a separate Firestore subcollection or cache locally. The chart widget should accept a `Map<String, WeatherDay>? weather` parameter — null-safe, degrades gracefully to date-only labels.

---

## Decision 12: Automated Log Entries

**What we added:** Two new `LogType` values — `weather` and `seasonal` — auto-generated from weather events and calendar milestones. These appear in the log list alongside manual inspections with distinct type badges.

**Why:** Beekeepers often don't log context. Automated entries (storms, frost, heat waves, seasonal transitions) fill the gap and help explain CPS anomalies without requiring beekeeper action.

**In production:** `LogEntry.source` already has `aiAssisted` and `observation` values — add `automated` or repurpose `aiAssisted`. Generate these server-side in a Cloud Function triggered by weather API webhooks or a daily scheduler. Store in the same `logEntries` subcollection.

---

## Decision 13: Accent Color — Honey Gold

**Color:** `#F5C33B` — warm golden yellow, clearly honey-related, readable on dark backgrounds.

**Previous:** `#4FFFB0` (mint green) — too generic, not evocative of beekeeping.

**Full palette:**
```dart
const kAccent          = Color(0xFFF5C33B); // honey gold — primary
const kMarkerInspection = Color(0xFFF5C33B); // same
const kMarkerWeather    = Color(0xFF64B5F6); // sky blue
const kMarkerSeasonal   = Color(0xFF81C784); // soft green
const kSurface          = Color(0xFF1E2530);
const kSurface2         = Color(0xFF161920);
const kBg               = Color(0xFF0D0F14);
const kNightBlue        = Color(0xFF0D1B3E);
```

**In production:** `cps_chart.dart` currently uses hardcoded hex colors throughout. Extract to a central `AppColors` or `CpsChartTheme` class and update all references.

---

## Decision 14: Timescale Selector as Dropdown

**What we built:** `zoom_toggle.dart` — `PopupMenuButton<ZoomLevel>` with current value + chevron.

**Why:** `SegmentedButton` with 3 options takes ~200px of horizontal space. A dropdown is ~100px, leaves more room for the hive name, and scales to more zoom levels without layout changes. Right-aligned for right-handed reach.

**Menu shows:** Current selection with a checkmark. Tapping opens: Intraday / Weekly / Monthly.

**In production:** `cps_chart.dart` uses horizontal tab buttons for range selection. Replace with a `PopupMenuButton` aligned to the trailing edge of the chart header row.

---

## Decision 15: M3 Top App Bar with Hive Context

**What we built:** Native `AppBar` with M3 theme, two-line title (hive name + apiary · CPS), trailing `⋮` menu.

**Menu items:** Edit Hive Details, Add Inspection, ─, Move to Apiary, Duplicate Hive, ─, Archive Hive, Delete Hive (red).

**Key M3 config:**
```dart
AppBar(
  backgroundColor: kBg,
  surfaceTintColor: Colors.transparent, // prevents M3 surface tint
  elevation: 0,
  title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...]),
  actions: [PopupMenuButton(...)],
)
```

**Subtitle formula:** `'${apiary.name}  ·  CPS ${latestCps.toStringAsFixed(1)}'`

**In production:** `hive_profile.dart` has a basic AppBar. The chart is embedded in `SensorsScreen`. The right home for this combined view is a dedicated `HiveChartScreen` that takes a `Hive` and `Sensor` as arguments.

---

## Suggested Implementation Order for Production Agent

1. **Extract colors** → create `lib/theme/app_colors.dart`, update `cps_chart.dart` references
2. **Viewport controller** → create `lib/widgets/chart_viewport_controller.dart` alongside `cps_chart.dart`
3. **Swipe + momentum** → add `GestureDetector` to `cps_chart.dart`, wire to controller
4. **Haptics** → add `vibration` package, add listener in chart widget `initState`
5. **Y-axis removal** → set `reservedSize: 0`, add ghost "0"/"100" labels
6. **Center-anchored x labels** → update `getTitlesWidget` in `cps_chart.dart`
7. **Log markers on chart** → add `visibleLogMarkers()` to controller, add `extraLinesData.verticalLines`
8. **CPS delta on log rows** → add `cpsDeltaAfterDate()` to controller, update `log_entry_list_item.dart`
9. **Tap log → scroll chart** → add `scrollToDate()` to controller, wire from `log_entry_list_item.dart`
10. **Weather x-axis** → add `WeatherDay` model, wire to weekly labels
11. **Dropdown zoom selector** → replace tab buttons in `cps_chart.dart` header
12. **AppBar** → update `hive_profile.dart` or create `HiveChartScreen`

---

## Prototype Source Reference

All patterns above are implemented and working in:

```
alveary-charts-prototype/lib/demo/
  app_colors.dart               ← color palette
  chart_viewport_controller.dart ← viewport, pan, zoom, scrollToDate, delta, markers, weather
  cps_line_chart.dart           ← fl_chart config, weather axis, marker rendering
  cps_mock_data.dart            ← data models (LogType, InspectionLog, CpsReading)
  weather_data.dart             ← WeatherCondition, WeatherDay, generator
  inspection_table.dart         ← log list with delta badge, type dot, tap-to-scroll
  zoom_toggle.dart              ← dropdown zoom selector
  chart_demo_screen.dart        ← M3 AppBar, screen layout
  night_overlay.dart            ← intraday night shoulders + moon phase
  moon_phase.dart               ← moonPhase() + moonIcon()
```
