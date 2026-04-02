# Chart Demo Spec — CPS Scrollable Chart

## Goal

A standalone Flutter demo screen that proves out:
1. Scrollable/swipeable line+area chart of Colony Performance Score
2. Animated prev/next buttons
3. Night gap handling with visual treatment
4. Zoom level switching (intraday → daily → monthly)

---

## Dependencies

```yaml
# pubspec.yaml
dependencies:
  fl_chart: ^0.70.0
  intl: ^0.19.0        # date formatting on x-axis
```

---

## Architecture

### State

```dart
enum ZoomLevel { intraday, weekly, monthly }

class ChartState {
  final ZoomLevel zoom;
  final List<CpsReading> data;       // pre-filtered for current viewport
  final double viewportStart;        // data index offset
  final int visiblePoints;           // depends on zoom level
}
```

### Data viewport pattern

Never pass all data to fl_chart. Maintain a sliding window:
- `minX` / `maxX` are the only values that change on pan
- Slice `data.sublist(start, start + visiblePoints)` and re-index x from 0
- This keeps render cost flat regardless of total dataset size

### Visible point counts by zoom

| Zoom      | Visible points | x-axis label format |
|-----------|---------------|---------------------|
| Intraday  | All day (~34) | `HH:mm`             |
| Weekly    | 7 days        | `EEE`               |
| Monthly   | 30 days       | `MMM d`             |

---

## Night gap handling (intraday only)

### Approach: compressed daylight axis + night shoulders

- x-axis runs **06:30 → 20:00** only — no midnight-to-midnight
- Flanks (before 06:30 / after 20:00) are rendered as a **deep blue shaded region**
- Sunrise and sunset positions are marked with icon annotations

### Implementation in fl_chart

```dart
// Night shading via RangeAnnotation
RangeAnnotations(
  verticalRangeAnnotations: [
    VerticalRangeAnnotation(
      x1: -0.5,
      x2: 0,              // left shoulder = before first reading
      color: Color(0xFF0D1B3E).withOpacity(0.6),
    ),
    VerticalRangeAnnotation(
      x1: lastReadingIndex.toDouble(),
      x2: lastReadingIndex + 0.5,
      color: Color(0xFF0D1B3E).withOpacity(0.6),
    ),
  ],
)
```

### Moon phase icon

Compute moon phase from date using this formula (no package needed):

```dart
int moonPhase(DateTime date) {
  // Returns 0–29 (0 = new moon, 14–15 = full moon)
  final synodicMonth = 29.53058867;
  final knownNewMoon = DateTime(2000, 1, 6);
  final daysSince = date.difference(knownNewMoon).inDays;
  return (daysSince % synodicMonth).floor();
}

String moonIcon(int phase) {
  if (phase < 2 || phase > 27) return '🌑';
  if (phase < 8) return '🌒';
  if (phase < 10) return '🌓';
  if (phase < 15) return '🌔';
  if (phase < 17) return '🌕';
  if (phase < 22) return '🌖';
  if (phase < 24) return '🌗';
  return '🌘';
}
```

Place the moon icon as a `Stack` overlay above the chart at the right edge,
not as an fl_chart annotation (fl_chart widget annotations don't support emoji well).

---

## Interactions

### Swipe/pan

```dart
GestureDetector(
  onHorizontalDragStart: (d) { /* capture start position */ },
  onHorizontalDragUpdate: (d) {
    // convert pixel delta → data units
    // shift viewportStart, clamp to [0, maxViewport]
    // setState()
  },
  onHorizontalDragEnd: (d) {
    // momentum fling: use d.velocity.pixelsPerSecond.dx
    // AnimationController to coast to rest
  },
  child: LineChart(...),
)
```

### Animated nav buttons

```dart
// Shift by 60% of visible window per tap
void _shiftLeft() => _animateTo(_viewportStart - visiblePoints * 0.6);
void _shiftRight() => _animateTo(_viewportStart + visiblePoints * 0.6);

void _animateTo(double target) {
  _animation = Tween<double>(
    begin: _viewportStart,
    end: target.clamp(0, maxViewportStart),
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ))..addListener(() => setState(() => _viewportStart = _animation.value));
  _controller.forward(from: 0);
}
```

### Zoom level toggle

Simple `SegmentedButton` or tab row above the chart:
`Intraday | Week | Month`

Switching zoom level:
1. Replaces data slice with appropriate aggregation tier
2. Resets `viewportStart` to show most recent data
3. Updates x-axis label format

---

## Chart styling

```dart
LineChartData(
  lineBarsData: [
    LineChartBarData(
      spots: visibleSpots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: const Color(0xFF4FFFB0),       // mint green
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
    getDrawingHorizontalLine: (_) => FlLine(
      color: Colors.white10,
      strokeWidth: 1,
    ),
  ),
  borderData: FlBorderData(show: false),
  minY: 0,
  maxY: 100,
)
```

---

## Screen layout

```
┌─────────────────────────────────┐
│  Colony Performance Score       │  ← title + date
│  [Intraday] [Week] [Month]      │  ← zoom toggle
├─────────────────────────────────┤
│                                 │
│   🌙  [chart area]  ☀️          │  ← moon/sun overlaid as Stack
│                                 │
├─────────────────────────────────┤
│      [ ‹ ]           [ › ]      │  ← animated nav buttons
└─────────────────────────────────┘
```

---

## Files to create

```
lib/
  demo/
    chart_demo_screen.dart     ← main screen widget
    cps_mock_data.dart         ← data model + generation functions
    chart_viewport_notifier.dart ← ChangeNotifier for pan/zoom state
    moon_phase.dart            ← moonPhase() + moonIcon() helpers
    night_annotation.dart      ← night shading widget/overlay
```
