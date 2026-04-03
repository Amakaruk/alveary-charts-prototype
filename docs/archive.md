# Archive

## ✓ Timeline List Formatting — completed 2026-04-03

Implemented in `inspection_table.dart`:
- `ListView.separated` replaced with a flat `Column` built from a mixed list of `_MonthHeader` and `_InspectionRow` widgets
- Month headers ("June 2024") inserted whenever the month changes between entries; no divider adjacent to headers
- Row date columns show day number only (`log.date.day.toString()`); wide-row date column narrowed from 52→32px
- `_MonthHeader`: subtle, 11pt semi-bold, `onSurfaceLow` colour, `letterSpacing: 0.5`, top padding 20px

---

## ✓ Platform-Adaptive Detail Sheets — completed 2026-04-03

Implemented in `inspection_table.dart`:
- `_showDetail(context, log)` — checks width ≥600 for side sheet, else bottom sheet
- `_LogDetailContent` — shared header + notes body used by both sheet variants
- `_LogDetailBottomSheet` — rounded-top container, drag handle, 65% height, `showModalBottomSheet`
- `_LogDetailSideSheet` — full-height, left-rounded container, slides in from right via `showGeneralDialog` + `SlideTransition`
- Row tap calls `onTap()` (chart scroll) AND `_showDetail()` (sheet)

---

## ✓ Key Metrics Cards (Viewport-Relative) — completed 2026-04-03

Implemented in `metric_cards.dart` (`MetricCards` widget), wired into `chart_demo_screen.dart` between chart and table:
- AVG, PEAK, LOW computed from `controller.visibleSpots` (excluding ghost left-edge point)
- TREND = last − first visible score; shown with `+`/`−` sign; dimmed color when negative
- Responsive: 4 cards (≥600px), 3 cards without TREND (<600px)
- Outlined box style matching palette; updates live on pan and zoom change

---

## ✓ X-Axis Time Label Display Rules — completed 2026-04-03

Implemented in `cps_line_chart.dart` (`_xLabel`):
- **1D**: readings within 15 min of even-hour marks; label shows rounded `HH:00`
- **1W**: one label per day; `EEE\nd` format (e.g. "Mon\n3")
- **1M**: round-day anchors 1/8/15/22/29; `MMM\nd` format
- **3M**: 1st and 15th of each month; `MMM\nd`; Jan 1 shows year
- **6M**: 1st of each month; `MMM`; Jan shows year
- **1Y**: 1st of each month; `MMM`; Jan shows year
