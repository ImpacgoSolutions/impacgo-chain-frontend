import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/main.dart';

void main() {
  testWidgets('App boots on the SCM Workspace', (tester) async {
    await tester.pumpWidget(const ImpacgoChainApp());
    expect(find.text('SCM Workspace'), findsWidgets);
  });

  test('Order to Cash flow runs end to end', () {
    final qt = S.docs.firstWhere((d) => d.type == 'QT');
    final so = S.doc(S.qtConvert(qt.id).open!)!;
    if (so.status == 'Pending Approval') S.soApprove(so.id);
    final pk = S.soRelease(so.id).open!;
    final pc = S.pkConfirm(pk).open!;
    final dn = S.pack(pc, 3, '120 kg').open!;
    final inv = S.dnDispatch(dn, 'Blue Dart', S.vehicles.first).open!;
    S.invPay(inv, S.doc(inv)!.amount, 'NEFT', 'UTR TEST');
    expect(S.doc(inv)!.status, 'Paid');
  });

  test('Procure to Pay flow runs end to end', () {
    final w = S.warehouses.first.id;
    final pr = S.saveDocForm('PR', 'S001', w, null, null, [(item: 'ITM-1001', qty: 100)]);
    S.prSubmit(pr.id);
    S.prApprove(pr.id);
    final po = S.doc(S.prPo(pr.id).open!)!;
    final qtys = po.lines.map((l) => l.qty).toList();
    final g = S.poReceive(po.id, qtys, 'DC-1').open!;
    S.grnRaiseQc([g]);
    S.grnQc(g, qtys);
    // the QC report is ready the moment the result is posted
    expect(S.doc(g)!.qcSent, isNotNull);
    // the supplier's invoice is checked automatically, nobody presses Verify
    final pi = S.supplierRaiseInvoice(po.id, 'SUP/1', '2026-09-28', {for (final l in po.lines) l.item: l.qty}, {for (final l in po.lines) l.item: l.rate}).open!;
    expect(S.doc(pi)!.status, 'Approved');
    S.piPay(pi);
    expect(S.doc(pi)!.status, 'Paid');
  });
}
