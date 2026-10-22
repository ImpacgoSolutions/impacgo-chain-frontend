import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/store.dart';
import '../core/models.dart';
import '../ui/overlays.dart';
import '../ui/table.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'buy_report.dart' show openPoFromPr;
import 'common.dart';

// ================================================================ SALES
Widget quotesView() => docListView('QT', 'Quotations', 'Price offers sent to customers before they commit',
    [['AUTO', 'Price from trade agreement → price list → item price'], ['MANUAL', 'Send, accept or mark lost'], ['SEMI', 'Convert to sales order in one click']],
    createLabel: 'New quotation', onCreate: () => openDocForm('QT'));

Widget salesOrdersView() => docListView('SO', 'Sales Orders', 'Customer orders from entry to closure · approvals above ${fmtINR(S.params.soApproval)}',
    [['AUTO', 'Credit check, approval routing, stock reservation'], ['SEMI', 'Release to warehouse creates the pick list'], ['AUTO', 'Status follows pick → pack → dispatch → payment']],
    createLabel: 'New sales order', onCreate: () => openDocForm('SO'));

Widget deliveriesView() => docListView('DN', 'Deliveries (Dispatch)', 'Delivery notes ready to leave the warehouse and already shipped',
    [['AUTO', 'Created when packing is confirmed'], ['MANUAL', 'Choose carrier and vehicle, then dispatch'], ['AUTO', 'Dispatch posts stock, invoice, e-way bill, shipment']]);

Widget salesInvoicesView() {
  final inv = S.docsOf('INV');
  final bal = inv.fold<double>(0, (a, d) => a + d.amount - d.paid);
  final od = inv.where((d) => d.status != 'Paid' && d.due != null && daysBetween(d.due!, todayStr()) > 0).toList();
  final coll = S.docsOf('CP').where((c) => c.date.startsWith(todayStr().substring(0, 7))).fold<double>(0, (a, c) => a + c.amount);
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    PageHeader('Sales Invoices', sub: 'GST invoices raised automatically on dispatch · e-invoice reference and e-way bill attached', actions: [Btn.secondary('Receivables ageing', icon: 'bars', onTap: () => S.go('rep_ar_ageing'))]),
    StatRow([
      Stat('Invoiced (FY 26-27)', fmtINR(inv.fold<double>(0, (a, d) => a + d.amount)), '${inv.length} invoices', 'receipt', Tone.blue),
      Stat('Outstanding', fmtINR(bal), 'Open', 'wallet', Tone.amber, up: false),
      Stat('Overdue', fmtINR(od.fold<double>(0, (a, d) => a + d.amount - d.paid)), '${od.length} invoice(s)', 'clock', Tone.red, up: false),
      Stat('Collected this month', fmtINR(coll), 'This month', 'check', Tone.green),
    ], max: 4, compact: true),
    docTable('tINV', 'INV', inv),
  ]);
}

void newReceipt() => pickDoc('New customer receipt', 'Invoice being paid', S.docsOf('INV').where((d) => d.status != 'Paid').toList(), dlgPay, 'All invoices are fully paid.',
    'Choose the invoice; the next step asks for the amount, payment mode and bank reference. Or import a bank statement to record many at once.');

Widget customerPaymentsView() => docListView('CP', 'Customer Payments', 'Receipts from customers and the invoices they settle',
    [['MANUAL', 'Record receipt from the invoice'], ['SEMI', 'Bank statement import suggests the match'], ['AUTO', 'Invoice and order close when fully paid']],
    bulk: false, createLabel: 'New receipt', onCreate: newReceipt, actions: [Btn('Import bank statement', icon: 'upload', onTap: openBankImport)]);

void openBankImport() {
  final ls = S.bankLines();
  final matched = ls.where((l) => l.inv != null).length;
  openModal(
    'Import bank statement · HDFC Current A/c ••4521',
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Statement for 28 Sep 2026 · ${ls.length} credit lines read. The system suggests a match by amount and customer name.', style: const TextStyle(fontSize: 12, color: C.faint)),
      const SizedBox(height: 10),
      for (final l in ls)
        ActivityRow('wallet', '${l.ref} · ${fmtINR(l.amount)}', l.narr,
            tone: l.inv != null ? Tone.green : Tone.amber,
            trailing: l.inv != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [StatusBadge(l.inv!, tone: Tone.green), Text(l.conf, style: tsFaint)])
                : StatusBadge(l.conf, tone: Tone.amber)),
    ]),
    size: ModalSize.wide,
    actions: (ctx) => [
      Btn.secondary('Cancel', onTap: () => Navigator.of(ctx).pop()),
      Btn('Post $matched matched receipt(s)', icon: 'check', onTap: () {
        final n = S.postBank(ls);
        after(Res('$n receipts posted · ${ls.length - n} unmatched line kept for review'));
      }),
    ],
  );
}

