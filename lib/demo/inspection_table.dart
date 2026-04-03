import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';
import 'cps_mock_data.dart';
import 'hive_task.dart';

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
  bool _autoOpenedToday = false;
  bool _todaySheetOpen = false;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _openTodayDetail(BuildContext ctx) {
    setState(() => _todaySheetOpen = true);
    _showTodayDetail(ctx, onClose: () => setState(() => _todaySheetOpen = false));
  }

  void _tapRow(BuildContext rowContext, InspectionLog log) {
    widget.controller.scrollToDate(log.date);
    widget.controller.selectDate(log.date);
    setState(() => _selectedLog = log);
    _showDetail(rowContext, log, onClose: () {
      widget.controller.autoSelectPresentIfVisible();
      setState(() => _selectedLog = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Auto-open profile sheet on wide screens (one-shot).
    final isWide = MediaQuery.of(context).size.width >= 600;
    if (isWide && !_autoOpenedToday) {
      _autoOpenedToday = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTodayDetail(context);
      });
    }
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        // Build a flat list: Today header first, then month headers and rows.
        // Dividers appear between consecutive rows but NOT adjacent to headers.
        final items = <Widget>[];
        String? lastMonthKey;
        int? lastYear;
        bool prevWasRow = false;

        // Today section header + row — always first.
        items.add(_MonthHeader(date: widget.controller.latestDate, p: p, label: 'Today'));
        items.add(_TodayRow(
          date: widget.controller.latestDate,
          cps: widget.controller.latestCps,
          isActive: _todaySheetOpen,
          onTap: (ctx) => _openTodayDetail(ctx),
        ));
        prevWasRow = true;

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
            onTap: (ctx) => _tapRow(ctx, log),
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
  final String? label;

  const _MonthHeader({required this.date, required this.p, this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label ?? DateFormat('MMMM').format(date),
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
  final void Function(BuildContext) onTap;

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
          onTap: () => onTap(context),
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
// Today row — same appearance as _InspectionRow
// ---------------------------------------------------------------------------

class _TodayRow extends StatelessWidget {
  final DateTime date;
  final double cps;
  final bool isActive;
  final void Function(BuildContext) onTap;

  const _TodayRow({
    required this.date,
    required this.cps,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isWide = MediaQuery.of(context).size.width >= 600;
    return Builder(
      builder: (ctx) => InkWell(
        onTap: () => onTap(ctx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive
                ? p.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                width: 2,
                color: p.markerInspection.withValues(alpha: isActive ? 0.85 : 0.3),
              ),
            ),
          ),
          child: isWide
              ? _TodayWideRow(date: date, cps: cps)
              : _TodayNarrowRow(date: date, cps: cps),
        ),
      ),
    );
  }
}

class _TodayWideRow extends StatelessWidget {
  final DateTime date;
  final double cps;
  const _TodayWideRow({required this.date, required this.cps});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = TextStyle(color: p.onSurfaceMed, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 32, child: Text(date.day.toString(), style: style)),
          SizedBox(width: 82, child: Text('Profile', style: style)),
          Expanded(
            child: Text(
              mockAiSummaryTeaser,
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
              Text(cps.round().toString(), style: style),
              Text('CPS', style: TextStyle(color: p.onSurfaceLow, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayNarrowRow extends StatelessWidget {
  final DateTime date;
  final double cps;
  const _TodayNarrowRow({required this.date, required this.cps});

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
                    Text(date.day.toString(), style: style),
                    const SizedBox(width: 8),
                    Text('Profile',
                        style: TextStyle(color: p.onSurfaceMed, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  mockAiSummaryTeaser,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.onSurfaceMed, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(cps.round().toString(), style: style),
              Text('CPS', style: TextStyle(color: p.onSurfaceLow, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today adaptive detail
// ---------------------------------------------------------------------------

void _showTodayDetail(BuildContext context, {required VoidCallback onClose}) {
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
              child: SafeArea(child: _TodayDetailSideSheet()),
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
      builder: (_) => _TodayDetailBottomSheet(),
    ).then((_) => onClose());
  }
}

class _TodayDetailContent extends StatelessWidget {
  const _TodayDetailContent();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final profile = mockHiveProfile;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                // Hero image — 16:9
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset('assets/beehive.jpg', fit: BoxFit.cover),
                ),
                // Hive name + apiary
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                  child: Text(
                    profile.name,
                    style: TextStyle(
                      color: p.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    profile.apiary,
                    style: TextStyle(color: p.onSurfaceLow, fontSize: 12),
                  ),
                ),
                // AI summary section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'TODAY\'S SUMMARY',
                    style: TextStyle(
                      color: p.onSurfaceLow,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  child: Text(
                    mockAiSummaryParagraph,
                    style: TextStyle(
                      color: p.onSurfaceMed,
                      fontSize: 13,
                      height: 1.65,
                    ),
                  ),
                ),
                Divider(
                    color: p.onSurfaceSubtle,
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                // Colony section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    'COLONY',
                    style: TextStyle(
                      color: p.onSurfaceLow,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                _ProfileRow(label: 'Hive type', value: profile.hiveType, p: p),
                _ProfileRow(label: 'Colony', value: profile.colonyType, p: p),
                _ProfileRow(label: 'Queen', value: profile.queenStatus, p: p),
                _ProfileRow(label: 'Queen age', value: profile.queenAge, p: p),
                const SizedBox(height: 8),
                Divider(
                    color: p.onSurfaceSubtle,
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                // Health section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    'HEALTH',
                    style: TextStyle(
                      color: p.onSurfaceLow,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                _ProfileRow(label: 'Varroa', value: profile.varroaStatus, p: p),
                _ProfileRow(label: 'Population', value: profile.population, p: p),
                _ProfileRow(label: 'Brood', value: profile.broodPattern, p: p),
                const SizedBox(height: 8),
                Divider(
                    color: p.onSurfaceSubtle,
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                // Equipment section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    'EQUIPMENT',
                    style: TextStyle(
                      color: p.onSurfaceLow,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                ...profile.equipment.map((e) => Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 3, 16, 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•',
                              style: TextStyle(
                                  color: p.onSurfaceLow, fontSize: 12)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e,
                              style: TextStyle(
                                  color: p.onSurfaceMed, fontSize: 12,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette p;

  const _ProfileRow({required this.label, required this.value, required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: TextStyle(color: p.onSurfaceLow, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: p.onSurfaceMed, fontSize: 12,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

Widget _todayCloseButton(BuildContext context) => Positioned(
      top: 12,
      right: 12,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Color(0x66000000),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 18),
        ),
      ),
    );

class _TodayDetailBottomSheet extends StatelessWidget {
  const _TodayDetailBottomSheet();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Stack(
          children: [
            const Positioned.fill(child: _TodayDetailContent()),
            _todayCloseButton(context),
          ],
        ),
      ),
    );
  }
}

class _TodayDetailSideSheet extends StatelessWidget {
  const _TodayDetailSideSheet();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: _TodayDetailContent()),
          _todayCloseButton(context),
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
