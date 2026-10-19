import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/store.dart';

void main() {
  migrationTest();
  test('Clear Buy records puts stock back and keeps sell records', () {
    final w = S.warehouses.first.id;
    final before = {for (final p in S.items) p.id: S.stk(w, p.id).onhand};
    final sellDocs = S.docs.length;
    final ledgerBefore = S.ledger.map((e) => '${e.ref}:${e.bal}').toList();
    // a full buy cycle with a rejection and a return, plus a sales issue after it
    final pr = S.saveDocForm('PR', 'S001', w, null, null, [(item: 'ITM-1001', qty: 100)]);
    S.prSubmit(pr.id);
    S.prApprove(pr.id);
    final po = S.doc(S.prPo(pr.id).open!)!;
    S.supplierRaiseInvoice(po.id, 'X/1', '2026-09-28', {'ITM-1001': 100}, {'ITM-1001': po.lines.first.rate});
    final g = S.poReceive(po.id, [100], 'DC').open!;
    S.grnRaiseQc([g]);
    S.grnQc(g, [90]);
    expect(S.stk(w, 'ITM-1001').onhand, before['ITM-1001']! + 90);
    expect(S.docs.length, greaterThan(sellDocs));

    final n = S.clearBuyRecords();
    expect(n, greaterThan(4));
    expect(S.docs.length, sellDocs);
    for (final p in S.items) {
      expect(S.stk(w, p.id).onhand, before[p.id], reason: p.id);
    }
    expect(S.ledger.map((e) => '${e.ref}:${e.bal}').toList(), ledgerBefore);
    expect(S.docs.any((d) => const {'PR', 'PO', 'GRN', 'PA', 'PI', 'PRT'}.contains(d.type)), isFalse);
    // numbering starts again
    expect(S.dt['PR']!.seq, 0);
    expect(S.clearBuyRecords(), 0);
  });
}

void migrationTest() {
  test('older saved data loses its Buy test records once, then stays clean', () {
    final w = S.warehouses.first.id;
    final sell = S.docs.length;
    final pr = S.saveDocForm('PR', 'S001', w, null, null, [(item: 'ITM-1001', qty: 100)]);
    S.prSubmit(pr.id);
    S.prApprove(pr.id);
    S.prPo(pr.id);
    expect(S.docs.length, greaterThan(sell));
    // what an older version saved: the same data without the "cleaned" mark
    final old = (jsonDecode(S.snapshotText()) as Map)..remove('buyCleaned');
    final fresh = AppStore();
    fresh.restoreFromText(jsonEncode(old));
    expect(fresh.docs.length, sell);
    expect(fresh.docs.any((d) => d.type == 'PR' || d.type == 'PO'), isFalse);
    // data saved by this version keeps its Buy records
    final keep = AppStore();
    keep.restoreFromText(S.snapshotText());
    expect(keep.docs.any((d) => d.type == 'PO'), isTrue);
    S.clearBuyRecords(); // leave the shared store as it was
  });
}