void newSalesReturn() => pickDoc('New sales return', 'Delivery', S.docsOf('DN').where((d) => ['Dispatched', 'Delivered'].contains(d.status)).toList(), dlgSalesReturn,
    'There are no dispatched deliveries to return against.', 'Returns are created against the delivery so the same items, price and GST are used.');

Widget salesReturnsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Sales Returns', sub: 'Goods coming back from customers and the credit notes issued for them'),
      Tabs([
        TabDef('Returns', () => docTable('tSR', 'SR', S.docsOf('SR'), createLabel: 'New return', onCreate: newSalesReturn)),
        TabDef('Credit notes', () => docTable('tCN', 'CN', S.docsOf('CN'), bulk: false)),
      ], storeKey: 'sreturns'),
    ]);

// ================================================================ PROCUREMENT
void runReorderUi() {
  final made = S.runReorder();
  S.refresh();
  toast(made.isEmpty ? 'Reorder check done — every item is above its reorder level' : '${made.length} purchase request(s) raised: ${made.map((d) => d.id).join(', ')}');
}

Widget purchaseRequestsView() => docListView('PR', 'Purchase Requests', 'Internal requests to buy — raised by users or by the daily reorder check',
    [['AUTO', 'Reorder check raises requests for items below reorder level'], ['MANUAL', 'Approve or reject'], ['SEMI', 'Convert to RFQ or PO']],
    createLabel: 'New request', onCreate: () => openDocForm('PR'));

/// [pr]: the approved purchase request the quotations are asked for (picked already).
void newRfqForm({String? pr}) {
  // opened from a request: its warehouse, item and quantity are filled in
  final src = pr == null ? null : S.doc(pr);
  final line = src?.lines.firstOrNull;
  mform('New request for quotation', [

    const F.header('RFQ'),
    F('rfq_no', 'RFQ No.', type: 'readonly', def: nextNo('RFQ')),
    F('rfq_date', 'RFQ Date', type: 'date', def: todayStr(), req: true),
    F('pr_ref', 'Purchase Request Ref.', type: 'select', req: true, def: pr ?? '', options: [
      ...S.docsOf('PR').where((d) => d.status == 'Approved').map((d) => Opt(d.id, '${d.id} · ${S.item(d.lines.first.item).name}')),
      const Opt('', 'Direct — without a request'),
    ]),
    F('close', 'Quote Due Date', type: 'date', def: addDays(todayStr(), 3), req: true),
    F('wh', 'Delivery Location', type: 'select', def: src?.wh ?? S.currentWh.id, options: S.warehouses.map((w) => Opt(w.id, '${w.code} — ${w.city}')).toList()),
    const F.header('Line Item'),
    F('item', 'Item', type: 'select', req: true, def: line?.item ?? '', options: S.items.map((p) => Opt(p.id, '${p.name} (${p.id})')).toList()),
    F('qty', 'Qty', type: 'number', def: line == null ? '50' : '${line.qty}', req: true),
    F('uom', 'UOM', type: 'select', req: true, def: line == null ? '' : S.item(line.item).uom, options: S.uoms.map((u) => Opt(u.code, u.code)).toList()),
    const F.header('Suppliers'),
    F('sups', 'Suppliers', type: 'checks', req: true, options: [
      for (var i = 0; i < S.suppliers.length; i++) Opt(S.suppliers[i].id, '${S.suppliers[i].name} · lead ${S.suppliers[i].lead} d', checked: i < 3),
    ]),
  ], (v, _) {
    final pr = v['pr_ref'] as String;
    // with a request selected, the RFQ asks for that request's item and quantity
    final src = pr.isEmpty ? null : S.doc(pr);
    final item = src?.lines.first.item ?? v['item'] as String;
    final qty = src?.lines.first.qty ?? (v['qty'] as num).toInt();
    final r = S.newRfq(item, qty, v['wh'] as String, v['close'] as String, (v['sups'] as List).cast<String>(), prRef: pr.isEmpty ? null : pr);
    after(Res('RFQ ${r.id} sent to ${r.invited.length} supplier(s)', r.id));
    return false;
  }, status: 'Draft', statusNote: 'Becomes RFQ Sent when saved and sent to the suppliers.', btn: 'Send RFQ', icon: 'msg', size: ModalSize.wide);
}

