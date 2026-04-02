import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';
import 'cps_line_chart.dart';
import 'cps_mock_data.dart';
import 'inspection_table.dart';
import 'night_overlay.dart';
import 'zoom_toggle.dart';

class ChartDemoScreen extends StatefulWidget {
  const ChartDemoScreen({super.key});

  @override
  State<ChartDemoScreen> createState() => _ChartDemoScreenState();
}

class _ChartDemoScreenState extends State<ChartDemoScreen>
    with TickerProviderStateMixin {
  late final ChartViewportController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChartViewportController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildChart(),
              const Divider(color: Color(0x14FFFFFF), height: 1),
              InspectionTable(
                controller: _controller,
                logs: mockInspectionLogs,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Custom header — back | CPS block | zoom toggle + menu
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final delta = _controller.recentTrendDelta;
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              // CPS block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spring Apiary',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
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
                          style: const TextStyle(
                            color: kAccent,
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: -1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'CPS',
                                style: TextStyle(
                                  color: kAccent.withValues(alpha: 0.55),
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
              // Zoom toggle
              ZoomToggle(
                selected: _controller.zoom,
                onChanged: _controller.setZoom,
              ),
              // More menu
              PopupMenuButton<_HiveAction>(
                onSelected: _onHiveAction,
                color: kSurface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                icon: const Icon(Icons.more_vert, color: Colors.white),
                itemBuilder: (context) => [
                  _menuItem(_HiveAction.edit, Icons.edit_outlined,
                      'Edit Hive Details'),
                  _menuItem(_HiveAction.addInspection,
                      Icons.add_circle_outline, 'Add Inspection'),
                  const PopupMenuDivider(),
                  _menuItem(
                      _HiveAction.move, Icons.swap_horiz, 'Move to Apiary'),
                  _menuItem(_HiveAction.duplicate, Icons.copy_outlined,
                      'Duplicate Hive'),
                  const PopupMenuDivider(),
                  _menuItem(_HiveAction.archive, Icons.archive_outlined,
                      'Archive Hive'),
                  _menuItem(
                    _HiveAction.delete,
                    Icons.delete_outline,
                    'Delete Hive',
                    color: const Color(0xFFFF6B6B),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Chart — full bleed, progress bar overlaid above x-axis
  // ---------------------------------------------------------------------------
  Widget _buildChart() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isWeekly = _controller.zoom == ZoomLevel.weekly;
        final chartHeight = isWeekly ? 280.0 : 240.0;
        final xAxisHeight = switch (_controller.zoom) {
          ZoomLevel.intraday => 26.0,
          ZoomLevel.weekly   => 76.0,
          ZoomLevel.monthly  => 42.0,
        };
        return SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              CpsLineChart(
                controller: _controller,
                logs: mockInspectionLogs,
              ),
              if (_controller.zoom == ZoomLevel.intraday)
                const Positioned.fill(
                  child: IgnorePointer(child: NightOverlay()),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: xAxisHeight,
                child: IgnorePointer(
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      value: _controller.progress,
                      backgroundColor: const Color(0x1AFFFFFF),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(kAccent),
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
  // Menu helpers
  // ---------------------------------------------------------------------------
  PopupMenuItem<_HiveAction> _menuItem(
    _HiveAction action,
    IconData icon,
    String label, {
    Color color = const Color(0xCCFFFFFF),
  }) {
    return PopupMenuItem<_HiveAction>(
      value: action,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  void _onHiveAction(_HiveAction action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(action.label),
        backgroundColor: kSurface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
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
            color: color,
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
