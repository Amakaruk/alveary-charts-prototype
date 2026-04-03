import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';
import 'cps_line_chart.dart';
import 'cps_mock_data.dart';
import 'inspection_table.dart';
import 'metric_cards.dart';
import 'zoom_toggle.dart';

// Must match CpsLineChart._xReservedSize so overlays stay aligned.
const double _xAxisHeight = 46.0;

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
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            MetricCards(controller: _controller),
            _buildChart(p),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
  // Chart — fixed height so zoom changes don't shift the layout
  // ---------------------------------------------------------------------------
  Widget _buildChart(AppPalette p) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final chartHeight = MediaQuery.sizeOf(context).height * 0.375;
        return SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              CpsLineChart(controller: _controller),
              Positioned(
                left: 0,
                right: 0,
                bottom: _xAxisHeight,
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
              Positioned(
                right: 24,
                bottom: _xAxisHeight + 24,
                child: ZoomToggle(
                  selected: _controller.zoom,
                  onChanged: _controller.setZoom,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
