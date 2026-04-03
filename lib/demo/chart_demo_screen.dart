import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';
import 'cps_line_chart.dart';
import 'cps_mock_data.dart';
import 'hive_task.dart';
import 'inspection_table.dart';
import 'night_overlay.dart';
import 'zoom_toggle.dart';

// Demo constants
const _demoDate = '2024-06-15';
final _demoNow = DateTime(2024, 6, 15);
final _nextInspectionDate = DateTime(2024, 7, 15);

class ChartDemoScreen extends StatefulWidget {
  const ChartDemoScreen({super.key});

  @override
  State<ChartDemoScreen> createState() => _ChartDemoScreenState();
}

class _ChartDemoScreenState extends State<ChartDemoScreen>
    with TickerProviderStateMixin {
  late final ChartViewportController _controller;
  late List<HiveTask> _tasks;

  @override
  void initState() {
    super.initState();
    _controller = ChartViewportController(vsync: this);
    _tasks = List.of(mockHiveTasks);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTaskFromRecommendation(Recommendation rec) {
    setState(() {
      _tasks = [
        ..._tasks,
        HiveTask(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: rec.title,
          source: rec.source,
        ),
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to Jul 15 inspection'),
        backgroundColor: AppPalette.of(context).surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(p),
            _buildChart(p),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUpcoming(p),
                    _buildTodayDivider(p),
                    InspectionTable(
                      controller: _controller,
                      logs: mockInspectionLogs,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader(AppPalette p) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final delta = _controller.recentTrendDelta;
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: p.onSurface, size: 22),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hive 3',
                      style: TextStyle(
                        color: p.onSurface.withValues(alpha: 0.45),
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _controller.latestCps.round().toString(),
                          style: GoogleFonts.notoSans(
                            color: p.onSurface,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: -1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'CPS',
                                style: TextStyle(
                                  color: p.onSurface.withValues(alpha: 0.45),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (delta != null) _TrendBadge(delta: delta),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ZoomToggle(
                selected: _controller.zoom,
                onChanged: _controller.setZoom,
              ),
              PopupMenuButton<_HiveAction>(
                onSelected: _onHiveAction,
                color: p.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                icon: Icon(Icons.more_vert, color: p.onSurface),
                itemBuilder: (context) => [
                  _menuItem(p, _HiveAction.edit, Icons.edit_outlined,
                      'Edit Hive Details'),
                  _menuItem(p, _HiveAction.addInspection,
                      Icons.add_circle_outline, 'Add Inspection'),
                  const PopupMenuDivider(),
                  _menuItem(p, _HiveAction.move, Icons.swap_horiz,
                      'Move to Apiary'),
                  _menuItem(p, _HiveAction.duplicate, Icons.copy_outlined,
                      'Duplicate Hive'),
                  const PopupMenuDivider(),
                  _menuItem(p, _HiveAction.archive, Icons.archive_outlined,
                      'Archive Hive'),
                  _menuItem(p, _HiveAction.delete, Icons.delete_outline,
                      'Delete Hive',
                      color: const Color(0xFFFF6B6B)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Chart — fixed height so zoom changes don't shift the layout
  // ---------------------------------------------------------------------------
  Widget _buildChart(AppPalette p) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final xAxisHeight = switch (_controller.zoom) {
          ZoomLevel.intraday => 26.0,
          ZoomLevel.weekly   => 76.0,
          ZoomLevel.monthly  => 42.0,
        };
        return SizedBox(
          height: 280, // fixed — no layout jump on zoom change
          child: Stack(
            children: [
              CpsLineChart(controller: _controller, logs: mockInspectionLogs),
              if (_controller.zoom == ZoomLevel.intraday)
                const Positioned.fill(
                    child: IgnorePointer(child: NightOverlay())),
              Positioned(
                left: 0,
                right: 0,
                bottom: xAxisHeight,
                child: IgnorePointer(
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      value: _controller.progress,
                      backgroundColor: p.onSurfaceSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(p.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Upcoming section
  // ---------------------------------------------------------------------------
  Widget _buildUpcoming(AppPalette p) {
    final daysAway = _nextInspectionDate.difference(_demoNow).inDays;
    final taskCount = _tasks.where((t) => !t.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── UPCOMING label ─────────────────────────────────────────
        _SectionLabel(label: 'UPCOMING'),

        // ── Planned inspection row ─────────────────────────────────
        _PlannedInspectionRow(
          date: _nextInspectionDate,
          daysAway: daysAway,
          taskCount: taskCount,
        ),

        // ── Schedule inspection affordance ─────────────────────────
        InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: p.onSurfaceLow, size: 13),
                const SizedBox(width: 8),
                Text('Schedule inspection',
                    style: TextStyle(color: p.onSurfaceLow, fontSize: 12)),
              ],
            ),
          ),
        ),

        // ── SUGGESTED label ────────────────────────────────────────
        _SectionLabel(label: 'SUGGESTED'),

        // ── Suggestion rows ────────────────────────────────────────
        ...mockRecommendations.map((r) => _SuggestedRow(
              rec: r,
              onAssign: () => _addTaskFromRecommendation(r),
            )),

        const SizedBox(height: 8),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Today divider — temporal anchor between future and past
  // ---------------------------------------------------------------------------
  Widget _buildTodayDivider(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: p.onSurfaceSubtle, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _demoDate,
              style: TextStyle(
                color: p.onSurfaceLow,
                fontSize: 10,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(child: Divider(color: p.onSurfaceSubtle, height: 1)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Menu helpers
  // ---------------------------------------------------------------------------
  PopupMenuItem<_HiveAction> _menuItem(
    AppPalette p,
    _HiveAction action,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final c = color ?? p.onSurfaceMed;
    return PopupMenuItem<_HiveAction>(
      value: action,
      child: Row(
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: c, fontSize: 14)),
        ],
      ),
    );
  }

  void _onHiveAction(_HiveAction action) {
    final p = AppPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(action.label),
        backgroundColor: p.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Planned inspection row — matches log row visual language
// ---------------------------------------------------------------------------

class _PlannedInspectionRow extends StatelessWidget {
  final DateTime date;
  final int daysAway;
  final int taskCount;

  const _PlannedInspectionRow({
    required this.date,
    required this.daysAway,
    required this.taskCount,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Planned bar uses a muted forward-looking teal to distinguish from past
    const planColor = Color(0xFF64B5F6);

    return InkWell(
      onTap: () {}, // stub — future: open planned inspection detail
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Type bar — same pattern as log rows
            Container(width: 2, color: planColor.withValues(alpha: 0.55)),
            Expanded(
              child: Builder(
                builder: (context) {
                  final isWide = MediaQuery.of(context).size.width >= 600;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                        12, isWide ? 8 : 10, 12, isWide ? 8 : 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Date
                        if (isWide)
                          SizedBox(
                            width: 52,
                            child: Text(
                              DateFormat('MMM d').format(date),
                              style: TextStyle(
                                color: p.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Text(
                            DateFormat('MMM d').format(date),
                            style: TextStyle(
                              color: p.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Type label
                        if (isWide)
                          SizedBox(
                            width: 82,
                            child: Text('Planned',
                                style: TextStyle(
                                    color: p.onSurfaceMed, fontSize: 12)),
                          )
                        else
                          Text('Planned',
                              style: TextStyle(
                                  color: p.onSurfaceMed, fontSize: 12)),
                        if (!isWide) const SizedBox(width: 8),
                        // Days away — expands on both layouts
                        Expanded(
                          child: Text(
                            '$daysAway days away',
                            style: TextStyle(
                                color: p.onSurfaceLow, fontSize: 12),
                          ),
                        ),
                        // Task count badge
                        if (taskCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$taskCount task${taskCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: p.onSurfaceMed,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            color: p.onSurfaceLow, size: 18),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Suggested row — compact, tappable, opens detail sheet
// ---------------------------------------------------------------------------

class _SuggestedRow extends StatelessWidget {
  final Recommendation rec;
  final VoidCallback onAssign;

  const _SuggestedRow({required this.rec, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final urgColor = recommendationColor(rec.urgency);
    final urgLabel = recommendationLabel(rec.urgency);

    return InkWell(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.only(right: 10, top: 1),
              decoration: BoxDecoration(
                color: p.onSurfaceLow,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                rec.title,
                style: TextStyle(color: p.onSurfaceMed, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: urgColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                urgLabel,
                style: TextStyle(
                  color: urgColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: p.onSurfaceLow, size: 16),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    if (isWide) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black26,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, anim1, anim2) => Align(
          alignment: Alignment.centerRight,
          child: _SuggestedDetailPanel(rec: rec, onAssign: onAssign),
        ),
        transitionBuilder: (ctx, anim, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SuggestedDetailPanel(rec: rec, onAssign: onAssign),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Suggested detail panel — bottom sheet (mobile) / right panel (desktop)
// ---------------------------------------------------------------------------

class _SuggestedDetailPanel extends StatelessWidget {
  final Recommendation rec;
  final VoidCallback onAssign;

  const _SuggestedDetailPanel({
    required this.rec,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isWide = MediaQuery.of(context).size.width >= 600;
    final urgColor = recommendationColor(rec.urgency);
    final urgLabel = recommendationLabel(rec.urgency);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag handle (mobile only)
        if (!isWide)
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
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        urgLabel,
                        style: TextStyle(
                          color: urgColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rec.title,
                      style: TextStyle(
                        color: p.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (rec.source != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        rec.source!,
                        style: TextStyle(
                            color: p.onSurfaceLow, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: p.onSurfaceMed, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(color: p.onSurfaceSubtle, height: 1),
        // Scrollable body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.detail,
                  style: TextStyle(
                    color: p.onSurfaceMed,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Steps',
                  style: TextStyle(
                    color: p.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                ...rec.actionItems.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 10, top: 1),
                            decoration: BoxDecoration(
                              color: p.onSurface.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                color: p.onSurface,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.value,
                              style: TextStyle(
                                color: p.onSurfaceMed,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        // Sticky footer
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.onSurfaceSubtle)),
          ),
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAssign();
            },
            style: FilledButton.styleFrom(
              backgroundColor: p.onSurface,
              foregroundColor: p.bg,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add to Hive 3',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );

    if (isWide) {
      final screenHeight = MediaQuery.of(context).size.height;
      return Material(
        color: p.bg,
        child: SizedBox(width: 400, height: screenHeight, child: content),
      );
    }

    // Mobile: bottom sheet with rounded top
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          color: p.onSurfaceLow,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trend badge
// ---------------------------------------------------------------------------

class _TrendBadge extends StatelessWidget {
  final double delta;
  const _TrendBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isPos = delta >= 0;
    final color = isPos ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B);
    final sign = isPos ? '+' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isPos ? Icons.north : Icons.south, color: color, size: 10),
        const SizedBox(width: 2),
        Text(
          '$sign${delta.toStringAsFixed(1)}  ·  7d',
          style: TextStyle(
            color: p.onSurfaceMed,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hive action menu
// ---------------------------------------------------------------------------

enum _HiveAction {
  edit,
  addInspection,
  move,
  duplicate,
  archive,
  delete;

  String get label => switch (this) {
        _HiveAction.edit          => 'Edit Hive Details',
        _HiveAction.addInspection => 'Add Inspection',
        _HiveAction.move          => 'Move to Apiary',
        _HiveAction.duplicate     => 'Duplicate Hive',
        _HiveAction.archive       => 'Archive Hive',
        _HiveAction.delete        => 'Delete Hive',
      };
}
