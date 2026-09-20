import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/theme/app_theme.dart';

void main() {
  test('secondary copy meets WCAG AA contrast on white', () {
    expect(
      _contrastRatio(AppTheme.mutedInk, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('common buttons retain 48dp targets with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Column(
              children: [
                TextButton(onPressed: () {}, child: const Text('Retry')),
                OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
                IconButton(
                  tooltip: 'Search customers',
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(IconButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final light = background.computeLuminance();
  final dark = foreground.computeLuminance();
  return (light + 0.05) / (dark + 0.05);
}
