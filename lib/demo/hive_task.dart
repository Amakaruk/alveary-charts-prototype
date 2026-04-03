import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Hive profile (static mock — in production returned by the server)
// ---------------------------------------------------------------------------

class HiveProfile {
  final String name;
  final String apiary;
  final String hiveType;
  final String colonyType;
  final String queenStatus;
  final String queenAge;
  final String varroaStatus;
  final String population;
  final String broodPattern;
  final List<String> equipment;

  const HiveProfile({
    required this.name,
    required this.apiary,
    required this.hiveType,
    required this.colonyType,
    required this.queenStatus,
    required this.queenAge,
    required this.varroaStatus,
    required this.population,
    required this.broodPattern,
    required this.equipment,
  });
}

const mockHiveProfile = HiveProfile(
  name: 'Hive A',
  apiary: 'Meadow View Apiary',
  hiveType: 'Langstroth 10-frame',
  colonyType: 'Italian (Apis mellifera ligustica)',
  queenStatus: 'Laying — confirmed May 2024',
  queenAge: '14 months',
  varroaStatus: '1.2 mites / 100 bees (last wash: May 28)',
  population: 'Strong — approx. 55,000–60,000',
  broodPattern: 'Solid, low-disease pattern on 7 of 10 frames',
  equipment: [
    '2× medium honey supers (both active)',
    'Screened bottom board',
    'Entrance reducer removed for summer',
    '8-frame queen excluder',
  ],
);

const mockAiSummaryTeaser =
    'Colony thriving at peak nectar flow — CPS up 6 pts this week.';

const mockAiSummaryParagraph =
    'Your colony is in excellent condition heading into the height of the '
    'summer nectar flow. The CPS trend has been consistently positive over '
    'the past seven days, driven by strong forager activity and a solid, '
    'disease-free brood pattern across most frames. Varroa levels remain well '
    'below the action threshold. Both honey supers are actively being worked, '
    'and at the current fill rate you should expect to assess harvest readiness '
    'within 10–14 days. The main watchpoints for the coming week are swarm '
    'readiness — the colony is populous and the queen is healthy, so frame '
    'congestion is worth monitoring — and ensuring adequate ventilation during '
    'the forecast warm spell. No immediate interventions are required; your '
    'next scheduled inspection is on track.';

// ---------------------------------------------------------------------------
// Task
// ---------------------------------------------------------------------------

class HiveTask {
  final String id;
  final String title;
  final String? source; // stub for future KB article link
  final bool completed;

  const HiveTask({
    required this.id,
    required this.title,
    this.source,
    this.completed = false,
  });

  HiveTask copyWith({bool? completed}) => HiveTask(
        id: id,
        title: title,
        source: source,
        completed: completed ?? this.completed,
      );
}

final mockHiveTasks = [
  const HiveTask(
    id: '1',
    title: 'Replace old brood comb in frame 4',
    source: 'Comb Management',
  ),
  const HiveTask(id: '2', title: 'Order replacement queen excluder'),
  const HiveTask(
    id: '3',
    title: 'Schedule late-season varroa treatment',
    source: 'Varroa Management',
  ),
];

// ---------------------------------------------------------------------------
// Recommendation
//
// Production: these are returned by a server-side rules engine operating on
// the full hive profile (colony state, mite load, season, management history,
// environmental factors). The app renders whatever it receives — no
// client-side derivation logic.
// ---------------------------------------------------------------------------

enum RecommendationUrgency { high, medium, low }

class Recommendation {
  final String title;
  final String detail;
  final List<String> actionItems;
  final RecommendationUrgency urgency;
  final String? source;

  const Recommendation({
    required this.title,
    required this.detail,
    required this.actionItems,
    required this.urgency,
    this.source,
  });
}

Color recommendationColor(RecommendationUrgency u) => switch (u) {
      RecommendationUrgency.high   => const Color(0xFFF87171),
      RecommendationUrgency.medium => const Color(0xFFFACC15),
      RecommendationUrgency.low    => const Color(0xFF4ADE80),
    };

String recommendationLabel(RecommendationUrgency u) => switch (u) {
      RecommendationUrgency.high   => 'HIGH',
      RecommendationUrgency.medium => 'MED',
      RecommendationUrgency.low    => 'LOW',
    };

// Static mock — representative of what the server would return for a healthy
// June colony at peak nectar flow with no active alerts.
const mockRecommendations = [
  Recommendation(
    title: 'Schedule varroa mite wash',
    urgency: RecommendationUrgency.medium,
    source: 'Varroa Management',
    detail:
        'Mite populations typically peak during summer brood rearing, just '
        'before the nectar flow ends. Treating now gives the colony time to '
        'raise a clean generation of winter bees — the long-lived bees that '
        'will carry the colony through to spring.',
    actionItems: [
      'Prepare a 200 ml alcohol wash with 70% isopropyl solution.',
      'Collect a sample of ~300 bees from a brood frame (avoid the queen).',
      'Shake the jar for 60 seconds and count mites in the liquid.',
      'If count exceeds 2 mites per 100 bees, begin treatment immediately.',
      'Record mite count and treatment date in the inspection log.',
    ],
  ),
  Recommendation(
    title: 'Assess swarm readiness',
    urgency: RecommendationUrgency.medium,
    source: 'Swarm Prevention',
    detail:
        'A strong, healthy colony trending upward in late spring is a prime '
        'swarm candidate. Colonies swarm when they run out of space or when '
        'the queen is old. Catching the signs early — crowding, queen cells, '
        'backfilling of brood frames with honey — gives you options.',
    actionItems: [
      'Check all frames for charged queen cells, especially along the bottom bars.',
      'Assess whether brood frames are being backfilled with nectar (congestion sign).',
      'If congested, add a super or perform a split within the next 7 days.',
      'If queen cells are present and capped, the swarm impulse is already underway.',
      'Consider a walk-away split or introducing a new queen to a split half.',
    ],
  ),
  Recommendation(
    title: 'Check honey super progress',
    urgency: RecommendationUrgency.low,
    source: 'Honey Production',
    detail:
        'June is peak nectar flow in most temperate regions. Supers can fill '
        'faster than expected during a good flow — a full super left too long '
        'can back-fill the brood nest and trigger swarming. Checking every '
        '10–14 days during flow keeps you ahead of it.',
    actionItems: [
      'Lift the super and assess weight — a full medium super weighs ~18 kg.',
      'Check the top frames: if 80% capped, the super is ready to harvest.',
      'If uncapped honey is present, test moisture content with a refractometer (target < 18.5%).',
      'Add an empty super above the existing one if frames are more than 70% full.',
      'Note harvest weight and date in the hive log for year-on-year comparison.',
    ],
  ),
];
