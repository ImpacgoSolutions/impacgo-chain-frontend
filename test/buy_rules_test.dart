import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/models.dart';
import 'package:impacgo_chain/core/store.dart';

Doc approvedPr(String item, int qty) {
  final pr = S.saveDocForm('PR', 'S001', S.warehouses.first.id, null, null, [(item: item, qty: qty)]);
  S.prSubmit(pr.id);
  S.prApprove(pr.id);
  return pr;
}

int onhand(String item) => S.stk(S.warehouses.first.id, item).onhand;

void main() {
  test('an approved request becomes one purchase order only', () {
    final pr = approvedPr('ITM-1001', 10);
    expect(S.prPo(pr.id).open, isNotNull);
    final again = S.prPo(pr.id);
    expect(again.open, isNull);
    expect(again.msg, contains('only an approved request'));
    expect(S.docsOf('PO').where((p) => p.ref == pr.id), hasLength(1));
  });

  test('all units rejected: no empty bin task, return raised, stock untouched, debit note once', () {
    final po = S.doc(S.prPo(approvedPr('ITM-1001', 40).id).open!)!;
    final g = S.poReceive(po.id, [40], 'DC').open!;
    final before = onhand('ITM-1001');
    S.grnRaiseQc([g]);
    S.grnQc(g, [0]);
    expect(S.docsOf('PA').where((p) => p.ref == g), isEmpty);
    expect(S.doc(g)!.status, 'QC Checked');
    expect(onhand('ITM-1001'), before);
    final prt = S.docsOf('PRT').firstWhere((r) => r.ref == g);
    expect(prt.lines.first.qty, 40);
    S.prtDispatch(prt.id);
    expect(onhand('ITM-1001'), before); // rejected units were never in stock
    final notes = S.docsOf('DBN').length;
    final twice = S.prtDispatch(prt.id);
    expect(twice.msg, contains('already dispatched'));
    expect(S.docsOf('DBN').length, notes);
  });

  test('a manual return of rejected units does not take stock out either', () {
    final po = S.doc(S.prPo(approvedPr('ITM-1001', 50).id).open!)!;
    final g = S.poReceive(po.id, [50], 'DC').open!;
    S.grnRaiseQc([g]);
    S.grnQc(g, [45]);
    final auto = S.docsOf('PRT').firstWhere((r) => r.ref == g);
    auto.status = 'Rejected'; // the automatic return was turned down: the 5 units can be returned by hand
    final stock = onhand('ITM-1001');
    final r = S.doc(S.prtCreate(g, {'ITM-1001': 5}, 'Damaged / leaking', '2026-09-28', S.warehouses.first.id, null).open!)!;
    S.prtApprove(r.id);
    S.prtDispatch(r.id);
    expect(onhand('ITM-1001'), stock);
  });

  test('the same supplier invoice number cannot be entered twice; a received order cannot be cancelled', () {
    final po = S.doc(S.prPo(approvedPr('ITM-1001', 20).id).open!)!;
    final q = {'ITM-1001': 20};
    final rate = {'ITM-1001': po.lines.first.rate};
    expect(S.supplierRaiseInvoice(po.id, 'DUP/1', '2026-09-28', q, rate).open, isNotNull);
    final dup = S.supplierRaiseInvoice(po.id, ' dup/1 ', '2026-09-28', q, rate);
    expect(dup.open, isNull);
    expect(dup.msg, contains('already recorded'));
    S.poReceive(po.id, [5], 'DC');
    expect(S.cancelDoc(po.id, 'x').msg, contains('cannot be cancelled'));
    expect(S.doc(po.id)!.status, isNot('Cancelled'));
  });
}
