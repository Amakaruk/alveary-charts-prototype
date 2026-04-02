/// Returns 0–29 where 0 = new moon, 14–15 = full moon.
int moonPhase(DateTime date) {
  const synodicMonth = 29.53058867;
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
