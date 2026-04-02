import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chart_viewport_controller.dart';
import 'cps_mock_data.dart';
import 'app_colors.dart';

class InspectionTable extends StatelessWidget {
  final ChartViewportController controller;
  final List<InspectionLog> logs;

  const InspectionTable({
    super.key,
    required this.controller,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final centreDate = controller.visibleCentreDate;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Inspection Log',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0x1AFFFFFF),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, i) {
                final log = logs[i];
                final isActive = _isSameDay(log.date, centreDate);
                final delta = controller.cpsDeltaAfterDate(log.date);
                return _InspectionRow(
                  log: log,
                  isActive: isActive,
                  delta: delta,
                  onTap: () => controller.scrollToDate(log.date),
                );
              },
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _InspectionRow extends StatelessWidget {
  final InspectionLog log;
  final bool isActive;
  final double? delta;
  final VoidCallback onTap;

  const _InspectionRow({
    required this.log,
    required this.isActive,
    required this.delta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isActive ? kAccent.withValues(alpha: 0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type dot + date column
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeDot(type: log.type),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d\nyyyy').format(log.date),
                    style: TextStyle(
                      color: isActive ? kAccent : const Color(0x89FFFFFF),
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Note + delta row
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xCCFFFFFF),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(height: 5),
                    _DeltaBadge(delta: delta!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // CPS badge
            _CpsBadge(score: log.cps, isActive: isActive),
          ],
        ),
      ),
    );
  }
}

class _TypeDot extends StatelessWidget {
  final LogType type;
  const _TypeDot({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      LogType.inspection => kMarkerInspection,
      LogType.weather    => kMarkerWeather,
      LogType.seasonal   => kMarkerSeasonal,
    };
    final label = switch (type) {
      LogType.inspection => 'Inspection',
      LogType.weather    => 'Weather',
      LogType.seasonal   => 'Seasonal',
    };
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9),
        ),
      ],
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double delta;

  const _DeltaBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final color = isPositive ? kAccent : const Color(0xFFFF6B6B);
    final arrow = isPositive ? '▲' : '▼';
    final sign = isPositive ? '+' : '';

    return Row(
      children: [
        Text(
          '$arrow $sign${delta.toStringAsFixed(1)} pts / 7d',
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CpsBadge extends StatelessWidget {
  final double score;
  final bool isActive;

  const _CpsBadge({required this.score, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? kAccent.withValues(alpha: 0.15)
            : const Color(0xFF1E2530),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? kAccent.withValues(alpha: 0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            score.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? kAccent : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'CPS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive
                  ? kAccent.withValues(alpha: 0.7)
                  : const Color(0x61FFFFFF),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
