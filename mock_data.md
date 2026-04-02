# Mock Data — Colony Performance Score

## Overview

Colony Performance Score (CPS) is a value from **0–100** representing hive health.
Readings are taken **every 20–30 minutes during daylight hours only**.

---

## Data Shape

```dart
class CpsReading {
  final DateTime timestamp;
  final double score; // 0.0–100.0
}
```

---

## Generation Strategy

### Intraday (raw readings)

- Daylight window: **06:30 → 20:00** (varies by season — use a fixed window for the demo)
- Reading interval: every **25 minutes** ± random jitter of ±5 min
- That yields roughly **32–36 readings per day**
- Score behaviour:
  - Starts at a baseline of **60–75** at sunrise
  - Rises gently through the morning foraging peak (~**10:00–13:00**)
  - Dips slightly mid-afternoon (~**14:00–16:00**) — heat stress
  - Recovers slightly before dropping as foragers return at dusk
  - Add ±3–5 point random noise per reading
  - Clamp to **[20, 98]** — never perfectly 0 or 100

```dart
double generateScore(DateTime t, double baseline) {
  final hour = t.hour + t.minute / 60.0;
  // morning rise
  final morningPeak = 12 * exp(-pow(hour - 11.0, 2) / 8);
  // afternoon dip
  final afternoonDip = -6 * exp(-pow(hour - 15.0, 2) / 4);
  final noise = (Random().nextDouble() - 0.5) * 6;
  return (baseline + morningPeak + afternoonDip + noise).clamp(20, 98);
}
```

### Daily averages (for week/month view)

- One `double` per day = mean of that day's raw readings
- Trend: slight upward drift over spring, plateau in summer, decline in autumn
- Add ±2 point day-to-day variation

### Hourly averages (optional middle tier)

- Mean of all readings within each clock hour
- Used if you add a 3–5 day zoom level

---

## Demo Dataset Sizes

| Zoom level      | Collection         | Points to generate |
|-----------------|--------------------|--------------------|
| Single day      | Raw readings       | ~34                |
| 7-day           | Hourly averages    | ~95 (14 hrs × 7)   |
| 30-day          | Daily averages     | 30                 |
| 90-day          | Daily averages     | 90                 |

---

## Hardcoded seed data (single day)

Use `DateTime(2024, 6, 15)` as the demo date.
Seed the random generator with a fixed value so the chart is reproducible.

```dart
List<CpsReading> generateDemoDay() {
  final rng = Random(42);
  final readings = <CpsReading>[];
  var time = DateTime(2024, 6, 15, 6, 30);
  double baseline = 65;

  while (time.isBefore(DateTime(2024, 6, 15, 20, 0))) {
    final hour = time.hour + time.minute / 60.0;
    final morningPeak = 12 * exp(-pow(hour - 11.0, 2) / 8);
    final afternoonDip = -6 * exp(-pow(hour - 15.0, 2) / 4);
    final noise = (rng.nextDouble() - 0.5) * 6;
    final score = (baseline + morningPeak + afternoonDip + noise).clamp(20.0, 98.0);
    readings.add(CpsReading(timestamp: time, score: score));
    time = time.add(Duration(minutes: 25 + rng.nextInt(10) - 5));
  }
  return readings;
}
```
