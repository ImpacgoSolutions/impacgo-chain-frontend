import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/models.dart';
import 'package:impacgo_chain/core/store.dart';

String grn(int qty, int accepted) {
  final w = S.warehouses.first.id;
  final pr = S.saveDocForm('PR', 'S001', w, null, null, [(item: 'ITM-1001', qty: qty)]);
  S.prSubmit(pr.id);
  S.prApprove(pr.id);
  final po = S.doc(S.prPo(pr.id).open!)!;
  final g = S.poReceive(po.id, [qty], 'DC').open!;
  S.grnRaiseQc([g]);
  S.grnQc(g, [accepted]);
  return g;
}

void main() {
  test('all passed: the QC report says so, and there is nothing to return', () {
    final g = S.doc(grn(100, 100))!;
    expect(qcRejectionText(g), 'Nil — all passed in quality check');
    expect(S.docsOf('PRT').where((r) => r.ref == g.id), isEmpty);
    expect(g.lines.any((l) => returnableQty(g, l, S.docsOf('PRT')) > 0), isFalse);
  });

  test('rejected units: the reason is shown, and they are covered by the automatic return', () {
    final g = S.doc(grn(100, 90))!;
    g.qcNote = 'Cartons crushed';
    expect(qcRejectionText(g), 'Cartons crushed');
    g.qcNote = '';
    expect(qcRejectionText(g), '10 unit(s) rejected during quality inspection');
    // QC already raised the return for the 10 rejected units
    final prt = S.docsOf('PRT').firstWhere((r) => r.ref == g.id);
    expect(prt.lines.first.qty, 10);
    expect(returnableQty(g, g.lines.first, S.docsOf('PRT')), 0);
    // if that return is rejected, the 10 units can be returned again; passed units never can
    prt.status = 'Rejected';
    expect(returnableQty(g, g.lines.first, S.docsOf('PRT')), 10);
  });
}
