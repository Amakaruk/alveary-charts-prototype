import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';
import 'cps_mock_data.dart';
import 'weather_data.dart';

class CpsLineChart extends StatefulWidget {
  final ChartViewportController controller;
  final List<InspectionLog> logs;

  const CpsLineChart({
    super.key,
    required this.controller,
    required this.logs,
  });

  @override
  State<CpsLineChart> createState() => _CpsLineChartState();
}

class _CpsLineChartState extends State<CpsLineChart> {
  double _chartWidth = 0;
  double _lastTickBucket = -1;
  int? _tooltipSpotIndex;

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
      ZoomLevel.intraday => 1.0,
      ZoomLevel.weekly => 7 / 30.0,
      ZoomLevel.monthly => 1.0,
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
  String? _xLabel(double x, ChartViewportController c) {
    final absIdx = c.viewportStart.floor() + x.toInt();
    final ts = c.timestampAt(absIdx);

    if (c.zoom == ZoomLevel.intraday) {
      // Show label every 3 hours to avoid crowding.
      if (ts.hour % 3 != 0) return null;
      if (absIdx > 0) {
        final prevTs = c.timestampAt(absIdx - 1);
        if (prevTs.hour == ts.hour) return null; // deduplicate within same hour
      }
      return DateFormat('ha').format(ts).toLowerCase(); // "6am", "12pm"
    }

    if (c.zoom == ZoomLevel.monthly) {
      // Show label only at month boundaries.
      if (absIdx == 0) return DateFormat('MMM').format(ts);
      final prevTs = c.timestampAt(absIdx - 1);
      if (prevTs.month == ts.month) return null;
      return DateFormat('MMM').format(ts); // "Feb", "Mar"
    }

    // Weekly: anchor to viewport centre, show every day.
    final centerAbs = c.viewportStart.floor() + c.visiblePoints ~/ 2;
    if ((absIdx - centerAbs) % 1 != 0) return null;
    return DateFormat('EEEEE\nd').format(ts); // "M\n3"
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _chartWidth = constraints.maxWidth;
        return GestureDetector(
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
              Widget chart = _buildChart(widget.controller, widget.logs, palette);
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
        );
      },
    );
  }

  Widget _buildChart(
      ChartViewportController c, List<InspectionLog> logs, AppPalette p) {
    final spots = c.visibleSpots;
    final isIntraday = c.zoom == ZoomLevel.intraday;
    final lastX = spots.isNotEmpty ? spots.last.x : 0.0;
    final markers = c.visibleLogMarkers(logs);
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
        minX: 0,
        maxX: c.visiblePoints.toDouble(),
        minY: 0,
        maxY: 100,
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
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _xReservedSize(c),
              interval: 1,
              getTitlesWidget: (v, meta) {
                final label = _xLabel(v, c);
                if (label == null) return const SizedBox.shrink();
                if (c.zoom == ZoomLevel.weekly) {
                  return _WeatherAxisLabel(
                    meta: meta,
                    dateLabel: label,
                    palette: p,
                    space: _xTitleSpace(c),
                    weather: c.weatherForDate(
                        c.timestampAt(c.viewportStart.floor() + v.toInt())),
                  );
                }
                return SideTitleWidget(
                  meta: meta,
                  space: _xTitleSpace(c),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.onSurfaceMed, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 98,
              color: Colors.transparent,
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                style: TextStyle(
                    color: p.onSurfaceLow,
                    fontSize: 9,
                    fontWeight: FontWeight.w500),
                labelResolver: (_) => '100',
              ),
            ),
            HorizontalLine(
              y: 2,
              color: Colors.transparent,
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.only(left: 6, top: 2),
                style: TextStyle(
                    color: p.onSurfaceLow,
                    fontSize: 9,
                    fontWeight: FontWeight.w500),
                labelResolver: (_) => '0',
              ),
            ),
          ],
          verticalLines: markers.map((m) {
            return VerticalLine(
              x: m.x,
              color: p.onSurface.withValues(alpha: 0.15),
              strokeWidth: 1,
            );
          }).toList(),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchTooltipData: LineTouchTooltipData(
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
        rangeAnnotations: isIntraday
            ? RangeAnnotations(
                verticalRangeAnnotations: [
                  VerticalRangeAnnotation(
                    x1: -0.5,
                    x2: 0,
                    color: kNightBlue.withValues(alpha: 0.6),
                  ),
                  VerticalRangeAnnotation(
                    x1: lastX,
                    x2: lastX + 0.5,
                    color: kNightBlue.withValues(alpha: 0.6),
                  ),
                ],
              )
            : null,
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

  double _xReservedSize(ChartViewportController c) => switch (c.zoom) {
        ZoomLevel.intraday => 26,
        ZoomLevel.weekly   => 72,
        ZoomLevel.monthly  => 30,
      };

  // Space from chart boundary to title widget — centers content in reserved area.
  // Intraday: ~14px text in 26px → (26-14)/2 = 6
  // Monthly:  ~14px text in 30px → (30-14)/2 = 8
  // Weekly:   ~52px column in 72px → (72-52)/2 = 10
  double _xTitleSpace(ChartViewportController c) => switch (c.zoom) {
        ZoomLevel.intraday => 6,
        ZoomLevel.weekly   => 10,
        ZoomLevel.monthly  => 8,
      };
}

// ---------------------------------------------------------------------------
// Weekly x-axis label: date + weather icon + high/low temp
// ---------------------------------------------------------------------------

class _WeatherAxisLabel extends StatelessWidget {
  final TitleMeta meta;
  final String dateLabel;
  final WeatherDay? weather;
  final AppPalette palette;

  final double space;

  const _WeatherAxisLabel({
    required this.meta,
    required this.dateLabel,
    required this.palette,
    required this.weather,
    this.space = 10,
  });

  @override
  Widget build(BuildContext context) {
    return SideTitleWidget(
      meta: meta,
      space: space,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.onSurfaceMed, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            weather != null ? weatherEmoji(weather!.condition) : '—',
            style: const TextStyle(fontSize: 14, height: 1),
          ),
          const SizedBox(height: 2),
          Text(
            weather != null
                ? '${weather!.highC}°/${weather!.lowC}°'
                : '',
            style: TextStyle(color: palette.onSurfaceMed, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
