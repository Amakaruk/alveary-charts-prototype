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
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'LOG',
                style: TextStyle(
                  color: Color(0x4DFFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
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
                return _InspectionRow(
                  log: log,
                  isActive: isActive,
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
  final VoidCallback onTap;

  const _InspectionRow({
    required this.log,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (log.type) {
      LogType.inspection => kMarkerInspection,
      LogType.weather    => kMarkerWeather,
      LogType.seasonal   => kMarkerSeasonal,
    };
    final typeLabel = switch (log.type) {
      LogType.inspection => 'Inspection',
      LogType.weather    => 'Weather',
      LogType.seasonal   => 'Seasonal',
    };

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isActive
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.transparent,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left type accent bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 2,
                color: typeColor.withValues(alpha: isActive ? 0.9 : 0.35),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Body
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date + type label
                            Row(
                              children: [
                                Text(
                                  DateFormat('MMM d').format(log.date),
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xBFFFFFFF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  typeLabel,
                                  style: TextStyle(
                                    color: typeColor.withValues(alpha: 0.55),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            // Note — primary content
                            Text(
                              log.note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : const Color(0x89FFFFFF),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // CPS — quiet reference
                      _CpsBadge(score: log.cps, isActive: isActive),
                      // Chevron
                      IconButton(
                        icon: const Icon(
                          Icons.expand_more,
                          color: Color(0x40FFFFFF),
                          size: 20,
                        ),
                        onPressed: () => _showDetailSheet(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogDetailSheet(log: log),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

class _LogDetailSheet extends StatelessWidget {
  final InspectionLog log;
  const _LogDetailSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (log.type) {
      LogType.inspection => kMarkerInspection,
      LogType.weather    => kMarkerWeather,
      LogType.seasonal   => kMarkerSeasonal,
    };
    final typeLabel = switch (log.type) {
      LogType.inspection => 'Inspection',
      LogType.weather    => 'Weather',
      LogType.seasonal   => 'Seasonal',
    };

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2530),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Type dot + label
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM d').format(log.date),
                  style: const TextStyle(
                    color: Color(0x89FFFFFF),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                // CPS badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: kAccent.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        log.cps.toStringAsFixed(1),
                        style: const TextStyle(
                          color: kAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'CPS',
                        style: TextStyle(color: Color(0x89FFFFFF), fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0x89FFFFFF), size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Placeholder body
          const SizedBox(height: 200),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------


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