Widget rfqsView() => docListView('RFQ', 'Ask Suppliers (RFQ)', 'Ask several suppliers for prices and pick the best offer',
    [['SEMI', 'Created from an approved purchase request'], ['MANUAL', 'Enter supplier quotes'], ['AUTO', 'Best price highlighted · award creates the PO']],
    bulk: false, createLabel: 'New RFQ', onCreate: newRfqForm);

/// New purchase order. An approved purchase request that was not converted yet is offered first, so the order
/// is made from it (supplier, warehouse and items filled in and the request marked Ordered).
/// A blank order stays available for purchases that have no request.
void newPurchaseOrder() {
  final open = S.docsOf('PR').where((r) => r.status == 'Approved').toList()..sort((a, b) => b.date.compareTo(a.date));
  if (open.isEmpty) {
    openDocForm('PO');
    return;
  }
  const blank = '-';
  mform('New purchase order', [
    F('from', 'Create from', type: 'select', req: true, full: true, def: open.first.id, options: [
      for (final r in open) Opt(r.id, '${r.id} · ${S.partyName(r)} · ${fmtINR(r.amount)} · approved, not yet ordered'),
      const Opt(blank, 'No purchase request — blank purchase order'),
    ]),
  ], (v, ctx) {
    final pick = v['from'] as String;
    Navigator.of(ctx).pop();
    final pr = pick == blank ? null : S.doc(pick);
    if (pr == null) {
      openDocForm('PO');
    } else {
      openPoFromPr(pr);
    }
    return false;
  }, btn: 'Continue', icon: 'swap', intro: '${open.length} approved purchase request(s) are waiting to be ordered. Pick one to order it, or start a blank order.');
}

Widget purchaseOrdersView() => docListView('PO', 'Purchase Orders', 'Orders placed with suppliers · approval above ${fmtINR(S.params.poApproval)}',
    [['AUTO', 'Price from purchase trade agreement'], ['AUTO', 'Approval only above the limit'], ['MANUAL', 'Receive goods against the PO']],
    createLabel: 'New purchase order', onCreate: newPurchaseOrder);

void newGrn() => pickDoc('New goods receipt', 'Purchase order', S.docsOf('PO').where((d) => ['Sent to Supplier', 'Partially Received'].contains(d.status)).toList(), dlgReceive,
    'No purchase order is waiting for goods.', 'Goods are always received against a PO so quantities and prices can be matched later.');

Widget grnsView() => docListView('GRN', 'Goods Receipts (GRN)', 'Product receipts against purchase orders, held in RCV-01 until QC',
    [['MANUAL', 'Count goods at the dock'], ['MANUAL', 'Raise QC · the QC team records the result'], ['AUTO', 'Stock posted, bin allocation task created, rejects returned']],
    tableActions: [TableAction('Raise QC', 'checksq', raiseQcFor, primary: true)],
    createLabel: 'New goods receipt', onCreate: newGrn);

/// Sends the ticked goods receipts (QC Pending) to the QC team.
void raiseQcFor(List rows) {
  final ids = rows.cast<Doc>().where((d) => d.status == 'QC Pending').map((d) => d.id).toList();
  if (ids.isEmpty) {
    toast(rows.isEmpty ? 'Tick the goods receipts to send for QC' : 'Only goods receipts in QC Pending can be sent for QC');
    return;
  }
  final res = S.grnRaiseQc(ids);
  S.refresh();
  toast(res.msg);
}

void newPi() => pickDoc('Generate invoice', 'Purchase order',
    S.docsOf('PO').where((d) => const ['Sent to Supplier', 'Partially Received', 'Received', 'Closed'].contains(d.status) && !S.docsOf('PI').any((p) => p.ref == d.id && p.status != 'Rejected')).toList(),
    dlgGenerateInvoice, 'Every purchase order already has its invoice.', 'Choose the purchase order the supplier sent goods for.');

