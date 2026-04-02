# CPS Chart Demo — Project Spec for Claude Code

## Project Overview

Build a self-contained Flutter demo screen that proves out a scrollable,
time-series line/area chart for **Colony Performance Score (CPS)** — a
0–100 health metric for honeybee hives. All data is mocked locally. No
backend, no Firestore, no auth. The goal is a working, polished prototype
that validates the chart interactions and visual design before integrating
into the production app.

---

## Goals

1. **Scrollable chart** — the user can swipe left/right to pan through
   time, and tap animated prev/next buttons to jump by a fixed interval.
2. **Zoom levels** — three tiers: Intraday (raw readings), Week (hourly
   averages), Month (daily averages). Switching zoom resets the viewport
   to the most recent data.
3. **Night gap treatment** — intraday view only. Nighttime hours are not
   plotted but are visually represented with a deep blue shaded region,
   a moon icon (correct phase for the demo date), and sun icons at the
   daylight boundaries.
4. **Realistic mock data** — generated deterministically from a seeded
   random function so the chart looks the same every run. Follows a
   natural daily CPS curve (morning rise, afternoon dip, evening
   decline).
5. **Production-quality feel** — smooth 60fps pan, momentum fling on
   swipe release, haptic feedback on button taps, no jank.

---

## Tech Stack

- **Flutter** (stable channel)
- **fl_chart: ^0.70.0** — charting
- **intl: ^0.19.0** — date/time formatting for x-axis labels

No other packages. All moon phase math and data generation is pure Dart.

---

## File Structure

Create all files under `lib/demo/`:

```
lib/
  demo/
    chart_demo_screen.dart        ← root screen widget + layout
    cps_mock_data.dart            ← CpsReading model + data generators
    chart_viewport_controller.dart ← pan/zoom state + animation logic
    moon_phase.dart               ← moonPhase(date) + moonIcon(phase)
    night_overlay.dart            ← night shading + sun/moon icon layer
    zoom_toggle.dart              ← segmented zoom level control widget
    cps_line_chart.dart           ← fl_chart configuration widget
```

Entry point: add a route or call `ChartDemoScreen()` directly from
`main.dart` for the demo.

---

## Data Model

### `cps_mock_data.dart`

```dart
class CpsReading {
  final DateTime timestamp;
  final double score; // 0.0–100.0, clamped to [20, 98]
}
```

### Intraday generator

- Daylight window: `06:30 → 20:00` on `DateTime(2024, 6, 15)`
- Interval: 25 minutes ± random jitter (±5 min), seeded `Random(42)`
- Score curve:
  - Baseline: 65
  - Morning peak: `+12` centred at 11:00 (Gaussian, σ²=8)
  - Afternoon dip: `−6` centred at 15:00 (Gaussian, σ²=4)
  - Noise: ±3 per reading
  - Clamp to `[20.0, 98.0]`

```dart
import 'dart:math';

List<CpsReading> generateDemoDay() {
  final rng = Random(42);
  final readings = <CpsReading>[];
  var time = DateTime(2024, 6, 15, 6, 30);
  const baseline = 65.0;

  while (time.isBefore(DateTime(2024, 6, 15, 20, 0))) {
    final hour = time.hour + time.minute / 60.0;
    final morningPeak = 12 * exp(-pow(hour - 11.0, 2) / 8);
    final afternoonDip = -6 * exp(-pow(hour - 15.0, 2) / 4);
    final noise = (rng.nextDouble() - 0.5) * 6;
    final score = (baseline + morningPeak + afternoonDip + noise)
        .clamp(20.0, 98.0);
    readings.add(CpsReading(timestamp: time, score: score));
    time = time.add(Duration(minutes: 25 + rng.nextInt(10) - 5));
  }
  return readings;
}
```

### Weekly generator (hourly averages)

- 7 days ending on `2024-06-15`
- One point per daylight hour (06:00–20:00 = 14 points/day = 98 points total)
- Score: same curve shape per day, with a ±3 day-level offset seeded per day

### Monthly generator (daily averages)

