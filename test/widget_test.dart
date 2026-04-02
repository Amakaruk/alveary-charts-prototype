import 'package:flutter_test/flutter_test.dart';
import 'package:cps_chart_demo/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CpsChartApp());
    expect(find.text('Colony Performance Score'), findsOneWidget);
  });
}
