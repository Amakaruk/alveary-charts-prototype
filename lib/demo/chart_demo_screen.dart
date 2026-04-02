import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      appBar: _buildAppBar(context),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Timescale selector — right-aligned
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => ZoomToggle(
                      selected: _controller.zoom,
                      onChanged: _controller.setZoom,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Chart + overlay
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final isWeekly = _controller.zoom == ZoomLevel.weekly;
                  // Taller chart in weekly to give weather labels breathing room
                  final chartHeight = isWeekly ? 300.0 : 280.0;
                  return SizedBox(
                    height: chartHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Nav row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => Row(
                    children: [
                      _NavButton(
                        icon: Icons.chevron_left,
                        onTap: _controller.viewportStart <= 0
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _controller.shiftLeft();
                              },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: _controller.progress,
                            minHeight: 3,
                            backgroundColor: const Color(0x1AFFFFFF),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(kAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _NavButton(
                        icon: Icons.chevron_right,
                        onTap: _controller.viewportStart >=
                                _controller.maxViewportStart
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _controller.shiftRight();
                              },
                      ),
                    ],
                  ),
                ),
              ),
              // Inspection log table
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

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      title: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hive Alpha',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            Text(
              'Spring Apiary  ·  CPS ${_controller.latestCps.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Color(0x89FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      actions: [
        PopupMenuButton<_HiveAction>(
          onSelected: _onHiveAction,
          color: kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          icon: const Icon(Icons.more_vert, color: Colors.white),
          itemBuilder: (context) => [
            _menuItem(_HiveAction.edit, Icons.edit_outlined, 'Edit Hive Details'),
            _menuItem(_HiveAction.addInspection, Icons.add_circle_outline, 'Add Inspection'),
            const PopupMenuDivider(),
            _menuItem(_HiveAction.move, Icons.swap_horiz, 'Move to Apiary'),
            _menuItem(_HiveAction.duplicate, Icons.copy_outlined, 'Duplicate Hive'),
            const PopupMenuDivider(),
            _menuItem(_HiveAction.archive, Icons.archive_outlined, 'Archive Hive'),
            _menuItem(
              _HiveAction.delete,
              Icons.delete_outline,
              'Delete Hive',
              color: const Color(0xFFFF6B6B),
            ),
          ],
        ),
      ],
    );
  }

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
    // Stub — wire to real actions in production
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

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? const Color(0x33FFFFFF) : const Color(0x11FFFFFF),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : const Color(0x33FFFFFF),
          size: 20,
        ),
      ),
    );
  }
}