- 30 days ending on `2024-06-15`
- One `double` per day = simulated daily mean
- Gentle upward trend (+0.3/day) with ±2 noise, clamped to `[40, 90]`

---

## Viewport / Pan Logic

### `chart_viewport_controller.dart`

Extend `ChangeNotifier`. Owns:

```dart
double viewportStart = 0;      // data index of left edge
int visiblePoints;             // depends on zoom level
int totalPoints;               // total data length
```

Key methods:

```dart
double get maxViewportStart => (totalPoints - visiblePoints).toDouble();
double get progress => viewportStart / maxViewportStart;

// Called by GestureDetector
void onDragStart(double localX) { ... }
void onDragUpdate(double localX, double chartWidth) {
  // pixel delta → data units: delta / chartWidth * visiblePoints
  // update viewportStart, clamp, notifyListeners()
}
void onDragEnd(double velocityPx) {
  // momentum: target = viewportStart + (−velocity / chartWidth * visiblePoints * 0.35)
  // animateTo(target)
}

// Called by buttons
void shiftLeft() => animateTo(viewportStart - visiblePoints * 0.6);
void shiftRight() => animateTo(viewportStart + visiblePoints * 0.6);

void animateTo(double target) {
  // AnimationController, CurvedAnimation(Curves.easeOutCubic), 400ms
  // clamp target to [0, maxViewportStart]
  // notifyListeners() in addListener callback
}
```

**Data slicing** — always re-index x from 0 for the chart:

```dart
List<FlSpot> get visibleSpots {
  final start = viewportStart.floor();
  final end = (start + visiblePoints + 1).clamp(0, totalPoints);
  return data
      .sublist(start, end)
      .asMap()
      .entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.score))
      .toList();
}
```

---

## Chart Configuration

### `cps_line_chart.dart`

Wrap `LineChart` in a `GestureDetector` connected to the controller.

```dart
LineChartData(
  minX: 0,
  maxX: visiblePoints.toDouble(),
  minY: 0,
  maxY: 100,

  lineBarsData: [
    LineChartBarData(
      spots: controller.visibleSpots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: const Color(0xFF4FFFB0),    // mint green
      barWidth: 2,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4FFFB0).withOpacity(0.25),
            Color(0xFF4FFFB0).withOpacity(0.0),
          ],
        ),
      ),
      dotData: FlDotData(show: false),
    ),
  ],

  gridData: FlGridData(
    drawVerticalLine: false,
    horizontalInterval: 20,
    getDrawingHorizontalLine: (_) =>
        FlLine(color: Colors.white10, strokeWidth: 1),
  ),

  borderData: FlBorderData(show: false),

  titlesData: FlTitlesData(
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 20,
        reservedSize: 32,
        getTitlesWidget: (v, _) => Text(
          v.toInt().toString(),
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        getTitlesWidget: (v, _) => _xLabel(v), // format by zoom level
      ),
    ),
    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
  ),

  // Night shading — intraday only, via RangeAnnotation on flanks
  rangeAnnotations: zoom == ZoomLevel.intraday
      ? RangeAnnotations(
          verticalRangeAnnotations: [
            VerticalRangeAnnotation(
              x1: -0.5, x2: 0,
              color: const Color(0xFF0D1B3E).withOpacity(0.5),
            ),
          ],
        )
      : null,
)
```

### Touch tooltip

```dart
lineTouchData: LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    tooltipBgColor: const Color(0xFF1E2530),
    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
      '${s.y.toStringAsFixed(1)}',
      const TextStyle(color: Color(0xFF4FFFB0), fontWeight: FontWeight.bold),
    )).toList(),
  ),
),
```

---

## Night Overlay

### `night_overlay.dart`

Rendered as a `Stack` child on top of the chart. Visible in intraday zoom only.

- **Left shoulder** (pre-sunrise): dark blue `Container` with `☀️` icon
  pinned to its right edge
- **Right shoulder** (post-sunset): dark blue `Container` with `☀️` icon
  pinned to its left edge
- **Moon icon**: positioned top-centre of the right shoulder
  - Compute phase from `moonPhase(DateTime(2024, 6, 15))`
  - Display `moonIcon(phase)` as a `Text` widget

