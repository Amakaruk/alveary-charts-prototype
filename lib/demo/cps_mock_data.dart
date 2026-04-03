import 'dart:math';

enum LogType { inspection, weather, seasonal }

class CpsReading {
  final DateTime timestamp;
  final double score;

  const CpsReading({required this.timestamp, required this.score});
}

class InspectionLog {
  final DateTime date;
  final String note;
  final double cps;
  final LogType type;

  const InspectionLog({
    required this.date,
    required this.note,
    required this.cps,
    this.type = LogType.inspection,
  });
}

// ---------------------------------------------------------------------------
// Intraday — ~34 raw readings for 2024-06-15
// ---------------------------------------------------------------------------

List<CpsReading> generateIntradayData() {
  final rng = Random(42);
  final readings = <CpsReading>[];

  // 7 days: Jun 9–15 2024. Baseline rises 77→84 toward the peak summer day.
  for (int dayOffset = -6; dayOffset <= 0; dayOffset++) {
    final date = DateTime(2024, 6, 15 + dayOffset);
    final baseline = 77.0 + (dayOffset + 6) * (7.0 / 6.0);
    var time = DateTime(date.year, date.month, date.day, 6, 30);
    final endTime = DateTime(date.year, date.month, date.day, 20, 0);
    while (time.isBefore(endTime)) {
      readings.add(CpsReading(
          timestamp: time, score: _intradayScore(time, baseline, rng)));
      time = time.add(Duration(minutes: 25 + rng.nextInt(10) - 5));
    }
  }
  return readings;
}

double _intradayScore(DateTime t, double baseline, Random rng) {
  final hour = t.hour + t.minute / 60.0;
  // Strong morning ramp, midday plateau, afternoon dip as foragers return
  final morningPeak = 18 * exp(-pow(hour - 10.5, 2) / 6);
  final afternoonDip = -14 * exp(-pow(hour - 15.5, 2) / 3);
  final noise = (rng.nextDouble() - 0.5) * 10;
  return (baseline + morningPeak + afternoonDip + noise).clamp(20.0, 98.0);
}

// ---------------------------------------------------------------------------
// Daily averages — 365 days starting Jun 15 2023, ending Jun 15 2024
// Seasonal arc: summer peak (84) → winter low (44) → summer peak (84)
// ---------------------------------------------------------------------------

List<CpsReading> generateDailyAverages() {
  final readings = <CpsReading>[];
  final startDate = DateTime(2023, 6, 15);
  final rng = Random(42);
  const days = 365;
  for (int d = 0; d < days; d++) {
    final date = startDate.add(Duration(days: d));
    final t = d / days.toDouble();
    final base = 64.0 + 20.0 * cos(t * 2 * pi);
    final undulation = 7.0 * sin(d / 14.0 * pi);
    final noise = (rng.nextDouble() - 0.5) * 12;
    final shock = _narrativeShock(date);
    final score = (base + undulation + noise + shock).clamp(28.0, 95.0);
    readings.add(CpsReading(timestamp: date, score: score));
  }
  return readings;
}

// Dips tied to weather/event log entries
double _narrativeShock(DateTime d) {
  // 2023 summer/fall
  if (d.year == 2023 && d.month == 7 && d.day >= 15 && d.day <= 20) return -7.0;
  if (d.year == 2023 && d.month == 8 && d.day >= 10 && d.day <= 16) return -8.0;
  if (d.year == 2023 && d.month == 9 && d.day >= 5  && d.day <= 10) return -10.0;
  if (d.year == 2023 && d.month == 10 && d.day >= 15 && d.day <= 20) return -6.0;
  // 2024 winter/spring (matching log entries)
  if (d.month == 2 && d.day >= 4  && d.day <= 9)  return -14.0;
  if (d.month == 3 && d.day >= 14 && d.day <= 17) return -10.0;
  if (d.month == 4 && d.day >= 1  && d.day <= 6)  return -8.0;
  if (d.month == 5 && d.day >= 19 && d.day <= 23) return -9.0;
  return 0.0;
}

