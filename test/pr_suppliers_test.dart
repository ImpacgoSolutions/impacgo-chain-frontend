import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/models.dart';
import 'package:impacgo_chain/core/store.dart';

void main() {
  test('a request with items from two suppliers becomes one purchase order per supplier', () {
    if (!S.suppliers.any((s) => s.id == 'S900')) {
      S.suppliers.add(Supplier('S900', 'Sri Balaji Papers', 'Vijayawada', 'Andhra Pradesh', '37AAACS1234B1Z5', 30, 5, 0, 0, 0, 'R. Babu', 'Approved'));
    }
    final w = S.warehouses.first.id;
    // nothing chosen at the top: the suppliers are on the lines
    final pr = S.saveDocForm('PR', null, w, null, null, [(item: 'ITM-1001', qty: 100), (item: 'ITM-1001', qty: 40)]);
    expect(pr.party, isNull);
    pr.lines[0].sup = 'S001';
    pr.lines[1].sup = 'S900';
    expect(S.partyName(pr), '${S.sup('S001').name}, Sri Balaji Papers');
    expect(S.prBySupplier(pr).keys, ['S001', 'S900']);

    S.prSubmit(pr.id);
    S.prApprove(pr.id);
    final res = S.prPo(pr.id);
    final pos = S.docsOf('PO').where((p) => p.ref == pr.id).toList();
    expect(pos.length, 2, reason: res.msg);
    expect(pos.map((p) => p.party).toSet(), {'S001', 'S900'});
    expect(pos.firstWhere((p) => p.party == 'S900').lines.single.qty, 40);
    expect(S.doc(pr.id)!.status, 'Ordered');
    expect(S.prSuppliersToOrder(S.doc(pr.id)!), isEmpty);
  });

  test('ordering one supplier at a time keeps the request open until all are ordered', () {
    final w = S.warehouses.first.id;
    final pr = S.saveDocForm('PR', null, w, null, null, [(item: 'ITM-1001', qty: 10), (item: 'ITM-1001', qty: 20)]);
    pr.lines[0].sup = 'S001';
    pr.lines[1].sup = 'S900';
    S.prSubmit(pr.id);
    S.prApprove(pr.id);

    // first supplier's order, made on the form
    final po1 = S.createPO('S001', w, [Line('ITM-1001', 10, 50)], null);
    S.prOrdered(pr.id, po1.id, forSup: 'S001');
    expect(S.doc(pr.id)!.status, 'Approved');
    expect(S.prSuppliersToOrder(S.doc(pr.id)!), ['S900']);

    final po2 = S.createPO('S900', w, [Line('ITM-1001', 20, 50)], null);
    S.prOrdered(pr.id, po2.id, forSup: 'S900');
    expect(S.doc(pr.id)!.status, 'Ordered');
  });
}
