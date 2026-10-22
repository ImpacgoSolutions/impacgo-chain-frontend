import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/screens/common.dart';
import 'package:impacgo_chain/ui/overlays.dart';

/// Picking an item types nothing into Description or HSN / SAC: the item's own text only shows faintly.
void main() {
  testWidgets('choosing an item leaves Description and HSN / SAC empty', (tester) async {
    tester.view.physicalSize = const Size(1536, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ImpacgoChainApp());
    await tester.pump(const Duration(milliseconds: 300));
    final item = S.items.first;
    openDocForm('PR');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Select item'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).last, item.id);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(item.name).last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    final typed = tester.widgetList<TextField>(find.byType(TextField)).map((t) => t.controller?.text ?? '').toList();
    expect(typed.contains(item.name), isFalse, reason: 'the description is not typed in');
    expect(typed.contains(item.hsn), isFalse, reason: 'the HSN / SAC is not typed in');
    // the item's name and HSN show as hints instead
    final hints = tester.widgetList<TextField>(find.byType(TextField)).map((t) => t.decoration?.hintText).toList();
    expect(hints, containsAll([item.name, item.hsn]));
    closeAll();
    await tester.pump(const Duration(milliseconds: 300));
  });

}