Widget supplierInvoicesView() => docListView('PI', 'Purchase Invoices', 'Invoices the suppliers have sent · checked automatically against the PO and goods receipt, then passed to Finance for payment',
    [['MANUAL', 'Supplier invoice received'], ['AUTO', 'Checked against the PO and goods receipt'], ['MANUAL', 'Manager approves differences'], ['MANUAL', 'Approved invoices go to Finance for payment']],
    createLabel: 'Generate invoice', onCreate: newPi);


void newPurchaseReturn() => pickDoc('New purchase return', 'Goods receipt', S.docsOf('GRN').where((g) => qcDone(g) && g.lines.any((l) => returnableQty(g, l, S.docsOf('PRT')) > 0)).toList(), dlgPurchaseReturn,
    'No goods receipt has rejected units waiting to be returned. Goods that passed quality check are not returned.', 'Purchase returns are made for the units rejected at quality check. Pick the goods receipt.');

Widget purchaseReturnsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Purchase Returns', sub: 'Goods sent back to suppliers and the debit notes raised'),
      Tabs([
        TabDef('Returns', () => docTable('tPRT', 'PRT', S.docsOf('PRT'), createLabel: 'New return', onCreate: newPurchaseReturn)),
        TabDef('Debit notes', () => docTable('tDBN', 'DBN', S.docsOf('DBN'), bulk: false)),
      ], storeKey: 'preturns'),
    ]);

// ================================================================ WAREHOUSE (document based)
Widget putawayView() => docListView('PA', 'Bin Allocation', 'After goods are received and QC is complete: put the accepted goods into storage bins',
    [['AUTO', 'Task and target bin created by storage rule'], ['MANUAL', 'Scan and confirm the move']]);

Widget pickingView() => docListView('PK', 'Picking', 'Pick lists grouped into pick batches · bins and batches chosen by earliest expiry',
    [['SEMI', 'Created when an order is released'], ['AUTO', 'Bin and batch suggested'], ['MANUAL', 'Picker confirms quantities']]);

Widget packingView() => docListView('PCK', 'Packing', 'Pack picked goods, record cartons and weight',
    [['AUTO', 'Created when picking is confirmed'], ['MANUAL', 'Enter cartons and weight'], ['AUTO', 'Delivery note and load created']]);

void newCountForm() {
  // the count is for the warehouse selected at the top of the screen; change it there to count another one
  final w = S.currentWh;
  final options = S.countOptions(w.id);
  mform('New stock count', [

    const F.header('Stock Count'),
    F('cc_no', 'Count No.', type: 'readonly', def: nextNo('CC')),
    F('count_date', 'Count Date', type: 'date', def: todayStr(), req: true),
    F('wh', 'Warehouse', type: 'readonly', def: '${w.code} — ${w.city}'),
    F('zone', 'Zone', type: 'select', req: true, options: opts(['A · Picking Area', 'B · Bulk storage'])),
    F('by', 'Counted By', type: 'select', req: true, options: opts(['Suresh N', 'Ravi Teja', 'Kiran Kumar'])),
    F('count_type', 'Count Type', type: 'select', show: true, options: opts(['Zone count', 'ABC cycle count', 'Spot check', 'Full count'])),
    const F.header('Items to count · item, batch and bin'),
    F('picks', 'Tick what will be counted', type: 'checks', req: true, full: true, options: [for (final o in options) Opt(o.key, o.label, checked: o.checked)],
        empty: 'No stock in this warehouse to count'),
  ], (v, _) {
    final picks = [for (final k in (v['picks'] as List)) k as String];
    final d = S.newCount(w.id, v['zone'] as String, v['by'] as String, picks: picks);
    d.source = v['count_type'] as String;
    d.date = v['count_date'] as String;
    after(Res('${d.id} created · enter the counted quantities', d.id));
    return false;
  }, status: 'Draft', statusNote: 'Becomes Counting when saved.', btn: 'Create count', icon: 'scan',
      note: 'The 3 highest-value items are ticked for you; tick or untick any line. After saving, the count opens so the counted quantities can be entered.');
}

