import 'package:flutter/material.dart';
import 'chart_viewport_controller.dart';
import 'app_colors.dart';

class ZoomToggle extends StatelessWidget {
  final ZoomLevel selected;
  final ValueChanged<ZoomLevel> onChanged;

  const ZoomToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static String _label(ZoomLevel z) => switch (z) {
        ZoomLevel.intraday => 'Intraday',
        ZoomLevel.weekly => 'Weekly',
        ZoomLevel.monthly => 'Monthly',
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ZoomLevel>(
      onSelected: onChanged,
      color: const Color(0xFF1E2530),
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
                    color: isSelected
                        ? kAccent
                        : const Color(0xCCFFFFFF),
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: Color(0xFF4FFFB0), size: 16),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161920),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(selected),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0x89FFFFFF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
