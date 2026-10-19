import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/screens/common.dart';
import 'package:impacgo_chain/ui/overlays.dart';

void main() {
  testWidgets('the packing form lists the items being packed', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ImpacgoChainApp());
    await tester.pump(const Duration(milliseconds: 400));
    final so = S.docs.firstWhere((d) => d.type == 'SO' && d.status == 'Confirmed');
    final pc = S.doc(S.pkConfirm(S.soRelease(so.id).open!).open!)!;
    final itemName = S.item(pc.lines.first.item).name;
    dlgPack(pc);
    await tester.pump(const Duration(milliseconds: 500));
    final all = tester.widgetList<Text>(find.byType(Text)).map((e) => e.data ?? '').join(' | ');
    expect(all.contains('Items being packed'), isTrue);
    expect(all.contains(itemName), isTrue, reason: 'the item $itemName must be listed');
    expect(all.contains('${pc.lines.first.qty} ${S.item(pc.lines.first.item).uom}'), isTrue);
    expect(tester.takeException(), isNull);
    print('PACKING lists: $itemName x ${pc.lines.first.qty}');
    closeAll();
  });
}
