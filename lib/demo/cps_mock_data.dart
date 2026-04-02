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
  var time = DateTime(2024, 6, 15, 6, 30);
  const baseline = 65.0;

  while (time.isBefore(DateTime(2024, 6, 15, 20, 0))) {
    final score = _scoreAt(time, baseline, rng);
    readings.add(CpsReading(timestamp: time, score: score));
    time = time.add(Duration(minutes: 25 + rng.nextInt(10) - 5));
  }
  return readings;
}

// ---------------------------------------------------------------------------
// Daily averages — 180 days ending 2024-06-15, one point per day
// ---------------------------------------------------------------------------

List<CpsReading> generateDailyAverages() {
  final readings = <CpsReading>[];
  final endDate = DateTime(2024, 6, 15);

  for (int d = 179; d >= 0; d--) {
    final date = endDate.subtract(Duration(days: d));
    final daySeed = date.year * 10000 + date.month * 100 + date.day;
    final rng = Random(daySeed);
    final dayOffset = (rng.nextDouble() - 0.5) * 8;
    final baseline = 62.0 + dayOffset;
    final noon = DateTime(date.year, date.month, date.day, 12, 0);
    final score = _scoreAt(noon, baseline, rng).clamp(40.0, 90.0);
    readings.add(CpsReading(timestamp: date, score: score));
  }
  return readings;
}

double _scoreAt(DateTime t, double baseline, Random rng) {
  final hour = t.hour + t.minute / 60.0;
  final morningPeak = 12 * exp(-pow(hour - 11.0, 2) / 8);
  final afternoonDip = -6 * exp(-pow(hour - 15.0, 2) / 4);
  final noise = (rng.nextDouble() - 0.5) * 6;
  return (baseline + morningPeak + afternoonDip + noise).clamp(20.0, 98.0);
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