Widget countingView() => docListView('CC', 'Physical Stock Count', 'Scheduled counts by zone · differences become adjustments',
    [['AUTO', 'Count list by ABC class'], ['MANUAL', 'Count entry (system quantity hidden)'], ['AUTO', 'Adjustments from count differences']],
    createLabel: 'New count', onCreate: newCountForm);

// ================================================================ INVENTORY (document based)
Widget transfersView() => docListView('TR', 'Stock Transfers', 'Move stock between warehouses with dispatch and receipt confirmation',
    [['MANUAL', 'Create or approve the transfer'], ['AUTO', 'Dispatch moves stock to in-transit'], ['MANUAL', 'Receive at destination']],
    createLabel: 'New transfer', onCreate: () => openDocForm('TR'));

Widget adjustView() => docListView('ADJ', 'Stock Adjustments', 'Damage, write-off and count corrections · approval above ${fmtINR(S.params.adjApproval)}',
    [['AUTO', 'Created from stock count differences'], ['AUTO', 'Small values post directly'], ['MANUAL', 'Approve high-value adjustments']],
    createLabel: 'New adjustment', onCreate: () => openDocForm('ADJ'));

// ================================================================ TRANSPORT (document based)
void newLoadForm({String? vehicleName}) {
  final ready = S.docsOf('DN').where((d) => d.status == 'Ready to Dispatch' && !S.docsOf('LD').any((l) => l.status != 'Dispatched' && l.dns.contains(d.id))).toList();
  mform('New load', [
    const F.header('Document'),
    F('planned', 'Planned Date', type: 'date', def: todayStr(), req: true),
    F('tpl', 'Trip Template', type: 'select', req: true, options: S.loadTemplates.map((t) => Opt(t.id, t.name)).toList()),
    F('veh', 'Vehicle', type: 'select', req: true, def: vehicleName ?? '', options: S.fleet.map((v) => Opt(v.name, v.name)).toList()),
    F('wh', 'Loading Warehouse', type: 'select', def: S.currentWh.id, options: S.warehouses.map((w) => Opt(w.id, '${w.code} — ${w.city}')).toList()),
    F('car', 'Carrier', type: 'select', def: 'Own fleet', options: opts(S.carriers.map((c) => c.name).toList())),
    const F('driver', 'Driver'),
    F('route', 'Route', def: '${S.currentWh.city} → ', req: true),
    const F.header('Load'),
    const F('weight', 'Weight (kg)', type: 'number'),
    const F('volume', 'Volume (m³)', type: 'number'),
    const F.header('Other'),
    const F('seal', 'Seal No.'),
    const F('remarks', 'Remarks', type: 'textarea', full: true),
    F('status', 'Status', type: 'select', req: true, options: opts(['Planned'])),
    const F.header('Shipments / Orders'),
    F('dns', 'Delivery Notes on this Load', type: 'checks', empty: 'No deliveries are waiting — you can still create an empty planned load.', options: [
      for (final d in ready) Opt(d.id, '${d.id} · ${S.partyName(d)} · ${S.wh(d.wh).code} · ${d.cartons ?? '?'} cartons', checked: d.wh == S.currentWh.id),
    ]),
  ], (v, _) {
    final dns = (v['dns'] as List).cast<String>();
    if (dns.any((x) => S.doc(x)!.wh != v['wh'])) {
      toast('Only deliveries from the loading warehouse can go on this load');
      return false;
    }
    final ld = S.newLoad(v['wh'] as String, v['veh'] as String, v['car'] as String, v['route'] as String, dns);
    after(Res('Trip ${ld.id} planned with ${dns.length} deliveries', ld.id));
    return false;
  }, btn: 'Create load', icon: 'layers', size: ModalSize.wide);
}

Widget loadsView() => docListView('LD', 'Trip Planning', 'Group deliveries into truck loads by route and vehicle capacity',
    [['AUTO', 'Deliveries added to the open load for their warehouse'], ['MANUAL', 'Start loading at the dock'], ['AUTO', 'Dispatch invoices every delivery on the load']],
    createLabel: 'New load', onCreate: newLoadForm);

Widget shipmentsView() => docListView('SHP', 'Shipments', 'Consignments with carriers and live tracking status',
    [['AUTO', 'Booked on dispatch'], ['AUTO', 'Tracking updates from carrier'], ['AUTO', 'Delivery closes the delivery note and order']]);
