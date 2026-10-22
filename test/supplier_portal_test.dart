import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/auth.dart';
import 'package:impacgo_chain/core/format.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/screens/supplier_portal.dart';

/// The supplier's side, end to end on the website's demo data: quote for an RFQ, reject the order it becomes
/// (the request opens up again), quote and win again, accept the new order, send the invoice.
void main() {
  AppStore.singleDemo = true; // the website's demo data (set before the store is first used)

  test('a supplier login sees only its three portal screens', () {
    expect(S.login('supplier@andhracorrugators.com', 'Supplier@123'), isTrue);
    expect(S.isSupplier, isTrue);
    expect(S.view, 'sp_po');
    for (final v in ['sp_rfq', 'sp_po', 'sp_inv']) {
      expect(S.canView(v), isTrue, reason: v);
    }
    for (final v in ['workspace', 'preqs', 'porders', 'rfqs', 'pinvoices', 'sorders', 'onhand', 'h_company']) {
      expect(S.canView(v), isFalse, reason: v);
    }
    expect(portalSupplier(), S.user!.party);
  });

  test('quote → order rejected (request opens up again) → quote again → accept → invoice', () {
    S.login('supplier@andhracorrugators.com', 'Supplier@123');
    final s = portalSupplier();
    // the demo RFQ waits for this supplier's price
    final rfq = supplierToQuote().single;
    expect(rfq.status, 'Awaiting Quotes');
    final pr = S.doc(rfq.ref!)!;
    expect(pr.status, 'RFQ Sent');

    S.supplierQuote(rfq.id, s, 41.5, 4, addDays(todayStr(), 14), 'Freight included');
    expect(rfq.status, 'Quotes Received');
    expect(supplierToQuote(), isEmpty);

    // the buyer awards it: the order arrives in the portal as a new order
    S.login('admin@impacgo.com', 'Admin@123');
    final po1 = S.doc(S.rfqAward(rfq.id).open!)!;
    S.login('supplier@andhracorrugators.com', 'Supplier@123');
    expect(po1.party, s);
    expect(supplierNewOrders().map((d) => d.id), contains(po1.id));

    // rejected with a reason: the order is cancelled and the RFQ / request are open again
    S.supplierRejectPo(po1.id, 'Price has changed');
    expect(po1.status, 'Cancelled');
    expect(po1.note, contains('Price has changed'));
    expect(rfq.status, 'Awaiting Quotes');
    expect(pr.status, 'RFQ Sent');
    expect(supplierToQuote().map((d) => d.id), contains(rfq.id));

    // quote again, win again, accept with a delivery date
    S.supplierQuote(rfq.id, s, 43, 5, addDays(todayStr(), 14), '');
    final po2 = S.doc(S.rfqAward(rfq.id).open!)!;
    expect(pr.status, 'Ordered');
    final when = addDays(todayStr(), 6);
    S.supplierAcceptPo(po2.id, when, '');
    expect(po2.extra['ack_date'], when);
    expect(supplierNewOrders(), isEmpty);
    expect(S.supplierRejectPo(po2.id, 'x').msg, contains('already accepted'));

    // accepted orders can be invoiced
    expect(supplierToInvoice().map((d) => d.id), contains(po2.id));
    S.supplierRaiseInvoice(po2.id, 'AND/INV/9001', todayStr(), {for (final l in po2.lines) l.item: l.qty}, {for (final l in po2.lines) l.item: l.rate});
    expect(supplierToInvoice().map((d) => d.id), isNot(contains(po2.id)));
    expect(S.docsOf('PI').any((p) => p.ref == po2.id && p.supInv == 'AND/INV/9001'), isTrue);
  });

  test('a supplier can decline a request for quotation', () {
    S.login('admin@impacgo.com', 'Admin@123');
    final r = S.newRfq(S.items.first.id, 10, S.warehouses.first.id, addDays(todayStr(), 3), [S.suppliers.first.id]);
    S.login('supplier@andhracorrugators.com', 'Supplier@123');
    expect(supplierToQuote().map((d) => d.id), contains(r.id));
    S.supplierDeclineRfq(r.id, portalSupplier(), 'Item not available');
    expect(supplierToQuote().map((d) => d.id), isNot(contains(r.id)));
  });

  for (final (name, size) in [('laptop', const Size(1536, 900)), ('phone', const Size(390, 844))]) {
    testWidgets('the three portal screens open cleanly on a $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      S.login('supplier@andhracorrugators.com', 'Supplier@123');
      await tester.pumpWidget(const ImpacgoChainApp());
      await tester.pump(const Duration(milliseconds: 300));
      for (final v in ['sp_rfq', 'sp_po', 'sp_inv']) {
        S.go(v);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: v);
      }
      expect(find.text('Orders to invoice'), findsOneWidget);
      S.login(demoUsers.first.email, demoUsers.first.password);
    });
  }
}
