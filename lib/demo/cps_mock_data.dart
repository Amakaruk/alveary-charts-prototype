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
  const baseline = 84.0; // peak summer day

  while (time.isBefore(DateTime(2024, 6, 15, 20, 0))) {
    final score = _intradayScore(time, baseline, rng);
    readings.add(CpsReading(timestamp: time, score: score));
    time = time.add(Duration(minutes: 25 + rng.nextInt(10) - 5));
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
// Daily averages — 180 days starting Dec 19 2023, ending Jun 15 2024
// Seasonal arc: winter low (~45) → spring buildup → summer peak (~84)
// ---------------------------------------------------------------------------

List<CpsReading> generateDailyAverages() {
  final readings = <CpsReading>[];
  final startDate = DateTime(2023, 12, 19);
  final rng = Random(42);

  for (int d = 0; d < 180; d++) {
    final date = startDate.add(Duration(days: d));
    final t = d / 179.0; // 0 = Dec 19, 1 = Jun 15

    // Seasonal arc: slow winter rise, steep spring, peak in June
    final base = 44.0 + 40.0 * _seasonCurve(t);

    // ~14-day undulation (foraging cycles, brood pulses) ±7
    final undulation = 7.0 * sin(t * 14 * pi);

    // Daily noise ±6
    final noise = (rng.nextDouble() - 0.5) * 12;

    // Narrative shocks matching the log events
    final shock = _narrativeShock(date);

    final score = (base + undulation + noise + shock).clamp(28.0, 95.0);
    readings.add(CpsReading(timestamp: date, score: score));
  }
  return readings;
}

// Slow start, accelerates through spring, plateaus near peak
double _seasonCurve(double t) {
  if (t < 0.5) return 2 * t * t;
  return 1.0 - pow(-2 * t + 2, 2) / 2;
}

// Dips tied to weather/event log entries
double _narrativeShock(DateTime d) {
  // Polar vortex Feb 4–9: hard dip
  if (d.month == 2 && d.day >= 4 && d.day <= 9)  return -14.0;
  // Late frost Mar 14–17
  if (d.month == 3 && d.day >= 14 && d.day <= 17) return -10.0;
  // Post-swarm split recovery Apr 1–6
  if (d.month == 4 && d.day >= 1  && d.day <= 6)  return -8.0;
  // Heat wave May 19–23
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
