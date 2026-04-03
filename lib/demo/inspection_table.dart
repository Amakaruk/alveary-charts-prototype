import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';
import 'cps_mock_data.dart';

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
    final p = AppPalette.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final centreDate = controller.visibleCentreDate;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                'LOG',
                style: TextStyle(
                  color: p.onSurfaceLow,
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
              separatorBuilder: (context, index) => Divider(
                color: p.onSurfaceSubtle,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, i) {
                final log = logs[i];
                final isActive =
                    _isSameDay(log.date, centreDate);
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

// ---------------------------------------------------------------------------
// Row — responsive layout
// >= 600px: single-line table cells (date | type | note | CPS | chevron)
//  < 600px: stacked (date + type / note / CPS badge)
// ---------------------------------------------------------------------------

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
    final p = AppPalette.of(context);
    final typeColor = switch (log.type) {
      LogType.inspection => p.markerInspection,
      LogType.weather    => kMarkerWeather,
      LogType.seasonal   => kMarkerSeasonal,
    };
    final typeLabel = switch (log.type) {
      LogType.inspection => 'Inspection',
      LogType.weather    => 'Weather',
      LogType.seasonal   => 'Seasonal',
    };

    return Builder(
      builder: (context) {
        final isWide = MediaQuery.of(context).size.width >= 600;
        return InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: isActive
                ? p.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Type accent bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 2,
                    color: typeColor
                        .withValues(alpha: isActive ? 0.85 : 0.3),
                  ),
                  Expanded(
                    child: isWide
                        ? _WideRow(
                            log: log,
                            isActive: isActive,
                            typeLabel: typeLabel,
                            onChevron: () => _showDetailSheet(context),
                          )
                        : _NarrowRow(
                            log: log,
                            isActive: isActive,
                            typeLabel: typeLabel,
                            onChevron: () => _showDetailSheet(context),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
// Wide row — single line, fixed-width columns
// ---------------------------------------------------------------------------

class _WideRow extends StatelessWidget {
  final InspectionLog log;
  final bool isActive;
  final String typeLabel;
  final VoidCallback onChevron;

  const _WideRow({
    required this.log,
    required this.isActive,
    required this.typeLabel,
    required this.onChevron,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date
          SizedBox(
            width: 52,
            child: Text(
              DateFormat('MMM d').format(log.date),
              style: TextStyle(
                color: p.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Type
          SizedBox(
            width: 82,
            child: Text(
              typeLabel,
              style: TextStyle(color: p.onSurfaceMed, fontSize: 12),
            ),
          ),
          // Note
          Expanded(
            child: Text(
              log.note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.onSurfaceMed, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          // CPS badge
          _CpsBadge(score: log.cps, isActive: isActive),
          // Chevron
          IconButton(
            icon: Icon(Icons.expand_more, color: p.onSurfaceLow, size: 18),
            onPressed: onChevron,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Narrow row — stacked, two-line layout
// ---------------------------------------------------------------------------

class _NarrowRow extends StatelessWidget {
  final InspectionLog log;
  final bool isActive;
  final String typeLabel;
  final VoidCallback onChevron;

  const _NarrowRow({
    required this.log,
    required this.isActive,
    required this.typeLabel,
    required this.onChevron,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d').format(log.date),
                      style: TextStyle(
                        color: isActive ? p.onSurface : p.onSurfaceMed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      typeLabel,
                      style:
                          TextStyle(color: p.onSurfaceMed, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  log.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? p.onSurface : p.onSurfaceMed,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Center(child: _CpsBadge(score: log.cps, isActive: isActive)),
          IconButton(
            icon:
                Icon(Icons.expand_more, color: p.onSurfaceLow, size: 20),
            onPressed: onChevron,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail sheet
// ---------------------------------------------------------------------------

class _LogDetailSheet extends StatelessWidget {
  final InspectionLog log;
  const _LogDetailSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final typeColor = switch (log.type) {
      LogType.inspection => p.markerInspection,
      LogType.weather    => kMarkerWeather,
      LogType.seasonal   => kMarkerSeasonal,
    };
    final typeLabel = switch (log.type) {
      LogType.inspection => 'Inspection',
      LogType.weather    => 'Weather',
      LogType.seasonal   => 'Seasonal',
    };

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: p.onSurfaceLow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: typeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        color: p.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM d').format(log.date),
                  style:
                      TextStyle(color: p.onSurfaceMed, fontSize: 12),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: p.onSurfaceLow, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        log.cps.round().toString(),
                        style: TextStyle(
                          color: p.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('CPS',
                          style: TextStyle(
                              color: p.onSurfaceMed, fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close,
                      color: p.onSurfaceMed, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: p.onSurfaceSubtle, height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: TextStyle(
                      color: p.onSurfaceLow,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    log.note,
                    style: TextStyle(
                      color: p.onSurfaceMed,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CPS badge
// ---------------------------------------------------------------------------

class _CpsBadge extends StatelessWidget {
  final double score;
  final bool isActive;

  const _CpsBadge({required this.score, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? p.onSurface.withValues(alpha: 0.08)
            : p.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? p.onSurfaceLow : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score.round().toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'CPS',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.onSurfaceMed, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
