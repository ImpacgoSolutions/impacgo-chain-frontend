import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/auth.dart';
import 'package:impacgo_chain/core/models.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/screens/common.dart';
import 'package:impacgo_chain/ui/widgets.dart';

/// Every step that needs the SCM Manager's approval waits for it, and only the manager gets the Approve / Reject buttons.
void main() {
  AppStore.singleDemo = true; // the website's demo data (set before the store is first used)
  void asManager() => S.login('admin@impacgo.com', 'Admin@123');
  void asExec() => S.login('executive@impacgo.com', 'Exec@123');
  void asStore() => S.login('store@impacgo.com', 'Store@123');
  List<String> buttons(Doc d) => actionsFor(d).whereType<Btn>().map((b) => b.label).toList();

  test('sales return: approval → inspection on receipt → credit for the good goods only', () {
    asManager();
    final inv = S.docsOf('INV').first;
    final it = inv.lines.first.item;
    final stock0 = S.stk(inv.wh, it).onhand;
    final sr = S.doc(S.invReturn(inv.id, it, 4, 'Damaged').open!)!;
    expect(sr.status, 'Pending Approval');
    // nothing moves before approval
    expect(S.srReceive(sr.id).msg, contains('waiting for approval'));
    expect(S.stk(inv.wh, it).onhand, stock0);
    asStore();
    expect(buttons(sr), isNot(contains('Approve return')), reason: 'only the manager approves');
    asManager();
    expect(buttons(sr), containsAll(['Reject', 'Approve return']));
    S.srApprove(sr.id);
    expect(sr.status, 'Approved');
    // 3 good, 1 damaged: only the good ones go back into stock and are credited
    S.srReceive(sr.id, [3]);
    expect(S.stk(inv.wh, it).onhand, stock0 + 3);
    final cn = S.doc(S.srCredit(sr.id).open!)!;
    expect(cn.type, 'CN');
    expect(cn.lines.single.qty, 3);
  });

  test('stock transfer: approval before any stock leaves', () {
    asManager();
    final w = S.warehouses.first.id, to = S.warehouses[1].id;
    final it = S.items.first.id;
    final before = S.stk(w, it).onhand;
    final tr = S.saveDocForm('TR', null, w, to, null, [(item: it, qty: 10)]);
    expect(tr.status, 'Pending Approval');
    expect(S.trDispatch(tr.id).msg, contains('waiting for approval'));
    expect(S.stk(w, it).onhand, before);
    asStore();
    expect(buttons(tr), isNot(contains('Approve transfer')));
    asManager();
    S.trApprove(tr.id);
    S.trDispatch(tr.id);
    expect(tr.status, 'In Transit');
    expect(S.stk(w, it).onhand, before - 10);
  });

  test('quotation: a discount above the limit waits for approval; a changed price needs approval again', () {
    asManager();
    final c = S.customers.first.id, it = S.items.first.id;
    final list = S.salesPrice(c, it, 100).rate;
    final qt = S.saveDocForm('QT', c, S.warehouses.first.id, null, null, [(item: it, qty: 100)], rates: [list * .8]);
    expect(S.qtDiscountPct(qt), closeTo(20, .01));
    S.qtSend(qt.id, 'buyer@example.com');
    expect(qt.status, 'Pending Approval', reason: 'not sent before approval');
    asExec();
    expect(buttons(qt), isNot(contains('Approve & send')));
    asManager();
    S.qtApprove(qt.id);
    expect(qt.status, 'Sent');
    // a small discount goes straight out
    final small = S.saveDocForm('QT', c, S.warehouses.first.id, null, null, [(item: it, qty: 100)], rates: [list * .95]);
    S.qtSend(small.id);
    expect(small.status, 'Sent');
    // sent back to re-price
    final big = S.saveDocForm('QT', c, S.warehouses.first.id, null, null, [(item: it, qty: 100)], rates: [list * .7]);
    S.qtSend(big.id);
    S.qtRejectDiscount(big.id, 'Discount too high');
    expect(big.status, 'Draft');
    expect(big.reason, 'Discount too high');
  });

  test('purchase order: without an approved request it always needs approval; from one it goes to the supplier', () {
    asManager();
    final s = S.suppliers.first.id, it = S.items.first.id, w = S.warehouses.first.id;
    final direct = S.saveDocForm('PO', s, w, null, null, [(item: it, qty: 1)]);
    expect(direct.status, 'Pending Approval');
    expect(direct.note, contains('No approved purchase request'));
    final pr = S.saveDocForm('PR', s, w, null, null, [(item: it, qty: 1)]);
    S.prSubmit(pr.id);
    S.prApprove(pr.id);
    final fromPr = S.saveDocForm('PO', s, w, null, null, [(item: it, qty: 1)], ref: pr.id);
    expect(fromPr.status, 'Sent to Supplier');
  });

  test('a warehouse executive can submit the request it raised, but not approve it', () {
    asStore();
    final pr = S.saveDocForm('PR', null, S.warehouses.first.id, null, null, [(item: S.items.first.id, qty: 5)]);
    expect(S.canAct('PR', 'Submit for approval'), isTrue);
    expect(S.canAct('PR', 'Approve request'), isFalse);
    expect(S.canAct('PR', 'Reject'), isFalse);
    expect(S.canAct('PO', 'Goods received'), isTrue);
    asExec();
    expect(S.canAct('PO', 'Goods received'), isFalse);
    expect(pr.status, 'Draft');
    asManager();
  });

  testWidgets('nothing breaks for the manager (who sees every button)', (tester) async {
    asManager();
    for (final d in S.docs.take(60)) {
      expect(() => actionsFor(d), returnsNormally, reason: d.id);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