// ---------------------------------------------------------------------------
// All logs — manual inspections + automated weather/seasonal events,
// sorted chronologically.
// ---------------------------------------------------------------------------

final List<InspectionLog> mockInspectionLogs = [
  // --- Seasonal transitions ---
  InspectionLog(
    date: DateTime(2024, 1, 5),
    note: 'Winter solstice passed. Daylight beginning to lengthen. Colony in tight cluster.',
    cps: 57.0,
    type: LogType.seasonal,
  ),
  // --- Manual inspections ---
  InspectionLog(
    date: DateTime(2024, 1, 5),
    note: 'Winter cluster tight. Adequate honey stores. Queen not spotted.',
    cps: 58.2,
  ),
  // --- Weather ---
  InspectionLog(
    date: DateTime(2024, 2, 5),
    note: 'Polar vortex — temps dropped to −14°C for 4 days. Hive insulation checked.',
    cps: 55.1,
    type: LogType.weather,
  ),
  InspectionLog(
    date: DateTime(2024, 2, 14),
    note: 'First brood frames of the year. Cluster beginning to expand.',
    cps: 61.7,
  ),
  // --- Seasonal ---
  InspectionLog(
    date: DateTime(2024, 3, 1),
    note: 'Early spring buildup underway. First dandelions observed in apiary.',
    cps: 64.0,
    type: LogType.seasonal,
  ),
  InspectionLog(
    date: DateTime(2024, 3, 3),
    note: 'Strong buildup. 6 frames of brood. Added pollen patty.',
    cps: 68.4,
  ),
  // --- Weather ---
  InspectionLog(
    date: DateTime(2024, 3, 15),
    note: 'Late frost — overnight temperatures −4°C. Foraging halted for 3 days.',
    cps: 63.8,
    type: LogType.weather,
  ),
  InspectionLog(
    date: DateTime(2024, 3, 28),
    note: 'Swarm cells found. Performed split to prevent swarming.',
    cps: 74.1,
  ),
  // --- Seasonal ---
  InspectionLog(
    date: DateTime(2024, 3, 20),
    note: 'Spring equinox. Daylight now exceeds 12 hours. Main foraging season begins.',
    cps: 69.5,
    type: LogType.seasonal,
  ),
  // --- Weather ---
  InspectionLog(
    date: DateTime(2024, 4, 8),
    note: 'Heavy storm — 52mm rainfall, sustained winds 70km/h. Checked for moisture ingress.',
    cps: 67.2,
    type: LogType.weather,
  ),
  InspectionLog(
    date: DateTime(2024, 4, 19),
    note: 'Post-split colony thriving. New queen laying well.',
    cps: 71.9,
  ),
  InspectionLog(
    date: DateTime(2024, 5, 10),
    note: 'Excellent foraging activity. Supers added for spring flow.',
    cps: 81.3,
  ),
  // --- Weather ---
  InspectionLog(
    date: DateTime(2024, 5, 20),
    note: 'Heat advisory — 37°C for 3 consecutive days. Added water source near hive.',
    cps: 76.4,
    type: LogType.weather,
  ),
  InspectionLog(
    date: DateTime(2024, 5, 30),
    note: 'Honey supers 60% full. Varroa wash — 1.2 mites per 100 bees.',
    cps: 79.6,
  ),
  // --- Seasonal ---
  InspectionLog(
    date: DateTime(2024, 6, 1),
    note: 'Peak nectar flow — clover and linden blooming. Strongest foraging of the year.',
    cps: 83.0,
    type: LogType.seasonal,
  ),
  InspectionLog(
    date: DateTime(2024, 6, 15),
    note: 'Peak summer health. Harvested first super. Queen vigorous.',
    cps: 84.5,
  ),
]..sort((a, b) => a.date.compareTo(b.date));
