import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'chart_viewport_controller.dart';

class ZoomToggle extends StatelessWidget {
  final ZoomLevel selected;
  final ValueChanged<ZoomLevel> onChanged;

  const ZoomToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static String _label(ZoomLevel z) => switch (z) {
        ZoomLevel.oneDay     => '1D',
        ZoomLevel.sevenDay   => '1W',
        ZoomLevel.thirtyDay  => '1M',
        ZoomLevel.threeMonth => '3M',
        ZoomLevel.sixMonth   => '6M',
        ZoomLevel.oneYear    => '1Y',
      };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopupMenuButton<ZoomLevel>(
      onSelected: onChanged,
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (context) => ZoomLevel.values.map((z) {
        final isSelected = z == selected;
        return PopupMenuItem<ZoomLevel>(
          value: z,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _label(z),
                  style: TextStyle(
                    color: isSelected ? p.accent : p.onSurfaceMed,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected) Icon(Icons.check, color: p.accent, size: 16),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.onSurfaceLow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(selected),
              style: TextStyle(
                color: p.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, color: p.onSurfaceMed, size: 16),
          ],
        ),
      ),
    );
  }
}
