import 'dart:math';

enum WeatherCondition { sunny, partlyCloudy, cloudy, rainy, stormy, snowy }

class WeatherDay {
  final DateTime date;
  final WeatherCondition condition;
  final int highC;
  final int lowC;

  const WeatherDay({
    required this.date,
    required this.condition,
    required this.highC,
    required this.lowC,
  });
}

String weatherEmoji(WeatherCondition c) => switch (c) {
      WeatherCondition.sunny       => '☀️',
      WeatherCondition.partlyCloudy => '⛅',
      WeatherCondition.cloudy      => '☁️',
      WeatherCondition.rainy       => '🌧',
      WeatherCondition.stormy      => '⛈',
      WeatherCondition.snowy       => '❄️',
    };

// Base high temps by month (northern hemisphere, °C)
const _baseHigh = [1, 3, 9, 15, 20, 25, 27, 26, 21, 14, 6, 2];
const _baseLow  = [-5, -4, 2, 7, 12, 16, 18, 17, 13, 7, 1, -3];

/// Generates deterministic weather for every date in [dates].
Map<String, WeatherDay> generateWeatherData(List<DateTime> dates) {
  final result = <String, WeatherDay>{};

  for (final date in dates) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final rng = Random(seed);
    final m = date.month - 1;

    final highC = _baseHigh[m] + rng.nextInt(7) - 3;
    final lowC  = _baseLow[m]  + rng.nextInt(5) - 2;

    final condition = _condition(m, rng.nextDouble());
    result[_key(date)] = WeatherDay(
      date: date,
      condition: condition,
      highC: highC,
      lowC: lowC,
    );
  }
  return result;
}

WeatherCondition _condition(int monthIndex, double r) {
  // Winter (Dec–Feb)
  if (monthIndex == 11 || monthIndex <= 1) {
    if (r < 0.30) return WeatherCondition.snowy;
    if (r < 0.55) return WeatherCondition.cloudy;
    if (r < 0.75) return WeatherCondition.partlyCloudy;
    return WeatherCondition.sunny;
  }
  // Summer (Jun–Aug)
  if (monthIndex >= 5 && monthIndex <= 7) {
    if (r < 0.38) return WeatherCondition.sunny;
    if (r < 0.62) return WeatherCondition.partlyCloudy;
    if (r < 0.78) return WeatherCondition.cloudy;
    if (r < 0.93) return WeatherCondition.rainy;
    return WeatherCondition.stormy;
  }
  // Spring / Autumn
  if (r < 0.25) return WeatherCondition.sunny;
  if (r < 0.48) return WeatherCondition.partlyCloudy;
  if (r < 0.65) return WeatherCondition.cloudy;
  if (r < 0.82) return WeatherCondition.rainy;
  return WeatherCondition.stormy;
}

String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
