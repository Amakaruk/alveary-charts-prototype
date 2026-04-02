import 'package:flutter/material.dart';
import 'moon_phase.dart';

const _nightBlue = Color(0xFF0D1B3E);

class NightOverlay extends StatelessWidget {
  const NightOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = moonPhase(DateTime(2024, 6, 15));
    final icon = moonIcon(phase);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final shoulderWidth = w * 0.10;

        return Stack(
          children: [
            // Left shoulder (pre-sunrise)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: shoulderWidth,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _nightBlue.withValues(alpha:0.85),
                      _nightBlue.withValues(alpha:0.0),
                    ],
                  ),
                ),
                alignment: Alignment.centerRight,
                child: const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text('🌅', style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
            // Right shoulder (post-sunset)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: shoulderWidth,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      _nightBlue.withValues(alpha:0.85),
                      _nightBlue.withValues(alpha:0.0),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(icon, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
