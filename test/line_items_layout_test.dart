import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/screens/common.dart';
import 'package:impacgo_chain/ui/overlays.dart';

/// Line items never slide sideways: a table that fits on a laptop, one card per line on a phone.
void main() {
  for (final (name, size, cards) in [('laptop', const Size(1536, 800), false), ('phone', const Size(390, 844), true)]) {
    for (final t in ['PR', 'PO', 'QT', 'SO', 'TR', 'ADJ']) {
      testWidgets('$t line items on a $name: every field shown, nothing scrolls sideways', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const ImpacgoChainApp());
        await tester.pump(const Duration(milliseconds: 300));
        openDocForm(t);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: 'no overflow on the $t form');
        expect(find.text('Qty'), findsWidgets);
        expect(find.text('Line 1'), cards ? findsOneWidget : findsNothing);
        // no sideways scrolling area left around the line items
        final form = find.byType(DocForm);
        final sideways = tester.widgetList<SingleChildScrollView>(find.descendant(of: form, matching: find.byType(SingleChildScrollView))).where((s) => s.scrollDirection == Axis.horizontal);
        expect(sideways, isEmpty);
        closeAll();
        await tester.pump(const Duration(milliseconds: 300));
      });
    }
  }
}
