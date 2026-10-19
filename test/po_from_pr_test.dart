import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/screens/sales_proc.dart';
import 'package:impacgo_chain/ui/overlays.dart';

void main() {
  testWidgets('New purchase order offers approved requests first', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ImpacgoChainApp());
    await tester.pump(const Duration(milliseconds: 300));

    // no approved request: straight to the blank order form
    newPurchaseOrder();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('New Purchase Order'), findsWidgets);
    expect(find.textContaining('are waiting to be ordered'), findsNothing);
    closeAll();
    await tester.pump(const Duration(milliseconds: 400));

    // an approved request waiting: the picker comes first, then the order is made from it
    final pr = S.saveDocForm('PR', 'S001', S.warehouses.first.id, null, null, [(item: 'ITM-1001', qty: 100)]);
    S.prSubmit(pr.id);
    S.prApprove(pr.id);
    newPurchaseOrder();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('approved purchase request(s) are waiting'), findsOneWidget);
    // nothing is pre-picked: Continue without a choice is refused, then the request is chosen by hand
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('approved purchase request(s) are waiting'), findsOneWidget, reason: 'still on the picker');
    // the request is chosen by hand (the form's own save is called with that choice)
    debugLastForm!.onSave({'from': pr.id}, navKey.currentContext!);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('from ${pr.id}'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