The shoulder width is fixed at ~14% of chart width for the demo (represents
~2 hours of non-daylight padding on each side).

---

## Moon Phase

### `moon_phase.dart`

```dart
/// Returns 0–29 where 0 = new moon, 14–15 = full moon
int moonPhase(DateTime date) {
  const synodicMonth = 29.53058867;
  final knownNewMoon = DateTime(2000, 1, 6);
  final daysSince = date.difference(knownNewMoon).inDays;
  return (daysSince % synodicMonth).floor();
}

String moonIcon(int phase) {
  if (phase < 2 || phase > 27) return '🌑';
  if (phase < 8)  return '🌒';
  if (phase < 10) return '🌓';
  if (phase < 15) return '🌔';
  if (phase < 17) return '🌕';
  if (phase < 22) return '🌖';
  if (phase < 24) return '🌗';
  return '🌘';
}
```

---

## Zoom Toggle

### `zoom_toggle.dart`

A simple `SegmentedButton<ZoomLevel>` with three segments:

```
[ Intraday ]  [ Week ]  [ Month ]
```

On selection:
1. Update `ZoomLevel` in controller
2. Swap data set (intraday → weekly → monthly generators)
3. Reset `viewportStart` to show most recent data (`maxViewportStart`)
4. Update `visiblePoints` count

| Zoom      | `visiblePoints` |
|-----------|----------------|
| Intraday  | all (~34)       |
| Week      | 14 (2 days)     |
| Month     | 14 (2 weeks)    |

---

## Screen Layout

### `chart_demo_screen.dart`

```
Scaffold (bg: #0D0F14)
└── Column
    ├── Padding
    │   ├── Text "Colony Performance Score"  (title, white)
    │   └── Text "June 15, 2024"            (subtitle, white54)
    ├── ZoomToggle
    ├── SizedBox(height: 320)
    │   └── Stack
    │       ├── CpsLineChart (with GestureDetector)
    │       └── NightOverlay (visible if intraday)
    └── Row (nav buttons)
        ├── _NavButton(icon: Icons.chevron_left, onTap: controller.shiftLeft)
        ├── Expanded(child: _ProgressBar)   ← thin scrubber showing position
        └── _NavButton(icon: Icons.chevron_right, onTap: controller.shiftRight)
```

### Nav buttons

- `IconButton` wrapped in a `Container` with rounded border
- `HapticFeedback.lightImpact()` on each tap
- Disable (grey out) left button when `viewportStart == 0`,
  right button when `viewportStart == maxViewportStart`

### Progress bar

Thin `LinearProgressIndicator` (value: `controller.progress`) between the
nav buttons. Shows the user where in the full dataset they are.
Use `Color(0xFF4FFFB0)` for the active colour.

---

## Colour Palette

| Token            | Hex         | Usage                        |
|------------------|-------------|------------------------------|
| Background       | `#0D0F14`   | Scaffold                     |
| Surface          | `#161920`   | Cards, tooltip bg            |
| Accent           | `#4FFFB0`   | Line, area fill, progress    |
| Night blue       | `#0D1B3E`   | Night shoulder overlay       |
| Text primary     | `#FFFFFF`   |                              |
| Text secondary   | `#FFFFFF89` | Subtitle, axis labels        |
| Grid lines       | `#FFFFFF1A` | Horizontal chart grid        |

---

## Acceptance Criteria

- [ ] Intraday chart loads and displays ~34 data points on first render
- [ ] Swiping left/right pans the chart smoothly at 60fps
- [ ] Releasing a swipe with velocity produces a momentum coast
- [ ] Prev/next buttons animate the chart with easeOutCubic, 400ms
- [ ] Haptic feedback fires on button tap
- [ ] Buttons disable correctly at dataset boundaries
- [ ] Progress bar tracks pan position in real time
- [ ] Zoom toggle switches data tier and resets viewport
- [ ] Night overlay is visible in intraday, hidden in week/month
- [ ] Moon icon shows correct phase for June 15, 2024
- [ ] Tooltip appears on touch with formatted score value
- [ ] No errors or jank on a mid-range Android or iOS device
