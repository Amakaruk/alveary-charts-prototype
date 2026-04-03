import 'package:flutter/widgets.dart';
import 'cps_mock_data.dart';
import 'package:fl_chart/fl_chart.dart';

enum ZoomLevel { oneDay, sevenDay, thirtyDay, threeMonth, sixMonth, oneYear }

class ChartViewportController extends ChangeNotifier {
  // -------------------------------------------------------------------------
  // Data
  // -------------------------------------------------------------------------
  late List<CpsReading> _dailyData;
  late List<CpsReading> _intradayData;
  late final int _intradayPointsPerDay;

  List<CpsReading> get _activeData =>
      _zoom == ZoomLevel.oneDay ? _intradayData : _dailyData;

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------
  ZoomLevel _zoom = ZoomLevel.thirtyDay;
  double _viewportStart = 0;
  late int _visiblePoints;

  ZoomLevel get zoom => _zoom;
  double get viewportStart => _viewportStart;
  int get visiblePoints => _visiblePoints;
  int get totalPoints => _activeData.length;

  double get maxViewportStart =>
      (totalPoints - _visiblePoints).toDouble().clamp(0, double.infinity);

  double get progress =>
      maxViewportStart == 0 ? 1.0 : _viewportStart / maxViewportStart;

  // -------------------------------------------------------------------------
  // Selected date (drives dashed marker line on chart)
  // -------------------------------------------------------------------------
  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  void selectDate(DateTime? date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Viewport-relative x coordinate for [date], or null if outside the
  /// visible window. Matches fl_chart's x coordinate system.
  double? localXForDate(DateTime date) {
    final idx = _indexForDate(_activeData, date);
    if (idx == null) return null;
    final localX = idx.toDouble() - _viewportStart.floor();
    if (localX < -0.5 || localX > _visiblePoints + 0.5) return null;
    return localX;
  }

  // -------------------------------------------------------------------------
  // Overscroll (right-edge rubber band)
  // -------------------------------------------------------------------------
  double _overscrollPixels = 0;

  /// Pixels the chart should be shifted left to show rubber-band resistance.
  double get overscrollPixels => _overscrollPixels;

  // -------------------------------------------------------------------------
  // Animation
  // -------------------------------------------------------------------------
  late final AnimationController _animController;
  late final AnimationController _bounceController;
  Animation<double>? _animation;
  Animation<double>? _bounceAnimation;

  ChartViewportController({required TickerProvider vsync}) {
    _dailyData = generateDailyAverages();      // 365 days
    _intradayData = generateIntradayData();    // ~7 days of readings
    // Count readings in the last day of intraday data
    final lastDay = _intradayData.last.timestamp;
    _intradayPointsPerDay = _intradayData.where((r) =>
      r.timestamp.year == lastDay.year &&
      r.timestamp.month == lastDay.month &&
      r.timestamp.day == lastDay.day
    ).length;
    _zoom = ZoomLevel.thirtyDay;
    _visiblePoints = 30; // thirtyDay default
    _viewportStart = maxViewportStart;

    _animController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 400),
    );
    _bounceController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Visible spots for fl_chart (re-indexed x from 0)
  // -------------------------------------------------------------------------
  List<FlSpot> get visibleSpots {
    final start = _viewportStart.floor();
    // For daily zoom, include one extra point left of the viewport so the line
    // enters from the left edge rather than starting abruptly at x=0.
    final leftExtra = ((_zoom == ZoomLevel.sevenDay || _zoom == ZoomLevel.oneDay) && start > 0) ? 1 : 0;
    final end = (start + _visiblePoints + 1).clamp(0, totalPoints);
    final slice = _activeData.sublist(start - leftExtra, end);
    return slice
        .asMap()
        .entries
        .map((e) => FlSpot((e.key - leftExtra).toDouble(), e.value.score))
        .toList();
  }

  /// Latest CPS score (last point in daily data).
  double get latestCps => _dailyData.last.score;

  /// Date of the most recent data point (demo "present day").
  DateTime get latestDate => _dailyData.last.timestamp;

