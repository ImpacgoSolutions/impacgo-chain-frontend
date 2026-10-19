import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/store.dart';

void main() {
  test('the demo lead LEAD-0103 goes through the whole sell flow', () {
    final lead = S.leads.firstWhere((l) => l.id == 'LEAD-0103');
    expect(lead.company, 'Vizag Safety Mart');
    expect(lead.status, 'New');
    expect(lead.phone, isNotEmpty);
    expect(lead.email, contains('@'));
    final log = <String>['LEAD-0103 · ${lead.status}'];

    // opportunity: the customer is created from the lead
    final custs = S.customers.length;
    final made = S.qualifyLead(lead, item: 'ITM-1001', qty: 100, value: 150000);
    final opp = S.opps.firstWhere((o) => o.id == made.open);
    expect(lead.status, 'Qualified');
    expect(S.customers.length, custs + 1);
    final cust = S.customers.last;
    expect(cust.name, 'Vizag Safety Mart');
    expect(cust.phone, '+91 98765 43210');
    log.add('${opp.id} · ${opp.stage} · customer ${cust.id}');

    // quotation → sent → accepted → sales order
    final qt = S.doc(S.oppQuote(opp).open!)!;
    expect(qt.status, 'Draft');
    S.qtSend(qt.id, lead.email);
    expect(S.doc(qt.id)!.status, 'Sent');
    S.qtAccept(qt.id);
    expect(S.doc(qt.id)!.status, 'Accepted');
    log.add('${qt.id} · ${S.doc(qt.id)!.status}');
    final so = S.doc(S.qtConvert(qt.id).open!)!;
    if (so.status == 'Pending Approval') S.soApprove(so.id);
    log.add('${so.id} · ${S.doc(so.id)!.status}');
    expect(opp.stage, 'Won');

    // pick → pack → dispatch → invoice
    final stock0 = S.stk(so.wh, 'ITM-1001').onhand;
    final pk = S.soRelease(so.id).open!;
    final pc = S.pkConfirm(pk).open!;
    final dn = S.pack(pc, 2, '60 kg').open!;
    S.doc(dn)!.eway = '123456789012';
    final inv = S.dnDispatch(dn, 'Blue Dart', S.vehicles.first).open!;
    expect(S.stk(so.wh, 'ITM-1001').onhand, stock0 - 100);
    log.add('${pk} → ${pc} → ${dn} → ${inv} (stock ${stock0} → ${S.stk(so.wh, 'ITM-1001').onhand})');

    // delivery, payment, return
    S.dnDeliver(dn);
    S.invPay(inv, S.doc(inv)!.amount, 'NEFT', 'UTR-DEMO');
    expect(S.doc(inv)!.status, 'Paid');
    final sr = S.invReturn(inv, 'ITM-1001', 5, 'Damaged').open!;
    S.srReceive(sr);
    expect(S.stk(so.wh, 'ITM-1001').onhand, stock0 - 95);
    log.add('${inv} Paid · return ${sr} received (stock ${S.stk(so.wh, 'ITM-1001').onhand})');
    for (final l in log) { print('FLOW $l'); }
  });
}
