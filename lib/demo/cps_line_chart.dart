import 'dart:math' show min, max;
import 'dart:ui' show PointerDeviceKind;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';
import 'cps_mock_data.dart';

class CpsLineChart extends StatefulWidget {
  final ChartViewportController controller;

  const CpsLineChart({
    super.key,
    required this.controller,
  });

  @override
  State<CpsLineChart> createState() => _CpsLineChartState();
}

class _CpsLineChartState extends State<CpsLineChart> {
  double _chartWidth = 0;
  double _lastTickBucket = -1;
  int? _tooltipSpotIndex;
  // Accumulated x position for trackpad pan-zoom simulation.
  double _trackpadPanX = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onViewportChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onViewportChanged);
    super.dispose();
  }

  void _onViewportChanged() {
    final step = switch (widget.controller.zoom) {
      ZoomLevel.oneDay     => 5.0,
      ZoomLevel.sevenDay   => 1.0,
      ZoomLevel.thirtyDay  => 7.0,
      ZoomLevel.threeMonth => 14.0,
      ZoomLevel.sixMonth   => 30.0,
      ZoomLevel.oneYear    => 30.0,
    };
    final bucket = (widget.controller.viewportStart / step).floor().toDouble();
    if (bucket != _lastTickBucket) {
      _lastTickBucket = bucket;
      if (!kIsWeb) Vibration.vibrate(duration: 15, amplitude: 80);
    }
  }

  void _onTapUp(TapUpDetails details) {
    final c = widget.controller;
    final spots = c.visibleSpots;
    if (spots.isEmpty) return;
    final fraction = (details.localPosition.dx / _chartWidth).clamp(0.0, 1.0);
    final idx = (fraction * c.visiblePoints).round().clamp(0, spots.length - 1);
    setState(() {
      _tooltipSpotIndex = _tooltipSpotIndex == idx ? null : idx;
    });
  }

  // Returns a label string if this x position should show a label, else null.
  // Two-line labels use '\n' as separator (split and rendered by getTitlesWidget).
  String? _xLabel(double x, ChartViewportController c) {
    final absIdx = c.viewportStart.floor() + x.toInt();
    final ts = c.timestampAt(absIdx);

    switch (c.zoom) {
      case ZoomLevel.oneDay:
        // Readings fall ~25 min apart. Label those within 15 min of a whole
        // even-hour mark — at most one reading lands in each window.
        // Show the rounded hour, not the actual reading time.
        if (ts.hour % 2 != 0 || ts.minute > 14) return null;
        return '${ts.hour.toString().padLeft(2, '0')}:00';

      case ZoomLevel.sevenDay:
        // One label per day; suppress right-edge cap point.
        if (x >= c.visiblePoints) return null;
        return '${DateFormat("EEE").format(ts)}\n${ts.day}'; // "Mon\n3"

      case ZoomLevel.thirtyDay:
        // Round-day anchors give ~weekly cadence → 5 labels per 30-day window.
        const labelDays = {1, 8, 15, 22, 29};
        if (!labelDays.contains(ts.day)) return null;
        return '${DateFormat("MMM").format(ts)}\n${ts.day}'; // "Jan\n8"

      case ZoomLevel.threeMonth:
        // 1st and 15th of each month → ~6 labels per 90-day window.
        if (ts.day != 1 && ts.day != 15) return null;
        if (ts.month == 1 && ts.day == 1) return 'Jan\n${ts.year}';
        return '${DateFormat("MMM").format(ts)}\n${ts.day}'; // "Mar\n15"

      case ZoomLevel.sixMonth:
        // 1st of each month → ~6 labels per 180-day window.
        if (ts.day != 1) return null;
        if (ts.month == 1) return 'Jan\n${ts.year}';
        return DateFormat('MMM').format(ts);

      case ZoomLevel.oneYear:
        // 1st of each month → 12 labels per year.
        if (ts.day != 1) return null;
        if (ts.month == 1) return 'Jan\n${ts.year}';
        return DateFormat('MMM').format(ts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _chartWidth = constraints.maxWidth;
        return Listener(
          // Trackpad two-finger pan on native macOS/iOS sends PointerPanZoom
          // events. HorizontalDragGestureRecognizer would try to synthesize a
          // PointerMoveEvent with kind=trackpad, which Flutter asserts against.
          // Handle these directly here instead.
          onPointerPanZoomStart: (e) {
            _trackpadPanX = e.localPosition.dx;
            setState(() => _tooltipSpotIndex = null);
            widget.controller.onDragStart(_trackpadPanX);
          },
          onPointerPanZoomUpdate: (e) {
            _trackpadPanX += e.panDelta.dx;
            widget.controller.onDragUpdate(_trackpadPanX, _chartWidth);
          },
          onPointerPanZoomEnd: (e) =>
              widget.controller.onDragEnd(0, _chartWidth),
          child: GestureDetector(
          supportedDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
          },
          onTapUp: _onTapUp,
          onHorizontalDragStart: (d) {
            setState(() => _tooltipSpotIndex = null);
            widget.controller.onDragStart(d.localPosition.dx);
          },
          onHorizontalDragUpdate: (d) => widget.controller
              .onDragUpdate(d.localPosition.dx, _chartWidth),
          onHorizontalDragEnd: (d) => widget.controller.onDragEnd(
            d.velocity.pixelsPerSecond.dx,
            _chartWidth,
          ),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final overscroll = widget.controller.overscrollPixels;
              Widget chart = _buildChart(widget.controller, palette);
              if (overscroll > 0) {
                chart = ClipRect(
                  child: Transform.translate(
                    offset: Offset(-overscroll, 0),
                    child: chart,
                  ),
                );
              }
              return chart;
            },
          ),
          ),
        );
      },
    );
  }

  Widget _buildChart(ChartViewportController c, AppPalette p) {
    final spots = c.visibleSpots;
    final selX = c.selectedDate != null ? c.localXForDate(c.selectedDate!) : null;

    // Dynamic Y range: pad 20% above and below the visible data on all zoom levels.
    const yPadFraction = 0.20;
    final double effectiveMinY;
    final double effectiveMaxY;
    if (spots.isNotEmpty) {
      final dataMin = spots.fold(double.infinity,        (m, s) => min(m, s.y));
      final dataMax = spots.fold(double.negativeInfinity, (m, s) => max(m, s.y));
      final range = (dataMax - dataMin).clamp(1.0, double.infinity);
      final pad = range * yPadFraction;
      effectiveMinY = dataMin - pad;
      effectiveMaxY = dataMax + pad;
    } else {
      effectiveMinY = 0;
      effectiveMaxY = 100;
    }

    // Guard against stale index after zoom change shrinks the spots list
    final tipIdx = (_tooltipSpotIndex != null && _tooltipSpotIndex! < spots.length)
        ? _tooltipSpotIndex
        : null;
    final barData = LineChartBarData(
      spots: spots,
      isCurved: false,
      color: p.accent,
      barWidth: 2,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.accent.withValues(alpha: 0.22),
            p.accent.withValues(alpha: 0.0),
          ],
        ),
      ),
      dotData: const FlDotData(show: false),
      showingIndicators: tipIdx != null ? [tipIdx] : [],
    );

    final chart = LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: (c.zoom == ZoomLevel.sevenDay || c.zoom == ZoomLevel.oneDay) ? -0.5 : 0,
        maxX: (c.zoom == ZoomLevel.sevenDay || c.zoom == ZoomLevel.oneDay)
            ? c.visiblePoints.toDouble() - 0.5
            : c.visiblePoints.toDouble(),
        minY: effectiveMinY,
        maxY: effectiveMaxY,
        clipData: const FlClipData.all(),
        lineBarsData: [barData],
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false, reservedSize: 36)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _xReservedSize,
              interval: 1,
              getTitlesWidget: (v, meta) {
                if (v < 0) return const SizedBox.shrink(); // ghost left point
                final label = _xLabel(v, c);
                if (label == null) return const SizedBox.shrink();
                final lines = label.split('\n');
                return SideTitleWidget(
                  meta: meta,
                  space: 0,
                  child: Container(
                    height: _xReservedSize,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: lines
                          .map((l) => Text(
                                l,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: p.onSurfaceMed, fontSize: 11),
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: selX != null
              ? [VerticalLine(
                  x: selX,
                  color: p.onSurfaceMed,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                )]
              : [],
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchTooltipData: LineTouchTooltipData(
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            getTooltipColor: (_) => p.surface,
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final absIdx = c.viewportStart.floor() + s.spotIndex;
              final ts = c.timestampAt(absIdx);
              return LineTooltipItem(
                '${s.y.round()}\n',
                TextStyle(
                    color: p.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                children: [
                  TextSpan(
                    text: DateFormat('MMM d').format(ts),
                    style: TextStyle(
                        color: p.onSurfaceMed,
                        fontSize: 10,
                        fontWeight: FontWeight.normal),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        showingTooltipIndicators: tipIdx != null
            ? [ShowingTooltipIndicators([LineBarSpot(barData, 0, spots[tipIdx])])]
            : [],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(child: chart),
        Divider(height: 1, thickness: 1, color: p.onSurfaceSubtle),
      ],
    );
  }

  // Fixed x-axis reserved height — same for all zoom levels so the chart
  // plot area never changes size when switching timescales.
  // Two lines at fontSize 11 ≈ 26px, centered inside 46px gives ~10px
  // padding above and below. Single-line labels get the same row height.
  static const double _xReservedSize = 46;
}