  /// Index within [visibleSpots] that corresponds to [selectedDate], or null
  /// if there is no selection or it falls outside the visible window.
  int? get selectedDateSpotIndex {
    final date = _selectedDate;
    if (date == null) return null;
    final localX = localXForDate(date);
    if (localX == null) return null;
    final spots = visibleSpots;
    int best = -1;
    double bestDiff = double.infinity;
    for (int i = 0; i < spots.length; i++) {
      final diff = (spots[i].x - localX).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best == -1 ? null : best;
  }

  /// Selects the latest (present) date if it falls within the current visible
  /// viewport; otherwise clears the selection. Call on initial load and
  /// whenever an inspection row selection is dismissed.
  void autoSelectPresentIfVisible() {
    if (localXForDate(latestDate) != null) {
      selectDate(latestDate);
    } else {
      selectDate(null);
    }
  }

  /// CPS change over the last 7 data days (positive = improving).
  double? get recentTrendDelta {
    if (_dailyData.length < 8) return null;
    return _dailyData.last.score - _dailyData[_dailyData.length - 8].score;
  }

  /// Returns the timestamp for the data point at absolute index [i].
  DateTime timestampAt(int i) {
    final data = _activeData;
    return data[i.clamp(0, data.length - 1)].timestamp;
  }

  // Returns the timestamp at the left edge of the visible window.
  DateTime get visibleStartDate =>
      _activeData[_viewportStart.floor().clamp(0, totalPoints - 1)].timestamp;

  // Returns the timestamp at the centre of the visible window.
  DateTime get visibleCentreDate {
    final idx =
        (_viewportStart + _visiblePoints / 2).round().clamp(0, totalPoints - 1);
    return _activeData[idx].timestamp;
  }

  // -------------------------------------------------------------------------
  // Drag / pan
  // -------------------------------------------------------------------------
  double _dragStartViewport = 0;
  double _dragStartX = 0;

  void onDragStart(double localX) {
    _animController.stop();
    _bounceController.stop();
    _overscrollPixels = 0;
    _dragStartViewport = _viewportStart;
    _dragStartX = localX;
    notifyListeners();
  }

  void onDragUpdate(double localX, double chartWidth) {
    if (chartWidth == 0) return;
    final pixelDelta = _dragStartX - localX;
    // 1.5× sensitivity multiplier
    final dataDelta = pixelDelta / chartWidth * _visiblePoints * 1.5;
    final rawTarget = _dragStartViewport + dataDelta;

    if (rawTarget > maxViewportStart) {
      // Rubber-band: allow overscroll with 0.3 damping factor
      final excessData = rawTarget - maxViewportStart;
      final excessPx = excessData / _visiblePoints * chartWidth;
      _overscrollPixels = excessPx * 0.3;
      _viewportStart = maxViewportStart;
    } else {
      _overscrollPixels = 0;
      _viewportStart = rawTarget.clamp(0.0, maxViewportStart);
    }
    notifyListeners();
  }

  void onDragEnd(double velocityPx, double chartWidth) {
    if (_overscrollPixels > 0) {
      _snapOverscrollBack();
      return;
    }
    if (chartWidth == 0) return;
    final dataDelta = -(velocityPx / chartWidth) * _visiblePoints * 0.35;
    final target = (_viewportStart + dataDelta).clamp(0.0, maxViewportStart);
    _animateTo(target);
  }

  // -------------------------------------------------------------------------
  // Button navigation
  // -------------------------------------------------------------------------
  void shiftLeft() => _animateTo(_viewportStart - _visiblePoints * 0.6);
  void shiftRight() => _animateTo(_viewportStart + _visiblePoints * 0.6);

  // -------------------------------------------------------------------------
  // Zoom switching
  // -------------------------------------------------------------------------
  void setZoom(ZoomLevel zoom) {
    if (_zoom == zoom) return;
    _overscrollPixels = 0;
    _bounceController.stop();

    // Preserve the date currently at the centre of the viewport.
    final centreDate = visibleCentreDate;

    _zoom = zoom;
    _visiblePoints = switch (zoom) {
      ZoomLevel.oneDay     => _intradayPointsPerDay,
      ZoomLevel.sevenDay   => 7,
      ZoomLevel.thirtyDay  => 30,
      ZoomLevel.threeMonth => 90,
      ZoomLevel.sixMonth   => 180,
      ZoomLevel.oneYear    => 365,
    };

    // Preserve the centre date across zoom changes.
    _viewportStart = maxViewportStart;
    final idx = _indexForDate(_activeData, centreDate);
    if (idx != null) {
      var centred = (idx - _visiblePoints / 2).clamp(0.0, maxViewportStart);
      if (zoom == ZoomLevel.sevenDay || zoom == ZoomLevel.oneDay) centred = centred.roundToDouble();
      _viewportStart = centred;
    }

    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Scroll to a specific date (used by inspection table)
  // -------------------------------------------------------------------------
  void scrollToDate(DateTime date) {
    _overscrollPixels = 0;
    _bounceController.stop();

    final idx = _indexForDate(_activeData, date);
    if (idx == null) return;

    final target =
        (idx - _visiblePoints / 2).clamp(0.0, (totalPoints - 1).toDouble());
    _animateTo(target, clampToMax: false);
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------
  void _animateTo(double target, {bool clampToMax = true}) {
    // Weekly/intraday snaps to whole-day boundaries so one day is always dead-centre.
    final snapped = (_zoom == ZoomLevel.sevenDay || _zoom == ZoomLevel.oneDay)
        ? target.roundToDouble()
        : target;
    final maxBound = clampToMax ? maxViewportStart : (totalPoints - 1).toDouble();
    final clamped = snapped.clamp(0.0, maxBound);
    _animController.stop();
    _animation = Tween<double>(begin: _viewportStart, end: clamped).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    )..addListener(() {
        _viewportStart = _animation!.value;
        notifyListeners();
      });
    _animController.forward(from: 0);
  }

  void _snapOverscrollBack() {
    final start = _overscrollPixels;
    _bounceController.stop();
    _bounceAnimation =
        Tween<double>(begin: start, end: 0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOutCubic),
    )..addListener(() {
        _overscrollPixels = _bounceAnimation!.value;
        notifyListeners();
      });
    _bounceController.forward(from: 0);
  }

  // -------------------------------------------------------------------------
  // Log marker positions (for chart overlay)
  // -------------------------------------------------------------------------

  /// Returns the local x positions (0..visiblePoints) of [logs] that fall
  /// within the current viewport.
  List<({double x, InspectionLog log})> visibleLogMarkers(
      List<InspectionLog> logs) {
    final result = <({double x, InspectionLog log})>[];
    for (final log in logs) {
      final idx = _indexForDate(_dailyData, log.date);
      if (idx == null) continue;
      final localX = idx - _viewportStart.floor().toDouble();
      if (localX < -0.5 || localX > _visiblePoints + 0.5) continue;
      result.add((x: localX, log: log));
    }
    return result;
  }

  // -------------------------------------------------------------------------
  // CPS delta after a log entry date
  // -------------------------------------------------------------------------

  /// Returns the CPS change [days] days after [date] using daily data.
  /// Positive = improvement, negative = decline, null = data unavailable.
  double? cpsDeltaAfterDate(DateTime date, {int days = 7}) {
    final baseIdx = _indexForDate(_dailyData, date);
    if (baseIdx == null) return null;
    final futureIdx = _indexForDate(
        _dailyData, date.add(Duration(days: days)));
    if (futureIdx == null || futureIdx >= _dailyData.length) return null;
    if ((futureIdx - baseIdx).abs() < 3) return null; // too close, unreliable
    return _dailyData[futureIdx].score - _dailyData[baseIdx].score;
  }

  /// Returns the index in [data] whose date is closest to [target].
  int? _indexForDate(List<CpsReading> data, DateTime target) {
    if (data.isEmpty) return null;
    int best = 0;
    int bestDiff = (data[0].timestamp.difference(target).inMinutes).abs();
    for (int i = 1; i < data.length; i++) {
      final diff = (data[i].timestamp.difference(target).inMinutes).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }
}
