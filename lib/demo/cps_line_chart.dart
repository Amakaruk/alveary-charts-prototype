import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'chart_viewport_controller.dart';
import 'cps_mock_data.dart';
import 'app_colors.dart';
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
      Vibration.vibrate(duration: 15, amplitude: 80);
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
      // Show label only at the first data point within each hour.
      if (absIdx == 0) return '${ts.hour}:00';
      final prevTs = c.timestampAt(absIdx - 1);
      if (prevTs.hour == ts.hour) return null;
      return '${ts.hour.toString().padLeft(2, '0')}:00';
    }

    // Weekly / monthly: anchor labels to viewport centre so one always lands
    // in the middle of the screen.
    final centerAbs = c.viewportStart.floor() + c.visiblePoints ~/ 2;
    final interval = c.zoom == ZoomLevel.weekly ? 1 : 5;
    if ((absIdx - centerAbs) % interval != 0) return null;

    return switch (c.zoom) {
      ZoomLevel.intraday => '', // unreachable
      ZoomLevel.weekly => DateFormat('EEE\nMMM d').format(ts),
      ZoomLevel.monthly => DateFormat('MMM d').format(ts),
    };
  }

  @override
  Widget build(BuildContext context) {
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
              Widget chart = _buildChart(widget.controller, widget.logs);
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

  Widget _buildChart(ChartViewportController c, List<InspectionLog> logs) {
    final spots = c.visibleSpots;
    final isIntraday = c.zoom == ZoomLevel.intraday;
    final lastX = spots.isNotEmpty ? spots.last.x : 0.0;
    final markers = c.visibleLogMarkers(logs);
    final tipIdx = _tooltipSpotIndex;
    final barData = LineChartBarData(
      spots: spots,
      isCurved: false,
      color: kAccent,
      barWidth: 2,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kAccent.withValues(alpha: 0.22),
            kAccent.withValues(alpha: 0.0),
          ],
        ),
      ),
      dotData: const FlDotData(show: false),
      showingIndicators: tipIdx != null ? [tipIdx] : [],
    );

    return LineChart(
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
                    weather: c.weatherForDate(
                        c.timestampAt(c.viewportStart.floor() + v.toInt())),
                  );
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0x89FFFFFF), fontSize: 11),
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
                style: const TextStyle(
                    color: Color(0x33FFFFFF),
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
                style: const TextStyle(
                    color: Color(0x33FFFFFF),
                    fontSize: 9,
                    fontWeight: FontWeight.w500),
                labelResolver: (_) => '0',
              ),
            ),
          ],
          verticalLines: markers.map((m) {
            final color = switch (m.log.type) {
              LogType.inspection => kMarkerInspection,
              LogType.weather    => kMarkerWeather,
              LogType.seasonal   => kMarkerSeasonal,
            };
            final dash = switch (m.log.type) {
              LogType.inspection => [3, 4],
              LogType.weather    => [2, 3],
              LogType.seasonal   => [5, 3],
            };
            return VerticalLine(
              x: m.x,
              color: color.withValues(alpha: 0.5),
              strokeWidth: 1,
              dashArray: dash,
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 4),
                style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 8),
                labelResolver: (_) => '▲',
              ),
            );
          }).toList(),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => kSurface,
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final absIdx = c.viewportStart.floor() + s.spotIndex;
              final ts = c.timestampAt(absIdx);
              return LineTooltipItem(
                '${s.y.toStringAsFixed(1)}\n',
                const TextStyle(
                    color: kAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                children: [
                  TextSpan(
                    text: DateFormat('MMM d').format(ts),
                    style: const TextStyle(
                        color: Color(0x89FFFFFF),
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
  }

  double _xReservedSize(ChartViewportController c) => switch (c.zoom) {
        ZoomLevel.intraday => 26,
        ZoomLevel.weekly   => 76,
        ZoomLevel.monthly  => 42,
      };
}

// ---------------------------------------------------------------------------
// Weekly x-axis label: date + weather icon + high/low temp
// ---------------------------------------------------------------------------

class _WeatherAxisLabel extends StatelessWidget {
  final TitleMeta meta;
  final String dateLabel;
  final WeatherDay? weather;

  const _WeatherAxisLabel({
    required this.meta,
    required this.dateLabel,
    required this.weather,
  });

  @override
  Widget build(BuildContext context) {
    return SideTitleWidget(
      meta: meta,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x89FFFFFF), fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            weather != null ? weatherEmoji(weather!.condition) : '—',
            style: const TextStyle(fontSize: 13, height: 1),
          ),
          const SizedBox(height: 2),
          Text(
            weather != null
                ? '${weather!.highC}°/${weather!.lowC}°'
                : '',
            style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 9),
          ),
        ],
      ),
    );
  }
}
