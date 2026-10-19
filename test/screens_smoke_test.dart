import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/screens/registry.dart';
import 'package:impacgo_chain/screens/common.dart';
import 'package:impacgo_chain/screens/setup_lists.dart';
import 'package:impacgo_chain/screens/importer.dart';
import 'package:impacgo_chain/ui/overlays.dart';

void main() {
  final ids = <String>{
    'workspace','preqs','porders','grns','qc','putaway','preturns','pinvoices','leads','opps','quotes','sorders','fulfil','sinvoices','sreturns','onhand','ledger','batches','transfers','adjust','counting',
    'rep_so','rep_pending_delivery','rep_po','rep_pending_po','rep_grn','rep_stock_overview','rep_stock_movement','rep_low_stock','rep_ar_ageing','rep_ap_ageing',
    'h_company','h_warehouses','h_items','h_customers','suppliers','h_team','reports','automation','setuplists',
  };
  for (final t in hubs.values) { for (final x in t) { ids.add(x.$2); } }
  // every report view that exists in the registry (sample data used to hide errors here)
  for (final r in ['rep_dn','rep_sr','rep_sales_customer','rep_sales_item','rep_pr_ret','rep_pur_supplier','rep_pur_item','rep_stock_ledger','rep_stock_transfer','rep_stock_adj','rep_batch','rep_serial','rep_sup_pur','rep_sup_perf','rep_cust_sales','rep_cust_trans','rep_shipment','rep_dispatch']) { ids.add(r); }
  for (final id in ids) {
    testWidgets('screen $id', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: buildView(id)))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('forms and records open', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ImpacgoChainApp());
    await tester.pump(const Duration(milliseconds: 300));
    final bad = <String>[];
    Future<void> go(String n, void Function() f) async {
      try { f(); await tester.pump(const Duration(milliseconds: 350)); final e = tester.takeException(); if (e != null) bad.add('$n: ${e.toString().split('\n').first}'); } catch (e) { bad.add('$n: $e'); }
      closeAll(); await tester.pump(const Duration(milliseconds: 350)); tester.takeException();
    }
    final w = S.warehouses.first.id;
    final pr = S.saveDocForm('PR', 'S001', w, null, null, [(item: 'ITM-1001', qty: 100)]);
    S.prSubmit(pr.id); S.prApprove(pr.id);
    final po = S.doc(S.prPo(pr.id).open!)!;
    final pi = S.supplierRaiseInvoice(po.id, 'X/1', '2026-09-28', {'ITM-1001': 100}, {'ITM-1001': po.lines.first.rate}).open!;
    final g = S.poReceive(po.id, [100], 'DC').open!;
    await go('grn raised', () => openDoc(g));
    S.grnRaiseQc([g]);
    await go('grn with qc', () => openDoc(g));
    S.grnQc(g, [100]);
    await go('grn qc done', () => openDoc(g));
    await go('pi', () => openDoc(pi));
    await go('po', () => openDoc(po.id));
    for (final d in S.docs.toList()) { await go('doc ${d.id}', () => openDoc(d.id)); }
    await go('branch new', () => branchForm());
    await go('branch edit', () => branchForm(S.branches.first));
    await go('currency', () => currencyForm(S.currencies.first));
    await go('term', () => payTermForm(S.payTerms.first));
    await go('tax', () => taxCodeForm(S.taxCodes.first));
    await go('tnc', () => tcTemplateForm(S.tcTemplates.first));
    for (final k in importSpecs.keys) { await go('import $k', () => openImport(k)); }
    print('FAILED ${bad.length}: ${bad.join(' | ')}');
    expect(bad, isEmpty);
  });
}
