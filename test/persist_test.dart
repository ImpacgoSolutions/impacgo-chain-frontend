import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/store.dart';

void main() {
  test('saving and loading gives back exactly the same data', () {
    // a busy store: sell flow, buy flow, a return, a transfer, a count, a new customer
    final qt = S.docs.firstWhere((d) => d.type == 'QT');
    qt.lines.first.qty = 100;
    qt.lines.first.rate = 1000;
    final so = S.doc(S.qtConvert(qt.id).open!)!;
    if (so.status == 'Pending Approval') S.soApprove(so.id);
    final pc = S.pkConfirm(S.soRelease(so.id).open!).open!;
    final dn = S.pack(pc, 3, '120 kg').open!;
    S.doc(dn)!.eway = '123456789012';
    final inv = S.dnDispatch(dn, 'Blue Dart', S.vehicles.first).open!;
    S.invPay(inv, 5000, 'NEFT', 'UTR1');
    final sr = S.invReturn(inv, qt.lines.first.item, 2, 'Damaged').open!;
    S.srApprove(sr);
    S.srReceive(sr);
    final w = S.warehouses.first.id;
    final pr = S.saveDocForm('PR', 'S001', w, null, null, [(item: 'ITM-1001', qty: 100)]);
    S.prSubmit(pr.id);
    S.prApprove(pr.id);
    final po = S.doc(S.prPo(pr.id).open!)!;
    S.supplierRaiseInvoice(po.id, 'SUP/1', '2026-09-28', {'ITM-1001': 100}, {'ITM-1001': po.lines.first.rate});
    final g = S.poReceive(po.id, [100], 'DC').open!;
    S.grnRaiseQc([g]);
    S.grnQc(g, [90]);
    final tr = S.docs.firstWhere((d) => d.type == 'TR' && d.status == 'Pending Approval');
    S.trApprove(tr.id);
    S.trDispatch(tr.id);
    S.customers.add(S.customers.first);
    S.payTerms.add(S.payTerms.first);

    final saved = S.snapshotText();
    final fresh = AppStore(); // a brand-new store with the standard data
    expect(fresh.snapshotText(), isNot(saved));
    fresh.restoreFromText(saved);
    expect(fresh.snapshotText(), saved);
    // spot checks on what the screens read
    expect(fresh.docs.length, S.docs.length);
    expect(fresh.doc(inv)!.eway, '123456789012');
    expect(fresh.doc(g)!.qcSent, isNotNull);
    expect(fresh.stk(w, 'ITM-1001').onhand, S.stk(w, 'ITM-1001').onhand);
    expect(fresh.ledger.length, S.ledger.length);
  });
}
