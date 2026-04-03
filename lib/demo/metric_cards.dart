import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';

class MetricCards extends StatelessWidget {
  final ChartViewportController controller;

  const MetricCards({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Exclude the left-edge ghost point (x < 0) used by 1D/1W zoom.
        final scores = controller.visibleSpots
            .where((s) => s.x >= 0)
            .map((s) => s.y)
            .toList();
        if (scores.isEmpty) return const SizedBox.shrink();

        final avg = scores.reduce((a, b) => a + b) / scores.length;
        final peak = scores.reduce(max);
        final low = scores.reduce(min);
        final trend = scores.last - scores.first;
        final trendLabel = '${trend >= 0 ? '+' : ''}${trend.round()}';

        final p = AppPalette.of(context);
        final isWide = MediaQuery.of(context).size.width >= 600;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _MetricCard(label: 'AVG',  value: avg.round().toString(),  p: p),
              const SizedBox(width: 8),
              _MetricCard(label: 'PEAK', value: peak.round().toString(), p: p),
              const SizedBox(width: 8),
              _MetricCard(label: 'LOW',  value: low.round().toString(),  p: p),
              if (isWide) ...[
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'TREND',
                  value: trendLabel,
                  valueColor: trend >= 0 ? null : p.onSurfaceMed,
                  p: p,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final AppPalette p;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.p,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: p.onSurfaceSubtle, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? p.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: p.onSurfaceLow,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
