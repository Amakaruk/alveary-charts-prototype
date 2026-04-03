import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';
import 'cps_mock_data.dart';

class InspectionTable extends StatefulWidget {
  final ChartViewportController controller;
  final List<InspectionLog> logs;

  const InspectionTable({
    super.key,
    required this.controller,
    required this.logs,
  });

  @override
  State<InspectionTable> createState() => _InspectionTableState();
}

class _InspectionTableState extends State<InspectionTable> {
  InspectionLog? _selectedLog;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        // Build a flat list: month headers inserted whenever the month changes.
        // Dividers appear between consecutive rows but NOT adjacent to headers.
        final items = <Widget>[];
        String? lastMonthKey;
        int? lastYear;
        bool prevWasRow = false;

        for (int i = 0; i < widget.logs.length; i++) {
          final log = widget.logs[widget.logs.length - 1 - i];
          final monthKey = '${log.date.year}-${log.date.month}';

          // Year divider only when crossing into a different year (not at top).
          if (lastYear != null && log.date.year != lastYear) {
            items.add(_YearDivider(year: log.date.year, p: p));
            prevWasRow = false;
          }
          lastYear = log.date.year;

          if (monthKey != lastMonthKey) {
            items.add(_MonthHeader(date: log.date, p: p));
            lastMonthKey = monthKey;
            prevWasRow = false;
          }

          if (prevWasRow) {
            items.add(Divider(
              color: p.onSurfaceSubtle,
              height: 1,
              indent: 16,
              endIndent: 16,
            ));
          }

          final isSelected = _selectedLog != null &&
              _isSameDay(log.date, _selectedLog!.date);
          items.add(_InspectionRow(
            log: log,
            isActive: isSelected,
            onTap: () {
              widget.controller.scrollToDate(log.date);
              widget.controller.selectDate(log.date);
              setState(() => _selectedLog = log);
            },
            onClose: () {
              widget.controller.selectDate(null);
              setState(() => _selectedLog = null);
            },
          ));
          prevWasRow = true;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Month section header
// ---------------------------------------------------------------------------

class _MonthHeader extends StatelessWidget {
  final DateTime date;
  final AppPalette p;

  const _MonthHeader({required this.date, required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        DateFormat('MMMM').format(date),
        style: TextStyle(
          color: p.onSurfaceLow,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _YearDivider extends StatelessWidget {
  final int year;
  final AppPalette p;

  const _YearDivider({required this.year, required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: p.onSurfaceSubtle, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              year.toString(),
              style: TextStyle(
                color: p.onSurfaceLow,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(child: Divider(color: p.onSurfaceSubtle, height: 1)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row — responsive layout
// >= 600px: single-line table cells (date | type | note | CPS)
//  < 600px: stacked (date + type / note / CPS)
// ---------------------------------------------------------------------------

class _InspectionRow extends StatelessWidget {
  final InspectionLog log;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _InspectionRow({
    required this.log,
    required this.isActive,
    required this.onTap,
    required this.onClose,
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
          onTap: () {
            onTap(); // scroll chart to this date
            _showDetail(context, log, onClose: onClose);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isActive
                  ? p.onSurface.withValues(alpha: 0.06)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  width: 2,
                  color: typeColor.withValues(alpha: isActive ? 0.85 : 0.3),
                ),
              ),
            ),
            child: isWide
                ? _WideRow(log: log, typeLabel: typeLabel)
                : _NarrowRow(log: log, typeLabel: typeLabel),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Wide row — single line, fixed-width columns
// ---------------------------------------------------------------------------

class _WideRow extends StatelessWidget {
  final InspectionLog log;
  final String typeLabel;

  const _WideRow({required this.log, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = TextStyle(color: p.onSurfaceMed, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Text(log.date.day.toString(), style: style),
          ),
          SizedBox(
            width: 82,
            child: Text(typeLabel, style: style),
          ),
          Expanded(
            child: Text(
              log.note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(log.cps.round().toString(), style: style),
              Text('CPS', style: TextStyle(color: p.onSurfaceLow, fontSize: 10)),
            ],
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
  final String typeLabel;

  const _NarrowRow({required this.log, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = TextStyle(color: p.onSurfaceMed, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(log.date.day.toString(), style: style),
                    const SizedBox(width: 8),
                    Text(
                      typeLabel,
                      style: TextStyle(color: p.onSurfaceMed, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  log.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.onSurfaceMed, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(log.cps.round().toString(), style: style),
              Text('CPS', style: TextStyle(color: p.onSurfaceLow, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Adaptive detail — bottom sheet on mobile, side sheet on wide screens
// ---------------------------------------------------------------------------

void _showDetail(BuildContext context, InspectionLog log,
    {required VoidCallback onClose}) {
  final isWide = MediaQuery.of(context).size.width >= 600;
  if (isWide) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, animation, _) {
        final width = (MediaQuery.of(ctx).size.width * 0.4).clamp(320.0, 440.0);
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: SafeArea(child: _LogDetailSideSheet(log: log)),
            ),
          ),
        );
      },
    ).then((_) => onClose());
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (_) => _LogDetailBottomSheet(log: log),
    ).then((_) => onClose());
  }
}

// Shared header + notes content used by both sheet variants.
class _LogDetailContent extends StatelessWidget {
  final InspectionLog log;
  const _LogDetailContent({required this.log});

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                typeLabel,
                style: TextStyle(color: p.onSurface, fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('MMM d').format(log.date),
                style: TextStyle(color: p.onSurfaceMed, fontSize: 12),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: p.onSurfaceLow, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(log.cps.round().toString(),
                        style: TextStyle(color: p.onSurface, fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text('CPS',
                        style: TextStyle(color: p.onSurfaceMed, fontSize: 9)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.close, color: p.onSurfaceMed, size: 20),
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
                Text('Notes',
                    style: TextStyle(color: p.onSurfaceLow, fontSize: 10,
                        fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(log.note,
                    style: TextStyle(color: p.onSurfaceMed, fontSize: 14,
                        height: 1.6)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Bottom sheet — rounded top, drag handle, 65% screen height.
class _LogDetailBottomSheet extends StatelessWidget {
  final InspectionLog log;
  const _LogDetailBottomSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
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
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: p.onSurfaceLow,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Expanded(child: _LogDetailContent(log: log)),
        ],
      ),
    );
  }
}

// Side sheet — full height, rounded left edge.
class _LogDetailSideSheet extends StatelessWidget {
  final InspectionLog log;
  const _LogDetailSideSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: _LogDetailContent(log: log),
    );
  }
}
