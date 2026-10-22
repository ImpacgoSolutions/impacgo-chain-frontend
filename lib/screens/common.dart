// Shared document machinery: list tables, the document drawer with its
// action buttons, action dialogs, the new-document form and party/item drawers.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import '../ui/select.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/auth.dart';
import '../ui/overlays.dart';
import '../ui/table.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'logistics.dart' show drivers;
import 'edit_forms.dart';
import 'remove.dart';
import 'attachments.dart';
import 'addresses.dart';
import 'buy_report.dart';
import 'grn_form.dart';
import '../core/export_builders.dart' show buildInvoicePdf, buildReceiptPdf, buildOrderPdf, buildPurchaseRequestPdf, buildPurchaseOrderPdf, buildGrnPdf, buildQcPdf, buildPurchaseInvoicePdf, buildPurchaseReturnPdf;
import '../core/export_helper.dart' show exportDocPdf;

// ================================================================ helpers
void after(Res r) {
  closeAll();
  S.refresh();
  toast(r.msg);
  // reopen in the same frame so the list never flashes in between
  if (r.open != null) openDoc(r.open!);
}

void openDocNav(String id) {
  final d = S.doc(id);
  if (d == null) {
    toast('$id is an archived document');
    return;
  }
  closeAll();
  S.go(S.dt[d.type]!.view);
  openDoc(id);
}

Widget chipWh(String id) => Tag(S.wh(id).code);

Widget invBadge(Doc d) {
  if (d.status != 'Paid' && d.due != null && daysBetween(d.due!, todayStr()) > 0) {
    return Wrap(spacing: 4, runSpacing: 4, children: [StatusBadge(d.status), StatusBadge('Overdue ${daysBetween(d.due!, todayStr())}d', tone: Tone.red)]);
  }
  return StatusBadge(d.status);
}

Widget partyCell(Doc d) {
  final p = S.dt[d.type]!.party;
  if (p == 'W') {
    return d.to != null ? Row(mainAxisSize: MainAxisSize.min, children: [chipWh(d.wh), const Text('  →  '), chipWh(d.to!)]) : chipWh(d.wh);
  }
  // a purchase request may have no supplier yet
  if (d.party == null) return const Text('Supplier not chosen', style: TextStyle(fontSize: 12.5, color: C.faint));
  return CellAv(S.partyName(d), S.partyCity(d));
}

String titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ================================================================ document list
const _short = {
  'QT': 'Quote No.', 'SO': 'Order No.', 'PK': 'Pick List', 'PCK': 'Packing Slip', 'DN': 'Delivery No.', 'INV': 'Invoice No.', 'CP': 'Receipt No.',
  'SR': 'Return No.', 'CN': 'Credit Note', 'PR': 'Request No.', 'RFQ': 'RFQ No.', 'PO': 'PO No.', 'GRN': 'GRN No.', 'PA': 'Task No.', 'PI': 'Invoice No.',
  'SP': 'Payment No.', 'PRT': 'Return No.', 'DBN': 'Debit Note', 'TR': 'Transfer No.', 'ADJ': 'Adjustment', 'CC': 'Count No.', 'SHP': 'Shipment', 'LD': 'Trip No.'
};

/// The item(s) on a document: the first item's name, and how many more there are.
String itemsOf(Doc d) {
  final names = [for (final l in d.lines) S.items.where((p) => p.id == l.item).firstOrNull?.name ?? l.desc ?? l.item];
  if (names.isEmpty) return '—';
  return names.length == 1 ? names.first : '${names.first} +${names.length - 1} more';
}

Col _itemCol() => Col.t('Item', (r) => itemsOf(r as Doc));

/// Who asked for a purchase request (requests from the reorder check name it as their source).
String _requester(Doc d) {
  final r = (d.requester ?? '').trim();
  if (r.isNotEmpty) return r;
  final src = (d.source ?? '').split('— ').last.trim();
  return src.isEmpty ? '—' : src;
}

List<Col> docCols(String t) {
  final party = S.dt[t]!.party;
  final c = <Col>[
    Col(_short[t]!, (r) => Text((r as Doc).id, style: tsB), sort: (r) => (r as Doc).id, text: (r) => (r as Doc).id),
    Col.t('Date', (r) => (r as Doc).date),
  ];
  if (party != 'W') {
    c.add(Col(party == 'C' ? 'Customer' : 'Supplier', (r) => partyCell(r as Doc), sort: (r) => S.partyName(r as Doc), text: (r) => S.partyName(r as Doc)));
    if (!['INV', 'PI', 'PRT', 'SHP', 'SR', 'DBN', 'CN'].contains(t)) c.add(Col('Warehouse', (r) => chipWh((r as Doc).wh), text: (r) => S.wh((r as Doc).wh).code));
  } else {
    c.add(Col(t == 'TR' ? 'From → To' : 'Warehouse', (r) => partyCell(r as Doc), text: (r) => S.wh((r as Doc).wh).code));
  }
  switch (t) {
    case 'PK':
      c.addAll([Col.t('Pick Batch', (r) => (r as Doc).wave ?? ''), Col.t('Picker', (r) => (r as Doc).picker ?? '')]);
      break;
    case 'SHP':
      c.addAll([Col.t('Carrier', (r) => (r as Doc).carrier ?? ''), Col.t('Tracking', (r) => (r as Doc).awb ?? ''), Col.t('ETA', (r) => (r as Doc).eta ?? '')]);
      break;
    case 'LD':
      c.addAll([
        Col.t('Vehicle', (r) => ((r as Doc).vehicle ?? '').split(' (').first),
        Col.t('Route', (r) => (r as Doc).route ?? ''),
        Col('Capacity Used', (r) => BarPct(((r as Doc).util ?? 0).toDouble()), sort: (r) => (r as Doc).util ?? 0),
      ]);
      break;
    case 'PI':
      c.addAll([
        Col.t('Supplier Ref', (r) => (r as Doc).supInv ?? ''),
        Col('Verification', (r) => (r as Doc).match == null
            ? const StatusBadge('Not verified', tone: Tone.gray)
            : r.match!.ok
                ? const StatusBadge('Verified', tone: Tone.green)
                : StatusBadge(r.status == 'Awaiting Goods Receipt' ? 'Awaiting goods' : 'Difference', tone: Tone.red)),
      ]);
      break;
    case 'CC':
      c.addAll([_itemCol(), Col.t('Zone', (r) => (r as Doc).zone ?? ''), Col.t('Counter', (r) => (r as Doc).counter ?? '')]);
      break;
    case 'PR':
      // who asked for the goods, and for which department
      c.add(Col('Requested By', (r) => CellTwo(_requester(r as Doc), [roleOfName(_requester(r)), r.dept ?? ''].where((s) => s.isNotEmpty).join(' · ')), sort: (r) => _requester(r as Doc), text: (r) => '${_requester(r as Doc)} · ${r.dept ?? ''}'));
      break;
    case 'SO':
      c.add(Col.t('Customer PO', (r) => ((r as Doc).custPo ?? '').trim().isEmpty ? '—' : r.custPo!));
      break;
    case 'TR':
    case 'PA':
      c.add(_itemCol());
      break;
    case 'ADJ':
      c.addAll([_itemCol(), Col.t('Reason', (r) => (r as Doc).reason ?? '')]);
      break;
    case 'SR':
    case 'PRT':
      c.add(Col.t('Reason', (r) => (r as Doc).reason ?? ''));
      break;
    case 'CP':
    case 'SP':
      c.addAll([Col.t('Mode', (r) => (r as Doc).mode ?? ''), Col.t('Reference', (r) => (r as Doc).utr ?? '')]);
      break;
    case 'GRN':
      c.add(Col.t('Received by', (r) => ((r as Doc).by ?? 'Warehouse').split(' (').first));
      break;
    case 'INV':
      c.addAll([Col.t('Customer PO', (r) => ((r as Doc).custPo ?? '').trim().isEmpty ? '—' : r.custPo!), Col.t('Due', (r) => (r as Doc).due ?? '')]);
      break;
  }
  if (!['CP', 'SP', 'CC', 'LD', 'INV', 'PI'].contains(t)) {
    c.add(Col(t == 'ADJ' ? 'Qty +/−' : 'Units', (r) => Text(fmtNum(S.calc(r as Doc).qty)), num: true, sort: (r) => S.calc(r as Doc).qty, text: (r) => '${S.calc(r as Doc).qty}'));
  }
  if (!['PK', 'PCK', 'PA', 'CC', 'TR', 'SHP', 'LD'].contains(t)) {
    double amt(Doc d) => t == 'ADJ' ? S.calc(d).sub : d.amount;
    c.add(Col(t == 'ADJ' ? 'Value' : 'Amount', (r) => Text(fmtINR(amt(r as Doc)), style: tsB), num: true, sort: (r) => amt(r as Doc), text: (r) => amt(r as Doc).toStringAsFixed(2)));
  }
  // payment is recorded on sales invoices; supplier payment belongs to Finance
  if (t == 'INV') {
    c.add(Col('Balance', (r) => Text(fmtINR((r as Doc).amount - r.paid)), num: true, sort: (r) => (r as Doc).amount - r.paid, text: (r) => ((r as Doc).amount - r.paid).toStringAsFixed(2)));
  }
  if (['PO', 'PK', 'PCK', 'DN', 'INV', 'GRN', 'PA', 'PI', 'SHP', 'CP', 'SP', 'SR', 'PRT', 'CN', 'DBN', 'RFQ'].contains(t)) {
    c.add(Col('Source', (r) => (r as Doc).ref != null ? Tag(r.ref!) : const Text('—', style: TextStyle(color: C.faint)), text: (r) => (r as Doc).ref ?? ''));
  }
  c.add(Col('Status', (r) => t == 'INV' ? invBadge(r as Doc) : StatusBadge((r as Doc).status), sort: (r) => (r as Doc).status, text: (r) => (r as Doc).status, status: true));
  return c;
}

List<Doc> sortedDocs(List<Doc> rows) => rows..sort((a, b) => a.date == b.date ? b.id.compareTo(a.id) : b.date.compareTo(a.date));

Widget docTable(String id, String type, List<Doc> rows, {String? createLabel, VoidCallback? onCreate, bool bulk = true, bool filters = true, List<TableAction> actions = const []}) {
  final sts = <String>[];
  for (final r in rows) {
    if (!sts.contains(r.status)) sts.add(r.status);
  }
  return DataTableCard(
    id: id,
    rows: sortedDocs(rows),
    cols: docCols(type),
    bulk: bulk,
    exportName: id,
    createLabel: createLabel,
    onCreate: onCreate,
    actions: actions,
    onRow: (r) => openDoc((r as Doc).id),
    // a purchase invoice can be downloaded straight from its row once the supplier has sent it
    rowActions: type == 'PI' ? (r) => supplierInvoiceSent(r as Doc) ? IconBtn('download', () => downloadSupplierInvoice(r), size: 30, tip: 'Download purchase invoice') : const SizedBox.shrink() : null,
    search: (r) {
      final d = r as Doc;
      return '${d.id} ${d.ref ?? ''} ${S.partyName(d)} ${d.status} ${d.custPo ?? ''}';
    },
    filters: filters
        ? [
            Filt('Status', sts, (r) => (r as Doc).status),
            Filt('Warehouse', S.warehouses.map((w) => w.code).toList(), (r) => S.wh((r as Doc).wh).code),
          ]
        : const [],
  );
}

Widget docListView(String type, String title, String sub, List<List<String>> notes, {String? createLabel, VoidCallback? onCreate, List<Widget> actions = const [], bool bulk = true, List<TableAction> tableActions = const []}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    PageHeader(title, sub: sub, actions: actions),
    docTable('t$type', type, S.docsOf(type), createLabel: createLabel, onCreate: onCreate, bulk: bulk, actions: tableActions),
  ]);
}

// ================================================================ document drawer
void openDoc(String id) {
  final d = S.doc(id);
  if (d == null) return;
  if (d.type == 'PR' && d.status == 'Draft') {
    // not submitted yet: show the request as its form, ready to change, attach and submit
    openFormPage('${docTitle(d.type)} · ${d.id} · Draft', DocForm(d.type, party: d.party, editId: d.id), headerActions: [AttachPin(d.id)], subtitle: d.type == 'PR' ? _prSubtitle : null);
    return;
  }
  if (const ['PI', 'INV'].contains(d.type)) {
    openBuyReport(d);
    return;
  }
  // the delivery steps open as their own forms: pick list, packing task, delivery note, shipment
  if (d.type == 'CC') {
    dlgCount(d, record: true);
    return;
  }
  if (d.type == 'PK') {
    dlgPick(d, record: true);
    return;
  }
  if (d.type == 'PCK') {
    dlgPack(d, record: true);
    return;
  }
  if (d.type == 'DN') {
    dlgDispatch(d, record: true);
    return;
  }
  if (d.type == 'SHP' && d.ref != null && S.doc(d.ref!) != null) {
    dlgTrack(S.doc(d.ref!)!, record: true);
    return;
  }
  // buying / returns documents open as the form they were created with: filled in, read-only once processed
  if (d.type == 'GRN') {
    openGrnRecord(d);
    return;
  }
  if (d.type == 'PA') {
    dlgBinAllocation(d, record: true);
    return;
  }
  if (d.type == 'SR') {
    recordSalesReturn(d);
    return;
  }
  if (d.type == 'PRT') {
    recordPurchaseReturn(d);
    return;
  }
  if (const ['QT', 'SO', 'PR', 'PO', 'TR', 'ADJ'].contains(d.type)) {
    // a created document always opens as the same form it was created with: changeable (Save changes) while
    // it can still be edited, otherwise shown as it is, not changeable. The bar below has only the next step,
    // and the download icon sits at the top.
    openFormPage(
      '${docTitle(d.type)} · ${d.id}',
      DocForm(d.type, party: d.party, editId: d.id, readOnly: !canEditDoc(d)),
      subtitle: canEditDoc(d) ? 'Change any field and press Save changes · the next step is the button at the bottom' : 'This document is no longer changeable · the next step is the button at the bottom',
      headerActions: [
        AttachPin(d.id),
        if (const ['QT', 'SO', 'PR', 'PO'].contains(d.type)) ...[const SizedBox(width: 6), IconBtn('download', () => downloadOrder(d), tip: 'Download PDF')],
      ],
      actions: (_) => actionsFor(d, nextOnly: true),
    );
    return;
  }
  if (d.type != 'INV' && d.type != 'PI') {
    openFormPage(
      '${docTitle(d.type)} · ${d.id}',
      DocRecordForm(d),
      subtitle: canEditDoc(d) ? 'Press Edit to change it · the next step is the button at the bottom' : 'This document is no longer changeable · the next step is the button at the bottom',
      headerActions: [
        AttachPin(d.id),
        if (canEditDoc(d)) ...[const SizedBox(width: 6), Btn.secondary('Edit', icon: 'edit', small: true, onTap: () => editDoc(d))],
      ],
      actions: (_) => actionsFor(d, nextOnly: true),
    );
    return;
  }
  final sub = '${titleCase(S.dt[d.type]!.label)} · ${S.dt[d.type]!.party == 'W' ? S.wh(d.wh).code : S.partyName(d)}';
  openPanel(
    header: (_) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: panelHead(d.id, sub, status: d.type == 'INV' ? invBadge(d) : StatusBadge(d.status))),
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            AttachPin(d.id),
            if (canEditDoc(d)) Btn.secondary('Edit', icon: 'edit', small: true, onTap: () => editDoc(d)),
            if (d.type == 'PR' && d.status == 'Draft') Btn('Submit', icon: 'check', small: true, onTap: () => after(S.prSubmit(d.id))),
          ]),
        ]),
    body: (_) => DocTabs(d),
    footer: (_) => actionsFor(d),
  );
}

class DocTabs extends StatefulWidget {
  final Doc d;
  const DocTabs(this.d, {super.key});
  @override
  State<DocTabs> createState() => _DocTabsState();
}

class _DocTabsState extends State<DocTabs> {
  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return RecordBody([
      TabDef('Details', () => docDetails(d, asRecord: sellRecordTypes.contains(d.type))),
      TabDef('Attachments', () => AttachmentsTab(d.id)),
      TabDef('History', () => Column(children: [
            for (final a in d.log.reversed)
              ActivityRow(a.icon, a.what, '${a.who} · ${a.when}',
                  tone: a.icon == 'plus'
                      ? Tone.blue
                      : a.icon == 'alert'
                          ? Tone.red
                          : a.icon == 'edit'
                              ? Tone.amber
                              : a.icon == 'eye'
                                  ? Tone.purple
                                  : Tone.green),
          ])),
    ]);
  }
}

Widget linesTable(Doc d) {
  final t = d.type;
  final showAmt = !['PK', 'PCK', 'PA', 'CC', 'TR', 'SHP', 'LD'].contains(t);
  final head = <String>['Item', if (t == 'PK') ...['Bin', 'Batch'], if (t == 'PA') ...['From', 'To bin'], if (t == 'CC') ...['Bin', 'System', 'Counted'], if (t != 'CC') 'Qty', if (t == 'PO') 'Received', if (showAmt) ...['Rate', 'Amount']];
  final numeric = {'Qty', 'Received', 'Rate', 'Amount', 'System', 'Counted'};
  TableRow row(List<Widget> cells, {bool header = false}) => TableRow(
        decoration: BoxDecoration(color: header ? C.navy900 : null, border: header ? null : const Border(top: BorderSide(color: C.border))),
        children: [
          for (var i = 0; i < cells.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Align(alignment: numeric.contains(head[i]) ? Alignment.centerRight : Alignment.centerLeft, child: cells[i]),
            ),
        ],
      );
  final rows = <TableRow>[
    row([for (final h in head) Text(h.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: .3))], header: true),
    for (final l in d.lines)
      row([
        CellTwo(l.desc ?? S.item(l.item).name, '${l.item} · HSN / SAC ${S.item(l.item).hsn} · GST ${S.item(l.item).gst}%'),
        if (t == 'PK') ...[Tag(l.bin.isEmpty ? '—' : l.bin), Text(l.batch.isEmpty ? '—' : l.batch, style: const TextStyle(fontSize: 12))],
        if (t == 'PA') ...[Tag(l.from), Tag(l.bin)],
        if (t == 'CC') ...[Tag(l.bin), Text('${l.sys ?? S.stk(d.wh, l.item).onhand}'), Text(l.cnt == null ? '—' : '${l.cnt}', style: tsB)],
        if (t != 'CC') Text('${fmtNum(l.qty)} ${S.item(l.item).uom}', style: const TextStyle(fontSize: 12.5)),
        if (t == 'PO') Text('${l.recv}'),
        if (showAmt) ...[Text(fmtINR(l.rate), style: const TextStyle(fontSize: 12.5)), Text(fmtINR(l.qty * l.rate), style: tsB)],
      ]),
  ];
  final widths = <int, TableColumnWidth>{0: const FlexColumnWidth(3)};
  for (var i = 1; i < head.length; i++) {
    widths[i] = const IntrinsicColumnWidth();
  }
  final table = Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(R.r), border: Border.all(color: C.border)),
    child: Table(columnWidths: widths, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: rows),
  );
  if (!showAmt || t == 'ADJ') return table;
  final c = S.calc(d);
  Widget tot(String l, String v, {bool grand = false}) => Padding(
        padding: EdgeInsets.only(top: grand ? 8 : 3),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(fontSize: grand ? 17 : 13, fontWeight: grand ? FontWeight.w800 : FontWeight.w400, color: grand ? C.text : C.soft))),
          Text(v, style: TextStyle(fontSize: grand ? 17 : 13, fontWeight: grand ? FontWeight.w800 : FontWeight.w700)),
        ]),
      );
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    table,
    Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(children: [
            tot('Subtotal', fmtINR(c.sub)),
            if (c.inter) tot('IGST', fmtINR(c.tax)) else ...[tot('CGST', fmtINR(c.tax / 2)), tot('SGST', fmtINR(c.tax / 2))],
            const Divider(height: 14),
            tot('Total', fmtINR(c.total), grand: true),
          ]),
        ),
      ),
    ),
  ]);
}

/// Buying and selling documents shown as a plain form-style record, like a lead.
/// Only invoices (sales and supplier), receipts, credit notes and reports keep the document layout.
const sellRecordTypes = ['QT', 'SO', 'PK', 'PCK', 'DN', 'SR', 'PR', 'PO', 'GRN', 'PRT', 'RFQ', 'PA'];

Widget docDetails(Doc d, {bool asRecord = false}) {
  final t = d.type;
  final c = S.calc(d);
  final w = S.wh(d.wh);
  final kv = <Kv>[];
  final party = S.dt[t]!.party;
  if (party == 'C' && d.party != null) {
    final cu = S.cust(d.party!);
    kv.addAll([Kv.t('Customer', cu.name), Kv.t('GSTIN · State', '${cu.gstin} · ${cu.state}')]);
    final ad = S.addressDoc(d);
    if (ad != null) kv.addAll([Kv.t('Bill to', ad.billTo ?? ad.shipTo!), Kv.t('Ship to', ad.shipTo!)]);
  }
  if (party == 'S' && d.party != null) {
    final su = S.sup(d.party!);
    kv.addAll([Kv.t('Supplier', su.name), Kv.t('GSTIN · State', '${su.gstin} · ${su.state}')]);
  }
  kv.addAll([Kv.t('Date', d.date), Kv.t(t == 'TR' ? 'From warehouse' : 'Warehouse', '${w.code} — ${w.name}')]);
  void add(String l, String? v) {
    if (v != null && v.isNotEmpty) kv.add(Kv.t(l, v));
  }

  if (d.to != null) add('To warehouse', '${S.wh(d.to!).code} — ${S.wh(d.to!).name}');
  add('Requested delivery', d.delivery);
  add('Valid until', d.valid);
  add('Needed by', d.need);
  add('Source', d.source);
  add('Due date', d.due);
  if (t == 'INV' || t == 'PI') {
    add('Amount paid', fmtINR(d.paid));
    add('Balance', fmtINR(d.amount - d.paid));
  }
  add('e-Invoice Reference No.', d.irn);
  add('E-way bill', d.eway);
  add('Supplier invoice no.', d.supInv);
  if (t == 'PR') add('Business justification', d.purpose);
  add('Supplier challan', d.challan);
  if (d.wave != null) add('Pick Batch · Picker', '${d.wave} · ${d.picker}');
  if (d.cartons != null) add('Cartons · Weight', '${d.cartons} · ${d.weight}');
  add('Carrier', d.carrier);
  add('Vehicle', d.vehicle);
  add('Tracking no.', d.awb);
  add('ETA', d.eta);
  add('Proof of delivery', d.pod);
  add('Route', d.route);
  if (d.util != null) add('Capacity used', '${d.util}%');
  add('Reason', d.reason);
  if (d.zone != null) add('Zone · Counter', '${d.zone} · ${d.counter}');
  if (d.mode != null) add('Mode · Reference', '${d.mode} · ${d.utr}');
  if (t != 'CP' && t != 'SP') add('Tax type', c.inter ? 'IGST (inter-state)' : 'CGST + SGST (intra-state)');

  final ids = <String>[];
  if (d.ref != null) ids.add(d.ref!);
  for (final x in [...d.refs, ...d.dns]) {
    if (!ids.contains(x)) ids.add(x);
  }
  for (final x in S.docs) {
    if (x.ref == d.id && !ids.contains(x.id)) ids.add(x.id);
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (d.status == 'On Hold') NoteBox(Tone.red, 'lock', 'Credit hold.', d.hold ?? ''),
    // goods receipt: where the goods were stored once the bins are allocated
    if (t == 'GRN' && S.binsOf(d).isNotEmpty)
      NoteBox(Tone.green, 'package', 'Stored in bins:', S.binsOf(d).entries.map((e) => '${e.key} → ${e.value}').join(' · ')),
    if (t == 'GRN' && d.qcSent != null)
      NoteBox(Tone.green, 'check', 'QC report ready (${d.qcSent}).', '${d.qcResult ?? 'QC done'}${(d.qcBy ?? '').isNotEmpty ? ' · inspected by ${d.qcBy}' : ''} · use Download QC report below.'),
    if (d.status == 'Pending Approval' && d.note != null) NoteBox(Tone.amber, 'alert', 'Approval needed.', d.note!),
    if (t == 'PI' && d.match != null) NoteBox(d.match!.ok ? Tone.green : Tone.red, d.match!.ok ? 'check' : 'alert', 'Invoice verification:', d.match!.msg),
    if (t == 'INV' && d.status != 'Paid' && d.due != null && daysBetween(d.due!, todayStr()) > 0)
      NoteBox(Tone.red, 'clock', 'Overdue by ${daysBetween(d.due!, todayStr())} days.', 'New orders for this customer go on credit hold automatically.'),
    if (asRecord) ...[
      // a record is shown as a form: status bar, the document fields, then the line items table
      FormStatusBar(d.status, 'Current status of ${d.id}. It changes automatically as the document moves forward.'),
      const SectionTitle('Document', first: true),
      _RecordFields([Kv.t('${docTitle(t)} No.', d.id), ...kv]),
      if (d.lines.isNotEmpty) ...[
        const SectionTitle('Line Items'),
        linesTable(d),
        // the items table already ends with Subtotal, GST and Total
      ] else ...[
        const SectionTitle('Amount'),
        _RecordFields([Kv.t('Amount', fmtINR(d.amount)), Kv.t('Allocated Against', d.ref ?? '—')]),
      ],
    ] else
      KvGrid(kv),
    if (t == 'RFQ' && d.quotes.isNotEmpty) ...[
      const SectionTitle('Supplier quotes'),
      for (final q in ([...d.quotes]..sort((a, b) => a.rate.compareTo(b.rate))).asMap().entries)
        ActivityRow('store', S.sup(q.value.sup).name, '${fmtINR(q.value.rate)} · lead ${q.value.lead} days · valid ${q.value.valid}',
            tone: q.key == 0 ? Tone.green : Tone.gray, trailing: q.key == 0 ? const StatusBadge('Best price', tone: Tone.green) : null),
    ],
    if (asRecord)
      const SizedBox.shrink()
    else if (d.lines.isNotEmpty) ...[const SectionTitle('Line Items'), linesTable(d)] else ...[
      const SectionTitle('Amount'),
      Text(fmtINR(d.amount), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      Text('Allocated against ${d.ref ?? '—'}', style: const TextStyle(fontSize: 12, color: C.faint)),
    ],
    if (ids.isNotEmpty) ...[
      const SectionTitle('Linked documents'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final x in ids) Tag('$x${S.doc(x) != null ? ' · ${S.doc(x)!.status}' : ''}', icon: 'file', onTap: () => openDocNav(x)),
      ]),
    ],
  ]);
}

/// Read-only form fields (label above a filled box), two per row, like the create forms.
class _RecordFields extends StatelessWidget {
  final List<Kv> items;
  const _RecordFields(this.items);
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
        final half = c.maxWidth >= 480 ? (c.maxWidth - 14) / 2 : c.maxWidth;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          for (final k in items)
            SizedBox(
              width: k.full ? c.maxWidth : half,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(k.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
                InputDecorator(decoration: const InputDecoration(), child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13, color: C.text), child: k.value)),
              ]),
            ),
        ]);
      });
}

/// Any other document (RFQ, credit / debit note, payment, load …) as a read-only form page.
class DocRecordForm extends StatelessWidget {
  final Doc d;
  const DocRecordForm(this.d, {super.key});
  @override
  Widget build(BuildContext context) => docDetails(d, asRecord: true);
}

// ================================================================ actions footer
List<Widget> actionsFor(Doc d, {bool nextOnly = false}) {
  final id = d.id, s = d.status;
  final a = <Widget>[];
  void pri(String l, String i, VoidCallback f) => a.add(Btn(l, icon: i, onTap: f));
  void sec(String l, String i, VoidCallback f) => a.add(Btn.secondary(l, icon: i, onTap: f));
  void dan(String l, String i, VoidCallback f) => a.add(Btn.danger(l, icon: i, onTap: f));
  void run(Res Function() f) => after(f());
  // closing a quotation as lost or rejecting an order always records why
  void withReason(String title, String btn, List<String> reasons) => mform('$title · $id', [
        F('why', 'Reason', type: 'select', req: true, custom: true, options: opts(reasons.where((r) => r != 'Other').toList())),
        const F('details', 'Details', type: 'textarea', full: true, show: true),
      ], (v, _) {
        final dt = (v['details'] as String).trim();
        after(S.reject(id, dt.isEmpty ? v['why'] as String : '${v['why']} · $dt'));
        return false;
      }, btn: btn, icon: 'x', status: s, statusNote: 'The reason is saved and shown on the document.');
  if (!nextOnly && const ['QT', 'SO', 'PO'].contains(d.type)) sec('Download PDF', 'download', () => downloadOrder(d));
  // nothing has been created from it yet: a draft can be deleted, an open document cancelled
  final hasChildren = S.docs.any((x) => x.ref == d.id);
  // Delete (a draft, nothing created from it) and Cancel (an open document) stay on the record page next to the next step
  if (!hasChildren && ScmActions.deletable.contains(d.status) && d.type != 'LD') {
    dan('Delete', 'trash', () => confirmDelete(d.id, () {
          S.deleteDocs([d]);
          closeAll();
          S.refresh();
          toast('${d.id} deleted');
        }));
  } else if (!hasChildren && (ScmActions.cancellable[d.type]?.contains(d.status) ?? false)) {
    dan('Cancel', 'x', () => mform('Cancel ${docTitle(d.type)} · ${d.id}', [
          const F('reason', 'Cancellation Reason', type: 'textarea', req: true, full: true, hint: 'e.g. Customer withdrew the order'),
        ], (v, _) {
          after(S.cancelDoc(d.id, v['reason'] as String));
          return false;
        }, btn: 'Confirm cancellation', icon: 'x', status: d.status, statusNote: 'Becomes Cancelled. Reserved stock is released; the record and its history are kept.'));
  }
  switch (d.type) {
    case 'QT':
      if (s == 'Draft') {
        // small card: the customer's email is filled in, change it if needed, then confirm to send the PDF
        pri('Send to customer', 'upload', () => mdialog('Send quotation · $id', [
              F('email', 'Customer Email', type: 'email', req: true, full: true, def: S.emailOfCust(d.party!), hint: 'The quotation is sent to this address as a PDF'),
            ], (v, _) {
              after(S.qtSend(id, v['email'] as String));
              return false;
            }, btn: 'Confirm & send', icon: 'upload'));
      }
      if (s == 'Sent') {
        dan('Customer rejected', 'x', () => withReason('Quotation rejected', 'Mark rejected', ['Price too high', 'Bought from a competitor', 'No budget', 'Requirement cancelled', 'No response', 'Other']));
        pri('Customer accepted', 'check', () => run(() => S.qtAccept(id)));
      }
      // the sales order form opens filled in from the quotation: change anything, then create
      if (s == 'Accepted') pri('Convert to sales order', 'swap', () => openFormPage('New Sales Order · from $id', DocForm('SO', party: d.party, fromId: id)));
      break;
    case 'SO':
      if (s == 'Pending Approval') {
        dan('Reject', 'x', () => withReason('Reject order', 'Reject order', ['Price not approved', 'Credit risk', 'Stock not available', 'Duplicate order', 'Other']));
        pri('Approve order', 'check', () => run(() => S.soApprove(id)));
      }
      if (s == 'On Hold') {
        sec('Customer ledger', 'users', () {
          closeAll();
          S.go('customers');
          openCustomerPanel(d.party!);
        });
        pri('Release credit hold', 'unlock', () => run(() => S.soReleaseHold(id)));
      }
      if (s == 'Confirmed') pri('Release to warehouse', 'checksq', () => run(() => S.soRelease(id)));
      break;
    case 'PK':
      if (s == 'To Pick') pri('Confirm picked', 'check', () => dlgPick(d));
      break;
    case 'PCK':
      if (s == 'Packing') pri('Confirm packed', 'package', () => dlgPack(d));
      break;
    case 'DN':
      if (s == 'Ready to Dispatch') pri('Dispatch', 'truck', () => dlgDispatch(d));
      if (s == 'Dispatched' || s == 'Delivered') {
        final inv = invoiceFor(d);
        if (inv != null) {
          sec('Download invoice', 'download', () => downloadInvoice(inv));
          if (inv.status != 'Paid') sec('Record payment', 'wallet', () => dlgPay(inv));
        }
      }
      if (s == 'Dispatched') pri('Update delivery status', 'check', () => dlgTrack(d));
      break;
    case 'INV':
      sec('Download invoice', 'download', () => downloadInvoice(d));
      if (s != 'Paid') pri('Record payment', 'wallet', () => dlgPay(d));
      sec('Create return', 'refund', () => dlgSalesReturn(d));
      break;
    case 'CP':
      sec('Download receipt', 'download', () => downloadReceipt(d));
      break;
    case 'SR':
      if (s == 'Requested') pri('Receive returned goods', 'inbox', () => run(() => S.srReceive(id)));
      if (s == 'Received') pri('Issue credit note', 'file', () => run(() => S.srCredit(id)));
      break;
    case 'PR':
      if (s == 'Draft') {
        pri('Submit for approval', 'check', () => run(() => S.prSubmit(id)));
      }
      if (s == 'Pending Approval') {
        dan('Reject', 'x', () => dlgRejectPr(d));
        pri('Approve request', 'check', () => run(() => S.prApprove(id)));
      }
      if (s == 'Approved') {
        pri('Convert to purchase order', 'swap', () => openPoFromPr(d));
        sec('Download PDF', 'download', () => downloadOrder(d));
      }
      if (s == 'Rejected' || s == 'Ordered') {
        sec('Download PDF', 'download', () => downloadOrder(d));
      }
      break;
    case 'RFQ':
      if (s == 'Awaiting Quotes' || s == 'Quotes Received') sec('Enter supplier quotation', 'edit', () => newSupplierQuoteForm(rfq: id));
      if (s == 'Quotes Received') pri('Award best quote', 'star', () => run(() => S.rfqAward(id)));
      break;
    case 'PO':
      if (s == 'Pending Approval' || s == 'Draft') {
        dan('Reject', 'x', () => withReason('Reject purchase order', 'Reject order', ['Price too high', 'Budget not available', 'Wrong supplier', 'Not needed any more', 'Other']));
        pri('Approve & send', 'check', () => run(() => S.poApprove(id)));
      }
      if (s == 'Sent to Supplier' || s == 'Partially Received') pri('Goods received', 'inbox', () => dlgReceive(d));
      if (const ['Sent to Supplier', 'Partially Received', 'Received', 'Closed'].contains(s)) {
        final inv = S.docsOf('PI').where((p) => p.ref == id && p.status != 'Rejected').firstOrNull;
        if (inv != null && supplierInvoiceSent(inv)) {
          sec('Download supplier invoice', 'download', () => downloadSupplierInvoice(inv));
          sec('View supplier invoice', 'file', () => openDocNav(inv.id));
        }
      }
      // goods received: each goods receipt can be downloaded from the order
      for (final g in S.docsOf('GRN').where((g) => g.ref == id)) {
        sec('Download goods receipt · ${g.id}', 'download', () => downloadGrn(g));
      }
      break;
    case 'GRN':
      if (s == 'QC Pending') pri('Raise QC', 'checksq', () => run(() => S.grnRaiseQc([id])));
      // returns are made in Buy › Purchase Returns and bins in Buy › Bin Allocation, not from here
      // once the QC team has posted the result, the QC report is the only thing left to show: it can be downloaded
      if (qcDone(d) && d.qcSent != null) pri('Download QC report', 'download', () => downloadQc(d));
      break;
    case 'PA':
      if (s == 'To Do') pri('Allocate bins', 'check', () => dlgBinAllocation(d));
      break;
    case 'PI':
      if (supplierInvoiceSent(d)) sec('Download purchase invoice', 'download', () => downloadSupplierInvoice(d));
      // the system checks the invoice by itself: no Verify / Reject buttons, only the manager's approval of a difference
      if (s == 'Pending Approval') pri('Approve difference', 'check', () => run(() => S.piApprove(id)));
      break;
    case 'PRT':
      if (s == 'Submitted') {
        dan('Reject', 'x', () => run(() => S.reject(id)));
        pri('Approve return', 'check', () => run(() => S.prtApprove(id)));
      }
      if (s == 'Approved' || s == 'Requested') pri('Dispatch items', 'truck', () => run(() => S.prtDispatch(id)));
      break;
    case 'TR':
      if (s == 'Requested') pri('Dispatch transfer', 'truck', () => run(() => S.trDispatch(id)));
      // a small card: confirm the quantity that really arrived for each item (a shortage is recorded)
      if (s == 'In Transit') {
        pri('Receive at destination', 'inbox', () => mdialog('Receive transfer · $id', [
              for (var i = 0; i < d.lines.length; i++)
                F('r$i', '${S.item(d.lines[i].item).name} · sent ${d.lines[i].qty}', type: 'number', req: true, full: true, def: '${d.lines[i].qty}', hint: 'Quantity that arrived'),
            ], (v, _) {
              final got = [for (var i = 0; i < d.lines.length; i++) (v['r$i'] as num).toInt()];
              for (var i = 0; i < got.length; i++) {
                if (got[i] < 0 || got[i] > d.lines[i].qty) {
                  toast('${S.item(d.lines[i].item).name}: received quantity must be between 0 and ${d.lines[i].qty}');
                  return false;
                }
              }
              after(S.trReceive(id, got));
              return false;
            }, btn: 'Confirm received', icon: 'inbox', note: 'If less arrived than was sent, enter what you received. The difference is recorded as a short receipt.'));
      }
      break;
    case 'ADJ':
      if (s == 'Pending Approval') {
        dan('Reject', 'x', () => run(() => S.reject(id)));
        pri('Approve & post', 'check', () => run(() => S.adjApprove(id)));
      }
      break;
    case 'CC':
      if (s == 'Counting') pri('Enter counts', 'edit', () => dlgCount(d));
      break;
    case 'SHP':
      if (s != 'Delivered' && d.ref != null && S.doc(d.ref!) != null) pri('Update delivery status', 'map', () => dlgTrack(S.doc(d.ref!)!));
      break;
    case 'LD':
      if (s == 'Planned') pri('Start loading', 'layers', () => run(() => S.ldLoad(id)));
      if (s == 'Loading') pri('Dispatch load', 'truck', () => run(() => S.ldDispatch(id)));
      break;
  }
  return a;
}

// ================================================================ invoice / receipt downloads
/// The sales invoice raised when this delivery was dispatched.
Doc? invoiceFor(Doc dn) => S.docsOf('INV').where((i) => i.ref == dn.ref || i.ref == dn.id).firstOrNull;

Future<void> downloadInvoice(Doc inv) async {
  toast('Preparing invoice ${inv.id}…');
  try {
    final f = await exportDocPdf('Invoice_${inv.id.replaceAll('/', '-')}.pdf', await buildInvoicePdf(inv));
    toast('Downloaded $f (also opened in a new tab)');
  } catch (e) {
    toast('Invoice download failed: $e');
  }
}

/// Purchase order › Generate invoice: the purchase invoice for the goods the supplier sent
/// (quantities and rates from the PO, editable). It opens straight away, ready to verify and download.
void dlgGenerateInvoice(Doc po) {
  final s = S.sup(po.party!);
  final prefix = s.name.split(' ').first.toUpperCase();
  final no = '${prefix.substring(0, prefix.length < 3 ? prefix.length : 3)}/INV/${4100 + S.docsOf('PI').length}';
  mform('Generate invoice · ${po.id}', [
    const F.header('Invoice'),
    F.calc('po', 'Purchase Order', def: po.id),
    F.calc('sup', 'Supplier', def: s.name),
    F('no', 'Supplier Invoice No.', req: true, def: no),
    F('date', 'Invoice Date', type: 'date', req: true, def: todayStr()),
    const F.header('Line Items'),
    for (final l in po.lines) ...[
      F('q_${l.item}', '${l.desc ?? S.item(l.item).name} · HSN / SAC ${S.item(l.item).hsn} · Qty (ordered ${l.qty}${l.recv > 0 ? ', received ${l.recv}' : ''})', type: 'number', def: '${l.recv > 0 ? l.recv : l.qty}'),
      F('r_${l.item}', '${l.desc ?? S.item(l.item).name} · Rate (PO ${fmtINR(l.rate)})', type: 'number', def: l.rate.toStringAsFixed(2)),
    ],
  ], (v, _) {
    final qtys = <String, int>{};
    final rates = <String, double>{};
    for (final l in po.lines) {
      final q = (v['q_${l.item}'] as num?)?.toInt() ?? 0;
      if (q > l.qty) {
        toast('${l.desc ?? S.item(l.item).name}: cannot invoice more than the ${l.qty} ordered');
        return false;
      }
      qtys[l.item] = q;
      rates[l.item] = (v['r_${l.item}'] as num?)?.toDouble() ?? l.rate;
    }
    if (qtys.values.every((q) => q == 0)) {
      toast('Enter a quantity for at least one line');
      return false;
    }
    if (S.supplierInvoiceExists(po.party, v['no'] as String)) {
      toast('Supplier invoice ${(v['no'] as String).trim()} is already recorded for ${s.name}');
      return false;
    }
    after(S.supplierRaiseInvoice(po.id, (v['no'] as String).trim(), v['date'] as String, qtys, rates));
    return false;
  }, btn: 'Generate invoice', icon: 'file', status: 'Draft', statusNote: 'Checked automatically against the PO and goods receipt: Approved when it matches, Pending Approval when there is a difference.');
}

Future<void> downloadPrt(Doc d) async {
  toast('Preparing purchase return ${d.id}…');
  try {
    final f = await exportDocPdf('Purchase_Return_${d.id}.pdf', await buildPurchaseReturnPdf(d));
    toast('Downloaded $f (also opened in a new tab)');
  } catch (e) {
    toast('Download failed: $e');
  }
}

Future<void> downloadGrn(Doc g) async {
  toast('Preparing goods receipt ${g.id}…');
  try {
    final f = await exportDocPdf('Goods_Receipt_${g.id}.pdf', await buildGrnPdf(g));
    toast('Downloaded $f (also opened in a new tab)');
  } catch (e) {
    toast('Download failed: $e');
  }
}

Future<void> downloadQc(Doc g) async {
  toast('Preparing QC report for ${g.id}…');
  try {
    final f = await exportDocPdf('QC_Report_${g.id}.pdf', await buildQcPdf(g));
    toast('Downloaded $f (also opened in a new tab)');
  } catch (e) {
    toast('Download failed: $e');
  }
}

Future<void> downloadSupplierInvoice(Doc pi) async {
  toast('Preparing supplier invoice ${pi.supInv ?? pi.id}…');
  try {
    final f = await exportDocPdf('Purchase_Invoice_${pi.id}.pdf', await buildPurchaseInvoicePdf(pi));
    toast('Downloaded $f (also opened in a new tab)');
  } catch (e) {
    toast('Supplier invoice download failed: $e');
  }
}

Future<void> downloadOrder(Doc d) async {
  toast('Preparing ${docTitle(d.type)} ${d.id}…');
  try {
    final f = await exportDocPdf('${docTitle(d.type).replaceAll(' ', '_')}_${d.id}.pdf', await (d.type == 'PR' ? buildPurchaseRequestPdf(d) : d.type == 'PO' ? buildPurchaseOrderPdf(d) : buildOrderPdf(d)));
    toast('Downloaded $f (also opened in a new tab)');
  } catch (e) {
    toast('Download failed: $e');
  }
}

Future<void> downloadReceipt(Doc cp) async {
  toast('Preparing receipt ${cp.id}…');
  try {
    final f = await exportDocPdf('Receipt_${cp.id}.pdf', await buildReceiptPdf(cp));
    toast('Downloaded $f (also opened in a new tab)');
  } catch (e) {
    toast('Receipt download failed: $e');
  }
}

// ================================================================ action dialogs
/// [record] opens the pick list as its own form page: changeable until it is confirmed, then shown as it was filled in.
void dlgPick(Doc pk, {bool record = false}) {
  mform(record ? 'Pick list · ${pk.id}' : 'Confirm picking · ${pk.id}', [
    const F.header('Picking'),
    F('pk_no', 'Pick No.', type: 'readonly', def: pk.id),
    F('so', 'SO Ref.', type: 'readonly', def: pk.ref ?? '—'),
    F('wh', 'Warehouse', type: 'readonly', def: '${S.wh(pk.wh).code} — ${S.wh(pk.wh).city}'),
    F('picker', 'Picker', type: 'select', req: true, def: pk.picker ?? '', options: opts(['Ravi Teja', 'Suresh N', 'Kiran Kumar'])),
    const F.header('Line Items · quantity picked'),
    for (var i = 0; i < pk.lines.length; i++) ...[
      F('it$i', pk.lines.length > 1 ? 'Item ${i + 1}' : 'Item', type: 'readonly', def: S.item(pk.lines[i].item).name),
      F('oq$i', 'Ordered Qty', type: 'readonly', def: '${pk.lines[i].qty}'),
      F('bin$i', 'Bin / Location', type: 'readonly', def: pk.lines[i].bin.isEmpty ? 'A-01' : pk.lines[i].bin),
      F('q$i', 'Picked Qty', type: 'number', def: '${pk.lines[i].qty}', req: true),
      if (S.item(pk.lines[i].item).track != 'None')
        F('b$i', S.item(pk.lines[i].item).track == 'Batch' ? 'Batch No. (earliest expiry first)' : 'Serial Nos.', def: pk.lines[i].batch, req: true, full: S.item(pk.lines[i].item).track == 'Serial'),
    ],
  ], (v, _) {
    for (var i = 0; i < pk.lines.length; i++) {
      final q = (v['q$i'] as num).toInt();
      if (q > pk.lines[i].qty) {
        toast('${S.item(pk.lines[i].item).name}: Picked Qty cannot be more than the ordered quantity (${pk.lines[i].qty})');
        return false;
      }
      if (q <= 0) {
        toast('${S.item(pk.lines[i].item).name}: enter the picked quantity');
        return false;
      }
    }
    // the batch / serial numbers typed must really exist here, be sellable, and cover the picked quantity
    for (var i = 0; i < pk.lines.length; i++) {
      if (!v.containsKey('b$i')) continue;
      final problem = S.pickProblem(pk.wh, pk.lines[i].item, (v['q$i'] as num).toInt(), v['b$i'] as String);
      if (problem != null) {
        toast(problem);
        return false;
      }
    }
    for (var i = 0; i < pk.lines.length; i++) {
      pk.lines[i].qty = (v['q$i'] as num).toInt();
      if (v.containsKey('b$i')) pk.lines[i].batch = (v['b$i'] as String).trim();
    }
    pk.picker = v['picker'] as String;
    after(S.pkConfirm(pk.id));
    return false;
  }, status: pk.status, statusNote: 'Becomes Picked on confirm and the packing task is created.', btn: 'Confirm picked', icon: 'check', note: record ? null : 'Batches with the earliest expiry are suggested first. On confirm the packing task is created.',
      readOnly: record && pk.status != 'To Pick', cancel: !record, headerActions: record ? [AttachPin(pk.id)] : const []);
}

/// [record] opens the shipment as its own form page: changeable until it is delivered, then shown as it was filled in.
/// The person who signed for a delivery, from the proof-of-delivery note ("Received by K. Rao on 2026-09-28" -> "K. Rao").
String podName(String? pod) {
  final p = (pod ?? '').trim();
  final m = RegExp(r'^(?:Received|Signed) by (.+?)(?: on .*)?$').firstMatch(p);
  return m == null ? p : m.group(1)!.trim();
}

void dlgTrack(Doc dn, {bool record = false}) {
  final shp = S.docsOf('SHP').where((s) => s.ref == dn.id).firstOrNull;
  final delivered = shp?.status == 'Delivered';
  final back = shp?.id ?? dn.id; // after saving, the shipment page opens again
  mform(record ? 'Shipment · ${shp?.id ?? dn.id}' : 'Update delivery status · ${dn.id}', [
    const F.header('Delivery Tracking'),
    if (shp != null) F('shp_no', 'Shipment No.', type: 'readonly', def: shp.id),
    F('dn_no', 'Delivery No.', type: 'readonly', def: dn.id),
    F('cust', 'Customer', type: 'readonly', def: S.partyName(dn)),
    if (shp != null && (shp.carrier ?? '').isNotEmpty) F('carrier', 'Carrier / Vehicle', type: 'readonly', def: '${shp.carrier}'),
    if (shp != null && (shp.awb ?? '').isNotEmpty) F('awb', 'Tracking No.', type: 'readonly', def: '${shp.awb}'),
    F('status', 'Status', type: 'select', req: true, def: delivered ? 'Delivered' : shp?.status == 'Out for Delivery' ? 'Out for Delivery' : 'In Transit', options: opts(['In Transit', 'Out for Delivery', 'Delivered'])),
    F('dd', 'Delivered Date', type: 'date', def: todayStr(), when: 'status', whenIs: 'Delivered'),
    F('rcv_by', 'Received By', def: delivered ? podName(shp?.pod) : '', when: 'status', whenIs: 'Delivered', hint: 'Name of the person who signed'),
  ], (v, _) {
    if (v['status'] == 'Delivered') {
      S.markDelivered(dn.id, 'Received by ${v['rcv_by']} on ${v['dd']}');
      after(Res('${dn.id} delivered · received by ${v['rcv_by']}', back));
    } else {
      if (shp != null) S.setStatus(shp, v['status'] as String, Users.wh);
      after(Res('${dn.id} · ${v['status']}', back));
    }
    return false;
  }, btn: 'Save status', icon: 'check', readOnly: record && delivered, cancel: !record, headerActions: record ? [AttachPin(back)] : const []);
}

/// [record] opens the packing task as its own form page: changeable until it is confirmed, then shown as it was filled in.
void dlgPack(Doc pc, {bool record = false}) {
  final q = S.calc(pc).qty;
  mform(record ? 'Packing · ${pc.id}' : 'Confirm packing · ${pc.id}', [

    const F.header('Packing'),
    F('pack_no', 'Pack No.', type: 'readonly', def: pc.id),
    F('pick_ref', 'Pick Ref.', type: 'readonly', def: S.docsOf('PK').where((k) => k.ref == pc.ref).map((k) => k.id).firstOrNull ?? (pc.ref ?? '—')),
    // what is being packed: the items picked for this order (shown for information, not changeable here)
    const F.header('Items being packed'),
    for (var i = 0; i < pc.lines.length; i++) ...[
      F('pit$i', pc.lines.length > 1 ? 'Item ${i + 1}' : 'Item', type: 'readonly', def: pc.lines[i].desc ?? S.item(pc.lines[i].item).name),
      F('pqty$i', 'Quantity', type: 'readonly', def: '${pc.lines[i].qty} ${S.item(pc.lines[i].item).uom}'),
      if (pc.lines[i].bin.isNotEmpty) F('pbin$i', 'Bin / Location', type: 'readonly', def: pc.lines[i].bin),
      if (pc.lines[i].batch.isNotEmpty) F('pbat$i', S.item(pc.lines[i].item).track == 'Serial' ? 'Serial Nos.' : 'Batch No.', type: 'readonly', def: pc.lines[i].batch, full: true),
    ],
    const F.header('Packing details'),
    F('cartons', 'No. of Cartons', type: 'number', def: '${pc.cartons ?? math.max(1, (q / 60).ceil())}', req: true),
    F('weight', 'Gross Weight (kg)', def: pc.weight ?? '${(q * 0.6).round()} kg', req: true),
    F('packed_by', 'Packed By', type: 'select', req: true, def: pc.picker ?? '', options: opts(['Ravi Teja', 'Suresh N', 'Kiran Kumar'])),
    F('pack_date', 'Pack Date', type: 'date', def: pc.status == 'Packing' ? todayStr() : pc.date),
  ], (v, _) {
    pc.picker = v['packed_by'] as String; // remembered, so the packed form shows who packed it
    after(S.pack(pc.id, (v['cartons'] as num).toInt(), v['weight'] as String));
    return false;
  }, status: pc.status, statusNote: 'Becomes Packed on confirm and the delivery note is created.', btn: 'Confirm packed', icon: 'package', note: record ? null : 'On confirm the system creates the delivery note, ready to dispatch.',
      readOnly: record && pc.status != 'Packing', cancel: !record, headerActions: record ? [AttachPin(pc.id)] : const []);
}

/// [record] opens the delivery note as its own form page: changeable until it is dispatched, then shown as it was filled in.
void dlgDispatch(Doc dn, {bool record = false}) {
  final sub = dn.lines.fold<double>(0, (a, l) => a + l.qty * l.rate);
  final ready = dn.status == 'Ready to Dispatch';
  final driverName = (dn.carrier ?? '').contains(' · ') ? (dn.carrier ?? '').split(' · ').last : '';
  mform(record ? 'Delivery note · ${dn.id}' : 'Dispatch · ${dn.id}', [

    const F.header('Dispatch'),
    F('dn_no', 'Delivery No.', type: 'readonly', def: dn.id),
    F('so', 'SO Ref.', type: 'readonly', def: dn.ref ?? '—'),
    F('cust', 'Customer', type: 'readonly', def: S.partyName(dn)),
    F('dl_date', 'Dispatch Date', type: 'date', def: ready ? todayStr() : dn.date, req: true),
    // the vehicle and driver already used stay in the lists, so a dispatched note shows them as they were
    F('veh', 'Vehicle', type: 'select', req: true, def: dn.vehicle ?? '', options: opts([...S.vehicles.where((x) => x != '—'), if ((dn.vehicle ?? '').isNotEmpty && !S.vehicles.contains(dn.vehicle)) dn.vehicle!])),
    F('driver', 'Driver', type: 'select', req: true, def: driverName, options: opts([...drivers.where((x) => x.status == 'Active').map((x) => x.name), if (driverName.isNotEmpty && !drivers.any((x) => x.status == 'Active' && x.name == driverName)) driverName])),
    if (sub > S.params.ewayLimit)
      F('eway', 'E-way Bill No.', req: true, def: (dn.eway ?? '').startsWith('EWB') ? dn.eway! : '', hint: '12-digit e-way bill number', help: 'Required — value above ₹50,000')
    else
      const F.calc('eway', 'E-way Bill No.', def: 'Not required (below ₹50,000)'),
  ], (v, _) {
    // stock cannot go negative: every line must be covered by what is in the warehouse
    for (final l in dn.lines) {
      final have = S.stk(dn.wh, l.item).onhand;
      if (have < l.qty) {
        toast('${S.item(l.item).name}: only $have in ${S.wh(dn.wh).code}, but ${l.qty} are being dispatched');
        return false;
      }
    }
    dn.eway = (v['eway'] as String?)?.isNotEmpty == true && sub > S.params.ewayLimit ? v['eway'] as String : dn.eway;
    after(S.dnDispatch(dn.id, 'Own fleet · ${v['driver']}', v['veh'] as String));
    return false;
  },
      status: dn.status, statusNote: 'Becomes Dispatched and the tax invoice is created.', btn: 'Dispatch now',
      icon: 'truck',
      note: record ? null : 'On dispatch the system reduces on-hand stock, releases the reservation and starts delivery tracking.',
      // once dispatched: the form is shown as it was filled in, with the invoice buttons as the next step
      readOnly: record && !ready, cancel: !record, headerActions: record ? [AttachPin(dn.id)] : const [],
      extra: record && !ready ? (_) => actionsFor(dn, nextOnly: true) : null);
}

/// The currency a document was agreed in, and ₹ per unit — looked up on the document or the one it came from.
(String, double) docCurrency(Doc d) {
  Doc? x = d;
  for (var depth = 0; x != null && depth < 5; depth++, x = x.ref == null || x.ref == x.id ? null : S.doc(x.ref!)) {
    final cur = x.extra['v:currency'];
    if (cur != null) {
      final fx = cur == 'INR' ? 1.0 : (double.tryParse(x.extra['v:exrate'] ?? '') ?? S.currencies.where((c) => c.code == cur).firstOrNull?.rate ?? 1.0);
      return (cur, fx > 0 ? fx : 1.0);
    }
  }
  return ('INR', 1.0);
}

/// Exchange-rate field shown when a foreign currency is picked on a form ([key] is the currency select).
F fxField(String key, double def) => F('fx', 'Exchange Rate (₹ per 1 unit of the currency)', type: 'number', def: def == 1 ? '' : def.toString(), when: key, whenIs: '!INR', show: true, hint: 'Leave blank to use the rate in Setup › Currencies');

/// ₹ per unit for the currency picked on a form (typed rate, else the rate in Setup › Currencies).
double fxOf(Map<String, dynamic> v, String key) {
  final cur = v[key] as String? ?? 'INR';
  if (cur == 'INR') return 1;
  final typed = v['fx'] is num ? (v['fx'] as num).toDouble() : double.tryParse('${v['fx'] ?? ''}') ?? 0;
  return typed > 0 ? typed : (S.currencies.where((c) => c.code == cur).firstOrNull?.rate ?? 1);
}

void dlgPay(Doc d) {
  final bal = d.amount - d.paid;
  final (cur, fx) = docCurrency(d);
  mform('Record payment · ${d.id}', [
    const F.header('Document'),
    F('pay_date', 'Payment Date', type: 'date', def: todayStr(), req: true),
    F('pay_type', 'Payment Type', type: 'select', req: true, options: opts(['Against Invoice', 'Advance', 'On Account'])),
    F.calc('inv_ref', 'Invoice Ref.', def: d.id),
    F('currency', 'Currency', type: 'select', req: true, def: cur, options: opts(S.currencyCodes)),
    fxField('currency', fx),
    F('amt', 'Amount Received (in the currency above)', type: 'number', def: (bal / fx).toStringAsFixed(2), req: true),
    const F.header('Payment'),
    F('mode', 'Payment Mode', type: 'select', req: true, options: opts(['NEFT', 'RTGS', 'UPI', 'Cheque', 'Cash'])),
    F('deposit', 'Deposit Account', type: 'select', req: true, options: opts(['Bank — HDFC Current A/c', 'Cash'])),
    F('utr', 'Bank Reference / Cheque No.', def: 'UTR N${2700 + S.docs.length} ${1000 + S.docs.length}', hint: 'Required unless paid in cash'),
    F('txn_date', 'Transaction Date', type: 'date', def: todayStr()),
    const F('bank_chg', 'Bank Charges (₹)', type: 'number', def: '0'),
    const F('tds', 'TDS Deducted (₹)', type: 'number', def: '0'),
    const F.header('Other'),
    const F('remarks', 'Remarks', type: 'textarea', full: true),
  ], (v, _) {
    if (v['mode'] != 'Cash' && (v['utr'] as String).isEmpty) {
      toast('Bank reference or cheque number is required unless the payment is in cash');
      return false;
    }
    // a receipt in another currency is converted to ₹ at the exchange rate
    final amt = (v['amt'] as num).toDouble() * fxOf(v, 'currency');
    if (amt <= 0) {
      toast('Enter an amount');
      return false;
    }
    after(S.invPay(d.id, amt, v['mode'] as String, v['utr'] as String));
    return false;
  }, status: d.status, statusNote: 'The invoice becomes Paid, or Partially Paid, when the receipt is saved.', btn: 'Save receipt', icon: 'wallet', intro: '${S.partyName(d)} · balance due ${fmtINR(bal)}', note: 'The receipt is allocated to this invoice. Bank-statement import can do this matching automatically.');
}

void dlgSalesReturn(Doc d) {
  mform('Create sales return · ${d.id}', [

    const F.header('Sales Return'),
    F('ret_no', 'Return No.', type: 'readonly', def: nextNo('SR')),
    F('ret_date', 'Return Date', type: 'date', def: todayStr(), req: true),
    F.calc('inv_ref', 'Delivery / SO Ref.', def: d.ref == null ? d.id : '${d.id} · ${d.ref}'),
    F('cust', 'Customer', type: 'readonly', def: S.partyName(d)),
    F('why', 'Reason', type: 'select', req: true, options: opts(['Damaged in transit', 'Wrong item shipped', 'Quality issue', 'Excess supplied'])),
    F('wh', 'Receiving Warehouse', type: 'select', def: d.wh, options: S.warehouses.map((w) => Opt(w.id, '${w.code} — ${w.city}')).toList()),
    const F.header('Line Item'),
    F('item', 'Item', type: 'select', req: true, options: d.lines.map((l) => Opt(l.item, '${S.item(l.item).name} (delivered ${l.qty})')).toList()),
    const F('qty', 'Return Qty', type: 'number', def: '1', req: true),
    const F('batch', 'Batch / Serial No.', hint: 'Required for batch- or serial-tracked items'),
  ], (v, _) {
    final ln = d.lines.firstWhere((l) => l.item == v['item']);
    if ((v['qty'] as num).toInt() > ln.qty) {
      toast('Return Qty cannot be more than the delivered quantity (${ln.qty})');
      return false;
    }
    final tp = S.item(v['item'] as String).track;
    if (tp != 'None' && (v['batch'] as String).trim().isEmpty) {
      toast('Enter the ${tp == 'Batch' ? 'Batch No.' : 'Serial No(s).'} of the goods being returned');
      return false;
    }
    after(S.invReturn(d.id, v['item'] as String, (v['qty'] as num).toInt(), v['why'] as String));
    return false;
  }, status: 'Draft', statusNote: 'Set automatically on save.', btn: 'Create return', icon: 'refund');
}

void dlgBinAllocation(Doc pa, {bool record = false}) {
  // bins are allocated only after the goods are received and their quality check is complete
  final grn = pa.ref == null ? null : S.doc(pa.ref!);
  if (pa.status == 'To Do' && grn != null && !qcDone(grn)) {
    toast('${grn.id} is still in quality check · allocate bins after QC is complete');
    return;
  }
  final bins = S.bins.where((b) => b.wh == pa.wh).map((b) => b.code).toList();
  final binOpts = opts(bins.isEmpty ? ['A-01', 'A-02', 'B-01', 'B-02'] : bins);
  mform('Bin allocation · ${pa.id}', [
    const F.header('Bin Allocation'),
    F('task', 'Task No.', type: 'readonly', def: pa.id),
    F('grn', 'GRN Ref.', type: 'readonly', def: pa.ref ?? '—'),
    F('wh', 'Warehouse', type: 'readonly', def: '${S.wh(pa.wh).code} — ${S.wh(pa.wh).city}'),
    const F.header('Line Items · choose the storage bin'),
    for (var i = 0; i < pa.lines.length; i++) ...[
      F('it$i', 'Item', type: 'readonly', def: '${S.item(pa.lines[i].item).name} · ${pa.lines[i].qty} ${S.item(pa.lines[i].item).uom}'),
      F('bin$i', 'Bin', type: 'select', req: true, def: pa.lines[i].bin, options: binOpts),
    ],
  ], (v, _) {
    for (var i = 0; i < pa.lines.length; i++) {
      pa.lines[i].bin = v['bin$i'] as String;
    }
    final res = S.paConfirm(pa.id);
    after(Res(res.msg, pa.ref ?? pa.id));
    return false;
  }, status: pa.status, statusNote: pa.status == 'Completed' ? 'Bins confirmed · the goods are stored in the bins below.' : 'Becomes Completed when the bins are confirmed.', btn: 'Confirm bin allocation', icon: 'check',
      readOnly: record && pa.status != 'To Do', cancel: !record, headerActions: record ? [AttachPin(pa.id)] : const [],
      extra: record && pa.status != 'To Do' ? (_) => actionsFor(pa, nextOnly: true) : null);
}

void newSupplierQuoteForm({String? rfq}) {
  final rfqs = S.docsOf('RFQ').where((r) => ['Awaiting Quotes', 'Quotes Received'].contains(r.status)).toList();
  if (rfqs.isEmpty) {
    toast('No open RFQ — create an RFQ first');
    return;
  }
  final r0 = rfq == null ? rfqs.first : S.doc(rfq)!;
  final sups = r0.invited.isEmpty ? S.suppliers.map((s) => s.id).toList() : r0.invited;
  mform('New supplier quotation', [
    const F.header('Supplier Quotation'),
    F('sq_no', 'SQ No.', type: 'readonly', def: 'SQ-${r0.id.split('-').skip(1).join('-')}-${r0.quotes.length + 1}'),
    F('rfq', 'RFQ Ref.', type: 'select', req: true, def: r0.id, options: rfqs.map((r) => Opt(r.id, '${r.id} · ${S.item(r.lines.first.item).name}')).toList()),
    F('sup', 'Supplier', type: 'select', req: true, options: [const Opt('', 'Select supplier'), ...sups.map((s) => Opt(s, S.sup(s).name))]),
    F('date', 'Quotation Date', type: 'date', def: todayStr(), req: true),
    F('valid', 'Valid Until', type: 'date', def: addDays(todayStr(), 15), req: true),
    const F.header('Line Item'),
    F('item', 'Item', type: 'readonly', def: '${S.item(r0.lines.first.item).name} (${r0.lines.first.item})'),
    F('qty', 'Qty', type: 'number', def: '${r0.lines.first.qty}', req: true),
    F('rate', 'Rate (₹)', type: 'number', def: S.item(r0.lines.first.item).cost.toStringAsFixed(2), req: true),
    F('tax', 'Tax Code', type: 'select', req: true, def: S.taxNameFor(S.item(r0.lines.first.item).gst), options: opts(S.taxNames)),
    F('days', 'Delivery Days', type: 'number', def: '${S.sup(sups.first).lead}', req: true),
  ], (v, _) {
    if ((v['sup'] as String).isEmpty) {
      toast('Select the Supplier');
      return false;
    }
    if ((v['valid'] as String).compareTo(v['date'] as String) < 0) {
      toast('Valid Until cannot be before the Quotation Date');
      return false;
    }
    final r = S.doc(v['rfq'] as String)!;
    r.quotes = [...r.quotes.where((q) => q.sup != v['sup']), Quote(v['sup'] as String, (v['rate'] as num).toDouble(), (v['days'] as num).toInt(), v['valid'] as String)];
    S.setStatus(r, 'Quotes Received', Users.buyer, 'quotation from ${S.sup(v['sup'] as String).name}');
    after(Res('Supplier quotation recorded against ${r.id}', r.id));
    return false;
  }, status: 'Draft', statusNote: 'Set automatically on save.', btn: 'Save quotation', icon: 'check');
}

/// Reject purchase request with mandatory reason
void dlgRejectPr(Doc d) {
  mform('Reject Purchase Request · ${d.id}', [
    const F.header('Rejection'),
    const F('reason', 'Rejection Reason', type: 'textarea', req: true, full: true, hint: 'Specify why this purchase request is being rejected (e.g. Budget limit exceeded, duplicate request, etc.)'),
  ], (v, _) {
    final reason = (v['reason'] as String).trim();
    if (reason.isEmpty) {
      toast('Please enter the rejection reason');
      return false;
    }
    after(S.prReject(d.id, reason));
    return false;
  }, btn: 'Reject Request', icon: 'x', status: d.status, statusNote: 'Becomes Rejected; the reason is recorded and displayed on the request.');
}

/// Receive goods against a purchase order: the full goods receipt form.
void dlgReceive(Doc d) => openGrnForm(d);

void dlgQc(Doc g) {
  mform('QC result · ${g.id}', [

    const F.header('Quality Check'),
    F('grn', 'GRN No.', type: 'readonly', def: g.id),
    F('inspector', 'QC Inspector', type: 'select', req: true, options: opts(['Lakshmi P (QC)', 'Suresh N', 'Ravi Teja'])),
    F('qc_status', 'QC Status', type: 'select', req: true, options: opts(['Passed', 'Partially passed', 'Failed'])),
    const F.header('Accepted Quantity · rest is rejected'),
    for (var i = 0; i < g.lines.length; i++) F('a$i', '${S.item(g.lines[i].item).name} · Accepted Qty (received ${g.lines[i].qty})', type: 'number', def: '${g.lines[i].qty}', req: true),
    const F('rej_reason', 'Rejection Reason', hint: 'Mandatory if any quantity is rejected', full: true),
  ], (v, _) {
    var rejected = 0;
    for (var i = 0; i < g.lines.length; i++) {
      final a = (v['a$i'] as num).toInt();
      if (a > g.lines[i].qty) {
        toast('${S.item(g.lines[i].item).name}: Accepted Qty cannot be more than the received quantity (${g.lines[i].qty})');
        return false;
      }
      rejected += g.lines[i].qty - a;
    }
    if (rejected > 0 && (v['rej_reason'] as String).trim().isEmpty) {
      toast('Enter the Rejection Reason — $rejected unit(s) are rejected');
      return false;
    }
    g.qcBy = (v['inspector'] as String).split(' (').first;
    g.qcResult = rejected == 0 ? 'Passed' : (v['qc_status'] as String) == 'Passed' ? 'Partially passed' : v['qc_status'] as String;
    g.qcNote = (v['rej_reason'] as String).trim();
    g.qcDate = todayStr();
    final res = S.grnQc(g.id, [for (var i = 0; i < g.lines.length; i++) (v['a$i'] as num).toInt()]);
    after(Res(res.msg, g.id));
    return false;
  }, status: g.status, statusNote: 'Becomes QC Checked when the result is posted; rejected units go to a purchase return.', btn: 'Post QC result', icon: 'checksq', note: 'Accepted stock becomes available. Rejected units create a purchase return automatically. Bins are allocated by the storage rules.');
}

/// A record laid out like the order forms: status bar, sections of read-only fields, the line items table,
/// then remarks. Not changeable; the next step is the button at the bottom.
void openRecordPage(Doc d, String title, List<(String, List<Kv>)> sections, {String? remarks, String? statusNote}) {
  openFormPage(
    title,
    IgnorePointer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FormStatusBar(d.status, statusNote ?? 'Current status of ${d.id}. It changes automatically as the document moves forward.'),
        for (var i = 0; i < sections.length; i++) ...[SectionTitle(sections[i].$1, first: i == 0), _RecordFields(sections[i].$2)],
        if (d.lines.isNotEmpty) ...[const SectionTitle('Line Items'), linesTable(d)],
        if (remarks != null) ...[const SectionTitle('Remarks'), _RecordFields([Kv.t('Remarks', remarks.isEmpty ? '—' : remarks, full: true)])],
      ]),
    ),
    subtitle: 'This document is no longer changeable · the next step is the button at the bottom',
    headerActions: [AttachPin(d.id)],
    actions: (_) => actionsFor(d, nextOnly: true),
  );
}

String _batches(Doc d) {
  final b = d.lines.map((l) => l.batch).where((x) => x.isNotEmpty).join(', ');
  return b.isEmpty ? '—' : b;
}

/// A created sales return: the return form, filled in and not changeable.
void recordSalesReturn(Doc sr) {
  final src = sr.ref == null ? null : S.doc(sr.ref!);
  openRecordPage(sr, 'Sales return · ${sr.id}', [
    ('Sales Return', [
      Kv.t('Return No.', sr.id),
      Kv.t('Return Date', sr.date),
      Kv.t('Delivery / SO Ref.', src == null ? (sr.ref ?? '—') : (src.ref == null ? src.id : '${src.id} · ${src.ref}')),
      Kv.t('Customer', S.partyName(sr)),
      Kv.t('Reason', sr.reason ?? '—'),
      Kv.t('Receiving Warehouse', '${S.wh(sr.wh).code} — ${S.wh(sr.wh).city}'),
      Kv.t('Batch / Serial No.', _batches(sr)),
    ]),
  ], statusNote: 'Current status of ${sr.id}. It changes automatically as the return is received and credited.');
}

/// A created purchase return: the return form, filled in and not changeable.
void recordPurchaseReturn(Doc r) {
  final g = r.ref == null ? null : S.doc(r.ref!);
  final sup = S.suppliers.where((x) => x.id == r.party).firstOrNull;
  openRecordPage(r, 'Purchase return · ${r.id}', [
    ('Return Details', [
      Kv.t('Return No.', r.id),
      Kv.t('Return Date', r.date),
      Kv.t('GRN No.', r.ref ?? '—'),
      Kv.t('PO No.', g?.ref ?? '—'),
      Kv.t('Reason', r.reason ?? '—'),
      Kv.t('Return From Warehouse', '${S.wh(r.wh).code} — ${S.wh(r.wh).city}'),
      Kv.t('Batch / Serial No.', _batches(r)),
    ]),
    ('Supplier', [
      Kv.t('Supplier', S.partyName(r)),
      Kv.t('Supplier GSTIN', sup?.gstin ?? '—'),
    ]),
  ], remarks: r.note ?? '', statusNote: 'Current status of ${r.id}. It changes automatically as the return is approved and dispatched.');
}

void dlgPurchaseReturn(Doc g) {
  final sup = S.suppliers.where((x) => x.id == g.party).firstOrNull;
  // only rejected units that are not on a return yet can be returned: goods that passed QC stay in stock
  final prts = S.docsOf('PRT');
  int left(Line l) => returnableQty(g, l, prts);
  final rows = [for (var i = 0; i < g.lines.length; i++) if (left(g.lines[i]) > 0) i];
  if (rows.isEmpty) {
    toast('Nothing to return: every unit of ${g.id} passed quality check (or its rejected units are already on a return)');
    return;
  }
  mform('New purchase return · ${g.id}', [
    const F.header('Return Details'),
    F('ret_no', 'Return No.', type: 'readonly', def: nextNo('PRT')),
    F('ret_date', 'Return Date', type: 'date', def: todayStr(), req: true),
    F('grn_ref', 'GRN No.', type: 'readonly', def: g.id),
    F('po_ref', 'PO No.', type: 'readonly', def: g.ref ?? '—'),
    F('sup', 'Supplier', type: 'readonly', def: S.partyName(g)),
    F('gstin', 'Supplier GSTIN', type: 'readonly', def: sup?.gstin ?? '—'),
    F('why', 'Reason', type: 'select', req: true, def: 'Rejected at QC',
        options: opts(['Rejected at QC', 'Damaged / leaking', 'Quality failure found later', 'Excess supplied', 'Wrong item supplied'])),
    F('wh', 'Return From Warehouse', type: 'select', def: g.wh, req: true, options: S.warehouses.map((w) => Opt(w.id, '${w.code} — ${w.city}')).toList()),
    const F.header('Items to Return'),
    for (final i in rows)
      F('q$i', '${g.lines[i].desc ?? S.item(g.lines[i].item).name} · Return Qty (received ${g.lines[i].qty}, rejected ${g.lines[i].qty - g.lines[i].acc}, can return ${left(g.lines[i])})',
          type: 'number', def: '${left(g.lines[i])}', req: true),
    const F('batch', 'Batch / Serial No.', hint: 'Required for batch- or serial-tracked items'),
    const F('remarks', 'Remarks', type: 'textarea', full: true, hint: 'e.g. 6 cartons damaged on arrival / rejected by QC'),
  ], (v, _) {
    final why = v['why'] as String;
    final qtys = <String, int>{};
    for (final i in rows) {
      final l = g.lines[i];
      final q = (v['q$i'] as num).toInt();
      if (q < 0) {
        toast('Return Qty cannot be negative');
        return false;
      }
      if (q == 0) continue;
      final name = l.desc ?? S.item(l.item).name;
      final max = left(l);
      if (q > max) {
        toast('$name: only $max rejected unit(s) are left to return from this receipt');
        return false;
      }
      final tp = S.item(l.item).track;
      if (tp != 'None' && (v['batch'] as String).trim().isEmpty) {
        toast('Enter the ${tp == 'Batch' ? 'Batch No.' : 'Serial No(s).'} of $name');
        return false;
      }
      qtys[l.item] = q;
    }
    if (qtys.isEmpty) {
      toast('Enter the Return Qty for at least one item');
      return false;
    }
    after(S.prtCreate(g.id, qtys, why, v['ret_date'] as String, v['wh'] as String, v['remarks'] as String));
    return false;
  }, status: 'Draft', statusNote: 'Becomes Submitted for approval; once approved the items can be dispatched.', btn: 'Submit return', icon: 'check', size: ModalSize.wide);
}

void dlgSupplierInvoice(Doc d) {
  final recv = d.lines.where((l) => l.recv > 0).toList();
  final pre = S.sup(d.party!).name.split(' ').first;
  // the invoice starts in the currency of the purchase order; rates are typed in that currency
  final (cur, fx) = docCurrency(d);
  mform('Enter supplier invoice · ${d.id}', [
    const F.header('Document'),
    F('post_date', 'Posting Date', type: 'date', def: todayStr(), req: true),
    F('no', 'Supplier Invoice No.', def: '${pre.substring(0, math.min(3, pre.length)).toUpperCase()}/INV/${4000 + S.docs.length}', req: true),
    F('inv_date', 'Supplier Invoice Date', type: 'date', def: todayStr(), req: true),
    F('due', 'Due Date', type: 'date', def: addDays(todayStr(), S.sup(d.party!).terms), req: true),
    F('currency', 'Currency', type: 'select', req: true, def: cur, options: opts(S.currencyCodes)),
    fxField('currency', fx),
    F.calc('po_ref', 'PO Ref.', def: d.id),
    F('grn_ref', 'GRN Ref.', type: 'select', options: opts(['—', ...S.docsOf('GRN').where((g) => g.ref == d.id).map((g) => g.id)])),
    F('terms', 'Payment Terms', type: 'select', req: true, def: 'Net ${S.sup(d.party!).terms} days', options: opts(S.termNames)),
    const F('tds', 'TDS Amount (₹)', type: 'number', def: '0'),
    const F.header('Line Items · Invoiced Rate (in the currency above)'),
    for (final l in recv)
      F('r_${l.item}', '${S.item(l.item).name} · qty ${l.recv} · PO rate ${cur == 'INR' ? fmtINR(l.rate) : '$cur ${(l.rate / fx).toStringAsFixed(2)}'}', type: 'number', def: (l.rate / fx).toStringAsFixed(cur == 'INR' ? 2 : 4), req: true),
    const F.header('Other'),
    const F('remarks', 'Remarks', type: 'textarea', full: true),
    const F('notes', 'Internal Notes', type: 'textarea', full: true),
  ], (v, _) {
    final fxNow = fxOf(v, 'currency');
    final rates = <String, double>{for (final l in recv) l.item: (v['r_${l.item}'] as num).toDouble() * fxNow}; // saved in ₹
    after(S.poInvoice(d.id, v['no'] as String, rates));
    return false;
  }, status: 'Draft', statusNote: 'Becomes Approved if verified, or Pending Approval if the price differs.', btn: 'Save supplier invoice', icon: 'file', note: 'On saving, the invoice is checked automatically against the purchase order and the goods receipt. A price difference above ${S.params.matchTolerance.toStringAsFixed(0)}% requires approval.');
}

/// [record] opens the count as its own form page: counted quantities can be entered until the count is submitted,
/// then it is shown as it was filled in, with the system quantity and the difference for every line.
void dlgCount(Doc d, {bool record = false}) {
  final done = d.status != 'Counting';
  mform(record ? 'Stock count · ${d.id}' : 'Enter counts · ${d.id}', [

    const F.header('Count'),
    F('cc_no', 'Count No.', type: 'readonly', def: d.id),
    F('wh', 'Warehouse', type: 'readonly', def: '${S.wh(d.wh).code} — ${S.wh(d.wh).city}'),
    if ((d.zone ?? '').isNotEmpty) F('zone', 'Zone', type: 'readonly', def: d.zone!),
    F('count_date', 'Count Date', type: 'date', req: true, def: d.date),
    F('by', 'Counted By', type: 'select', req: true, def: d.counter ?? '', options: opts(['Suresh N', 'Ravi Teja', 'Kiran Kumar', if ((d.counter ?? '').isNotEmpty && !['Suresh N', 'Ravi Teja', 'Kiran Kumar'].contains(d.counter)) d.counter!])),
    F('count_type', 'Count Type', type: 'select', show: true, def: d.source ?? '', options: opts(['Zone count', 'ABC cycle count', 'Spot check', 'Full count'])),
    const F.header('Counted Quantity · what is physically in the bin'),
    for (var i = 0; i < d.lines.length; i++) ...[
      // each line says exactly what was counted: the item, its batch, and the bin it sits in
      F('it$i', d.lines.length > 1 ? 'Item ${i + 1}' : 'Item', type: 'readonly', def: S.item(d.lines[i].item).name),
      F('bt$i', 'Batch No.', type: 'readonly', def: d.lines[i].batch.isEmpty ? '— (not batch-tracked)' : d.lines[i].batch),
      F('bin$i', 'Bin / Location', type: 'readonly', def: d.lines[i].bin.isEmpty ? 'A-01' : d.lines[i].bin),
      if (done) F('sys$i', 'System Qty', type: 'readonly', def: '${d.lines[i].sys ?? 0}'),
      F('c$i', 'Counted Qty', type: 'number', req: true, def: d.lines[i].cnt != null ? '${d.lines[i].cnt}' : '', hint: 'Count and enter'),
      if (done)
        F('diff$i', 'Difference', type: 'readonly', def: () {
          final x = (d.lines[i].cnt ?? 0) - (d.lines[i].sys ?? 0);
          return x == 0 ? '0 — matches' : (x > 0 ? '+$x (more than the system)' : '$x (less than the system)');
        }()),
    ],
    F('var_reason', 'Difference Reason', full: true, def: d.reason ?? '', hint: 'Mandatory if any count differs from the system quantity'),
  ], (v, _) {
    var diff = 0;
    for (var i = 0; i < d.lines.length; i++) {
      if ((v['c$i'] as num).toInt() != S.countSys(d.wh, d.lines[i])) diff++;
    }
    if (diff > 0 && (v['var_reason'] as String).trim().isEmpty) {
      toast('$diff line(s) differ from the system quantity — enter the Difference Reason');
      return false;
    }
    d.counter = v['by'] as String;
    d.date = v['count_date'] as String;
    if ((v['count_type'] as String).isNotEmpty) d.source = v['count_type'] as String;
    d.reason = (v['var_reason'] as String).trim();
    after(S.ccCount(d.id, [for (var i = 0; i < d.lines.length; i++) (v['c$i'] as num).toInt()]));
    return false;
  }, status: d.status, statusNote: 'Becomes Completed; differences become stock adjustments.', btn: 'Submit count', icon: 'check',
      // "Save changes" keeps the count open (still Counting) with what is typed so far; "Submit count" locks it
      altBtn: record && !done ? 'Save changes' : null,
      onAlt: (v, _) {
        d.counter = (v['by'] as String).isEmpty ? d.counter : v['by'] as String;
        if ((v['count_date'] as String).isNotEmpty) d.date = v['count_date'] as String;
        if ((v['count_type'] as String).isNotEmpty) d.source = v['count_type'] as String;
        d.reason = (v['var_reason'] as String).trim();
        for (var i = 0; i < d.lines.length; i++) {
          final n = v['c$i'];
          d.lines[i].cnt = n is num ? n.toInt() : null;
        }
        closeAll();
        S.refresh();
        toast('${d.id} saved · submit the count when every quantity is entered');
        openDoc(d.id);
      },
      intro: record && done ? null : 'Enter the quantity physically counted for each line. The system quantity stays hidden while counting, so the count is honest; it is shown with the difference once the count is submitted.',
      readOnly: record && done,
      cancel: !record,
      headerActions: record ? [AttachPin(d.id)] : const [],
      // the adjustments created from the differences are one tap away
      extra: record
          ? (_) => [
                // a count still being counted can be deleted: nothing has been posted to stock yet
                if (!done)
                  deleteBtn(() => confirmDelete(d.id, () {
                        S.deleteDocs([d]);
                        closeAll();
                        S.refresh();
                        toast('${d.id} deleted');
                      })),
                for (final r in d.refs) if (S.doc(r)?.type == 'ADJ') Btn.secondary('Adjustment $r', icon: 'sliders', onTap: () => openDocNav(r)),
              ]
          : null);
}

// ================================================================ new document form (with lines)
/// Statuses in which each document can still be changed.
const editableStatus = <String, List<String>>{
  'PR': ['Draft'],
  'PO': ['Draft', 'Pending Approval'],
  'QT': ['Draft'], // once it is sent to the customer it can no longer be changed
  'SO': ['Pending Approval', 'On Hold', 'Confirmed'],
  'TR': ['Requested'],
  'ADJ': ['Draft', 'Pending Approval'],
};

bool canEditDoc(Doc d) => editableStatus[d.type]?.contains(d.status) ?? false;

void editDoc(Doc d) {
  closeAll();
  openFormPage('Edit ${docTitle(d.type)} · ${d.id}', DocForm(d.type, party: d.party, editId: d.id), headerActions: [AttachPin(d.id)], subtitle: d.type == 'PR' ? _prSubtitle : null);
}

void openDocForm(String t, {String? party}) {
  final pt = S.dt[t]!.party;
  final missing = [
    if (S.items.isEmpty) 'an item (Setup → Items)',
    if (pt == 'C' && S.customers.isEmpty) 'a customer (Setup → Customers)',
    // a purchase request can be raised before the supplier is known
    if (pt == 'S' && t != 'PR' && S.suppliers.isEmpty) 'a supplier (Setup → Suppliers)',
    if ((t == 'QT' || t == 'SO') && S.salesPersons.isEmpty) 'a sales person (Setup → Sales & Delivery Team)',
  ];
  if (missing.isNotEmpty) {
    toast('First add ${missing.join(' and ')}');
    return;
  }
  openFormPage('New ${docTitle(t)}', DocForm(t, party: party), subtitle: t == 'PR' ? _prSubtitle : null);
}

/// A purchase request has no mandatory fields.
const _prSubtitle = 'Fill in what you need and save';

// ================================================================ searchable item picker (line items)
/// Line-item "Item" box: shows the chosen item; clicking opens a search list.
class ItemSearchField extends StatelessWidget {
  final String value;
  final String wh;
  final ValueChanged<String> onChanged;
  /// Purchase lines may have no item: the description is typed instead.
  final bool allowEmpty;
  const ItemSearchField({super.key, required this.value, required this.wh, required this.onChanged, this.allowEmpty = false});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty || !S.items.any((x) => x.id == value)) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final v = await pickItem(context, selected: value, wh: wh, allowEmpty: allowEmpty);
          if (v != null) onChanged(v);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
          child: const Row(children: [
            Icon(Icons.search, size: 15, color: C.faint),
            SizedBox(width: 6),
            Expanded(child: Text('Select item', style: TextStyle(fontSize: 12.5, color: C.faint))),
          ]),
        ),
      );
    }
    final p = S.item(value);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final v = await pickItem(context, selected: value, wh: wh, allowEmpty: allowEmpty);
        if (v != null) onChanged(v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
        child: Row(children: [
          const Icon(Icons.search, size: 15, color: C.faint),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25)),
              Text('${p.id}${p.track == 'None' ? '' : ' · ${p.track} tracked'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.faint, height: 1.25)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Search items by name, code, category or HSN. Returns the chosen item id.
Future<String?> pickItem(BuildContext context, {String? selected, required String wh, bool allowEmpty = false}) {
  final q = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      final t = q.text.trim().toLowerCase();
      final list = S.items.where((p) => t.isEmpty || '${p.name} ${p.id} ${p.cat} ${p.hsn}'.toLowerCase().contains(t)).toList();
      return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
              child: Row(children: [
                const Expanded(child: Text('Select item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(ctx).pop()),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: q,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(hintText: 'Search by item name, code, category or HSN…', prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (_) => setD(() {}),
                onSubmitted: (_) {
                  if (list.length == 1) Navigator.of(ctx).pop(list.first.id);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Text('${list.length} item(s) · stock shown for ${S.wh(wh).code}', style: const TextStyle(fontSize: 11.5, color: C.faint)),
            ),
            if (allowEmpty)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(''),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(18, 4, 18, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
                  child: const Row(children: [
                    Icon(Icons.edit_note, size: 18, color: C.soft),
                    SizedBox(width: 8),
                    Expanded(child: Text('No item · I will type a description instead', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
            Flexible(
              child: list.isEmpty
                  ? const Padding(padding: EdgeInsets.all(24), child: Text('No item matches your search.', textAlign: TextAlign.center, style: TextStyle(color: C.faint)))
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: C.border),
                      itemBuilder: (_, i) {
                        final p = list[i];
                        final av = S.avail(wh, p.id);
                        return InkWell(
                          onTap: () => Navigator.of(ctx).pop(p.id),
                          child: Container(
                            color: p.id == selected ? C.blue50 : null,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text('${p.id} · ${p.cat} · HSN ${p.hsn} · GST ${p.gst}%', style: const TextStyle(fontSize: 11.5, color: C.faint)),
                                ]),
                              ),
                              if (p.track != 'None') Padding(padding: const EdgeInsets.only(right: 10), child: Tag(p.track)),
                              Text('$av ${p.uom}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: av > 0 ? C.text : C.red)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      );
    }),
  ).whenComplete(() {
    // the dialog is still sliding away for a moment after it returns: dispose the search box only once it is really gone
    Future<void>.delayed(const Duration(milliseconds: 600), q.dispose);
  });
}

class DocForm extends StatefulWidget {
  final String t;
  final String? party;
  /// When set, the form opens this existing document for editing.
  final String? editId;
  /// Purchase order made from this approved purchase request: the form starts filled in from it.
  final String? fromId;
  /// Quotation made from this opportunity: the form starts filled in from it.
  final String? fromOppId;
  /// Purchase order from a request: the request's supplier whose lines this order takes ('' = lines without a supplier).
  final String? fromSup;
  /// Shows the saved document exactly as its form, but not changeable (no Save / Cancel buttons).
  final bool readOnly;
  const DocForm(this.t, {super.key, this.party, this.editId, this.fromId, this.fromOppId, this.fromSup, this.readOnly = false});
  @override
  State<DocForm> createState() => _DocFormState();
}

class _DocFormLine {
  String item;
  final TextEditingController qtyCtl;
  final TextEditingController rateCtl;
  final TextEditingController discCtl;
  final TextEditingController descCtl;
  final TextEditingController hsnCtl;
  final TextEditingController batchCtl;
  final TextEditingController acceptedCtl;
  final TextEditingController rejectedCtl;
  String uom;
  String taxCode;
  String wh;
  String delivDate;
  /// Purchase request: the supplier of this line ('' = not chosen yet).
  String sup;

  _DocFormLine({
    this.sup = '',
    required this.item,
    required double qty,
    required double rate,
    this.uom = 'Nos',
    this.taxCode = 'GST 18%',
    this.wh = 'WH-01',
    String disc = '0',
    String desc = '',
    String hsn = '',
    String batch = '',
    String accepted = '0',
    String rejected = '0',
    String? delivDate,
  })  : qtyCtl = TextEditingController(text: qty % 1 == 0 ? qty.toInt().toString() : qty.toString()),
        rateCtl = TextEditingController(text: rate.toStringAsFixed(2)),
        discCtl = TextEditingController(text: disc),
        descCtl = TextEditingController(text: desc),
        hsnCtl = TextEditingController(text: hsn),
        batchCtl = TextEditingController(text: batch),
        acceptedCtl = TextEditingController(text: accepted),
        rejectedCtl = TextEditingController(text: rejected),
        delivDate = delivDate ?? todayStr();

  void dispose() {
    qtyCtl.dispose();
    rateCtl.dispose();
    discCtl.dispose();
    descCtl.dispose();
    hsnCtl.dispose();
    batchCtl.dispose();
    acceptedCtl.dispose();
    rejectedCtl.dispose();
  }

  double get qty => double.tryParse(qtyCtl.text.trim()) ?? 0;
  double get rate => double.tryParse(rateCtl.text.trim()) ?? 0;
  double get disc => double.tryParse(discCtl.text.trim()) ?? 0;
  double get taxRate => S.taxRateOf(taxCode);

  double get gross => qty * rate;
  double get discAmt => gross * (disc / 100.0);
  double get taxable => gross - discAmt;
  double get taxAmt => taxable * (taxRate / 100.0);
  double get lineTotal => taxable + taxAmt;
}

class _DocFormState extends State<DocForm> {
  /// The SCM Manager sees every field, both when creating a document and when opening it later,
  /// so the saved document never shows fields that were not on the create form. Others see mandatory fields only.
  /// Purchase requests and purchase orders always show their mandatory fields only.
  bool get _opt => S.isManager && !const ['PR', 'PO'].contains(widget.t);
  late String party, wh, to, reason;
  late String salesPerson, territory, paymentTerms, currency, priceList, billingAddr, shippingAddr, taxRegNo, placeOfSupply, contactPerson;
  String billKey = '', shipKey = ''; // chosen customer address (by label)

  List<Address> get _addrs => S.dt[widget.t]!.party == 'C' && S.customers.any((c) => c.id == party) ? S.addressesOf(party) : const [];
  Address? _addr(String key) => _addrs.where((a) => a.label == key).firstOrNull;
  void _setBill(String key) {
    billKey = key;
    billingAddr = _addr(key)?.full ?? billingAddr;
  }
  void _setShip(String key) {
    shipKey = key;
    final a = _addr(key);
    if (a == null) return;
    shippingAddr = a.full;
    placeOfSupply = '${kStateCodes[a.state] ?? '37'} - ${a.state}';
  }
  final TextEditingController exRateCtl = TextEditingController(text: '1.0');
  /// Bumped when a number is typed (quantity, rate, discount, charges, exchange rate): only the line totals and the totals box
  /// listen to it, so typing never rebuilds the whole form.
  final ValueNotifier<int> _calc = ValueNotifier(0);

  /// The document totals from the lines as typed right now (recomputed whenever a quantity or rate changes).
  ({double subtotal, double totalLineDisc, double totalTax, double grandTotal, double roundOff}) _totals() {
    double subtotal = 0, totalLineDisc = 0, totalTax = 0;
    for (final l in lines) {
      subtotal += l.taxable;
      totalLineDisc += l.discAmt;
      totalTax += l.taxAmt;
    }
    double n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
    final rawGrand = (subtotal - n(headerDiscCtl)) + totalTax + n(freightCtl) + n(packingCtl) + n(otherChargesCtl);
    // ₹ totals round to the whole rupee; a foreign-currency total keeps its cents
    final grandTotal = currency == 'INR' ? rawGrand.roundToDouble() : (rawGrand * 100).roundToDouble() / 100;
    return (subtotal: subtotal, totalLineDisc: totalLineDisc, totalTax: totalTax, grandTotal: grandTotal, roundOff: grandTotal - rawGrand);
  }
  final TextEditingController headerDiscCtl = TextEditingController(text: '0');
  final TextEditingController freightCtl = TextEditingController(text: '0');
  final TextEditingController packingCtl = TextEditingController(text: '0');
  final TextEditingController otherChargesCtl = TextEditingController(text: '0');
  final TextEditingController remarksCtl = TextEditingController();
  final TextEditingController internalNotesCtl = TextEditingController();

  // Sales order only
  final TextEditingController orderDateCtl = TextEditingController(text: todayStr());
  final TextEditingController custPoNoCtl = TextEditingController();
  final TextEditingController custPoDateCtl = TextEditingController();
  final TextEditingController delivDateCtl = TextEditingController(text: addDays(todayStr(), 3));
  final TextEditingController advanceCtl = TextEditingController(text: '0');
  final TextEditingController tncCtl = TextEditingController();
  late String branch;
  String quotationRef = '';
  String shipMode = 'Road — own vehicle';
  String deliveryTerms = 'Door delivery';
  String tncTemplate = '';
  bool partialDelivery = true;

  /// The T&C templates saved on Company Settings (active ones), by name.
  static Map<String, String> get _tncTemplates => {for (final t in S.tcTemplates) if (t.status == 'Active') t.name: t.text};
  /// Template names that may be used on a document: purchase documents use Purchase / Both, the others Sales / Both.
  static List<String> _tncFor(bool purchase) => [for (final t in S.tcTemplates) if (t.status == 'Active' && t.applies != (purchase ? 'Sales' : 'Purchase')) t.name];

  // Extra fields for Quotation, Purchase Request, PO, Transfer and Adjustment
  final Map<String, TextEditingController> _x = {};
  final Map<String, String> _xs = {};
  TextEditingController _c(String k, [String def = '']) => _x.putIfAbsent(k, () => TextEditingController(text: def));
  Widget _sel(String label, String k, List<String> options, {bool req = false}) => _dd(label, _xs[k] ?? '', opts(options), (v) => _xs[k] = v, req: req);

  final List<_DocFormLine> lines = [];

  // ---- currency: rates on the form are in the document currency; the document is saved in ₹ (rate × exchange rate)
  Currency? get _cur => S.currencies.where((x) => x.code == currency).firstOrNull;
  /// ₹ for one unit of the document currency.
  double get _fx {
    if (currency == 'INR') return 1;
    final v = double.tryParse(exRateCtl.text.trim()) ?? 0;
    return v > 0 ? v : (_cur?.rate ?? 1);
  }

  String get _sym => currency == 'INR' ? '₹' : (_cur?.symbol ?? '$currency ');

  /// An amount in the document currency (₹ uses Indian grouping, others 1,234.56).
  String _m(num v) {
    if (currency == 'INR') return fmtINR(v);
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '${neg ? '-' : ''}$_sym$whole.${parts[1]}';
  }

  /// Picking another currency converts the typed rates at the exchange rates from Setup › Currencies.
  void _setCurrency(String v) {
    if (v == currency) return;
    final before = _fx;
    currency = v;
    exRateCtl.text = v == 'INR' ? '1.0' : (_cur?.rate ?? 1).toString();
    final now = _fx;
    for (final l in lines) {
      if (l.rateCtl.text.trim().isEmpty) continue;
      l.rateCtl.text = _rateText(l.rate * before / now);
    }
  }

  /// Rates in a foreign currency keep 4 decimals so converting back to ₹ does not lose paise.
  String _rateText(double v) => currency == 'INR' ? v.toStringAsFixed(2) : v.toStringAsFixed(4).replaceFirst(RegExp(r'0{1,2}$'), '');

  @override
  void initState() {
    super.initState();
    final pt = S.dt[widget.t]!.party;
    // the customer / supplier starts empty: it is chosen by hand, and then fills in the addresses, terms and tax details
    party = widget.party ?? '';
    wh = S.currentWh.id;
    // Terms & Conditions start from the default template for the document
    if (const ['QT', 'SO', 'PO'].contains(widget.t)) {
      final names = _tncFor(widget.t == 'PO');
      tncTemplate = names.isEmpty ? '' : names.contains(widget.t == 'PO' ? 'Standard purchase terms' : 'Standard sales terms') ? (widget.t == 'PO' ? 'Standard purchase terms' : 'Standard sales terms') : names.first;
      tncCtl.text = _tncTemplates[tncTemplate] ?? '';
    }
    // only what the system decides starts filled in: the number, dates, currency, and the warehouse / branch you are working in.
    // Everything a person decides starts empty.
    to = '';
    reason = '';
    branch = '${S.currentWh.city} Branch';

    salesPerson = '';
    territory = '';
    paymentTerms = '';
    currency = 'INR';
    priceList = '';
    billingAddr = '';
    shippingAddr = '';
    taxRegNo = '';
    placeOfSupply = '';
    contactPerson = '';

    if (party.isNotEmpty) {
      _autoFillParty(party);
    }
    _add();
    // a purchase request has no supplier at the top: the supplier it was opened for goes on the first line
    if (widget.t == 'PR' && party.isNotEmpty) lines.first.sup = party;
    final src = widget.editId ?? widget.fromId;
    final e = src == null ? null : S.doc(src);
    if (e != null) {
      party = e.party ?? party;
      if (party.isNotEmpty) _autoFillParty(party);
      final ab = _addrs.where((a) => a.full == e.billTo).firstOrNull, as = _addrs.where((a) => a.full == e.shipTo).firstOrNull;
      if (ab != null) _setBill(ab.label);
      if (as != null) _setShip(as.label);
      // addresses typed on the form (not one of the saved ones) come back as they were saved
      if (ab == null && e.billTo != null && e.billTo!.isNotEmpty) {
        billKey = '';
        billingAddr = e.billTo!;
      }
      if (as == null && e.shipTo != null && e.shipTo!.isNotEmpty) {
        shipKey = '';
        shippingAddr = e.shipTo!;
        if (e.shipState != null) placeOfSupply = '${kStateCodes[e.shipState] ?? '37'} - ${e.shipState}';
      }
      if (widget.editId == null) {
        // made from a request / quotation: same currency and exchange rate
        if (e.extra['v:currency'] != null) currency = e.extra['v:currency']!;
        if (e.extra['v:exrate'] != null) exRateCtl.text = e.extra['v:exrate']!;
      }
      if (widget.editId != null) {
        for (final x in e.extra.entries) {
          if (x.key.startsWith('v:')) {
            switch (x.key) {
              case 'v:currency': currency = x.value;
              case 'v:exrate': exRateCtl.text = x.value;
              case 'v:ship': shipMode = x.value;
              case 'v:terms': deliveryTerms = x.value;
              case 'v:pricelist': priceList = x.value;
              case 'v:payterms': paymentTerms = x.value;
            }
          } else if (x.key.startsWith('t:')) {
            _c(x.key.replaceFirst('t:', '')).text = x.value;
          } else {
            _xs[x.key] = x.value;
          }
        }
      }
      wh = e.wh;
      to = e.to ?? to;
      reason = e.reason ?? reason;
      if (widget.t == 'SO' && e.custPo != null) custPoNoCtl.text = e.custPo!;
      if (widget.t == 'TR') {
        if (e.vehicle != null) _xs['tr_vehicle'] = e.vehicle!;
        if (e.eta != null) _c('arrival', e.eta!).text = e.eta!;
        if (e.transferredBy != null) _xs['tr_by'] = e.transferredBy!;
        if (e.receivedBy != null) _c('tr_recv').text = e.receivedBy!;
      }
      if (widget.t == 'ADJ' && e.approvedBy != null) _xs['approver'] = e.approvedBy!;
      if (widget.t == 'PR') {
        // a draft request keeps its justification and required-by date
        if ((e.purpose ?? '').isNotEmpty) _c('purpose').text = e.purpose!;
        if (e.need != null) _c('req_by', e.need!).text = e.need!;
        if (e.requester != null) _xs['req_by_person'] = e.requester!;
        if (e.dept != null) _xs['dept'] = e.dept!;
      }
      // a sales order made from (or saved against) a quotation shows it as its Quotation Ref.
      if (widget.t == 'SO') {
        final q = widget.fromId ?? (e.ref != null && e.ref!.startsWith('QT-') ? e.ref : null);
        if (q != null) quotationRef = q;
      }
      if (widget.t == 'PO') {
        final pr = widget.fromId ?? (e.ref != null && e.ref!.startsWith('PR-') ? e.ref : null);
        if (pr != null) _xs['pr_ref'] = pr;
      }
      for (final l in lines) {
        l.dispose();
      }
      // a purchase order from a request takes the lines of one supplier of that request
      final src = widget.t == 'PO' && e.type == 'PR' && widget.fromSup != null ? e.lines.where((l) => S.lineSup(e, l) == widget.fromSup).toList() : e.lines;
      lines
        ..clear()
        ..addAll((src.isEmpty ? e.lines : src).map((l) {
          final p = S.items.firstWhere((x) => x.id == l.item, orElse: () => S.items.first);
          return _DocFormLine(
            sup: widget.t == 'PR' ? (l.sup.isNotEmpty ? l.sup : (e.party ?? '')) : '',
            item: l.item,
            qty: l.qty.abs().toDouble(),
            rate: l.rate,
            uom: l.item.isEmpty ? 'Nos' : p.uom,
            taxCode: S.taxNameFor(l.item.isEmpty ? 18 : p.gst),
            wh: e.wh,
            batch: l.batch,
            desc: l.desc ?? (l.item.isEmpty ? '' : p.name),
            hsn: l.item.isEmpty ? '' : p.hsn,
          );
        }));
      // a document in a foreign currency shows its rates in that currency again (saved in ₹)
      if (currency != 'INR') {
        for (final l in lines) {
          l.rateCtl.text = _rateText(l.rate / _fx);
        }
      }
      if (widget.t == 'ADJ' && e.lines.any((l) => l.qty < 0)) _xs['adj_type'] = 'Decrease';
      if (widget.t == 'ADJ' && e.lines.every((l) => l.qty > 0)) _xs['adj_type'] = 'Increase';
    } else if (widget.fromOppId != null) {
      // quotation from an opportunity: customer, warehouse and products come from it, rates from the pricing rules
      final o = S.opps.where((x) => x.id == widget.fromOppId).firstOrNull;
      if (o != null) {
        party = o.party;
        _autoFillParty(party);
        wh = S.terr(o.party).wh;
        // the references it came from are filled in
        _xs['opp_ref'] = o.id;
        if (o.lead != null) _xs['lead_ref'] = o.lead!;
        for (final l in lines) {
          l.dispose();
        }
        lines
          ..clear()
          ..addAll(o.lines.map((ol) {
            final p = S.items.firstWhere((x) => x.id == ol.item, orElse: () => S.items.first);
            return _DocFormLine(
              item: ol.item,
              qty: ol.qty.toDouble(),
              rate: S.salesPrice(o.party, ol.item, ol.qty).rate,
              uom: p.uom,
              taxCode: S.taxNameFor(p.gst),
              wh: wh,
              desc: p.name,
              hsn: p.hsn,
            );
          }));
      }
    }
  }

  void _autoFillParty(String pId) {
    final pt = S.dt[widget.t]!.party;
    if (pt == 'C' && S.customers.any((c) => c.id == pId)) {
      final c = S.cust(pId);
      final terr = S.terrOf[c.id] ?? '';
      territory = S.territories.where((t) => t.id == terr || t.name == terr).firstOrNull?.name ?? '';
      final sp = S.salesPersons.where((x) => x.terr == terr && terr.isNotEmpty).firstOrNull;
      if (sp != null) salesPerson = sp.name; // the customer's own sales person; otherwise it stays as chosen
      paymentTerms = 'Net ${c.terms} days';
      priceList = S.priceLists.where((pl) => pl.group == c.group).firstOrNull?.name ?? '';
      billingAddr = '${c.name}, ${c.city}, ${c.state}';
      shippingAddr = '${c.name}, ${c.city}, ${c.state}';
      taxRegNo = c.gstin;
      placeOfSupply = '${kStateCodes[c.state] ?? '37'} - ${c.state}';
      final ads = S.addressesOf(c.id);
      _setBill((ads.where((a) => a.billing).firstOrNull ?? ads.first).label);
      // the shipping address typed on the customer form is used first, then any shipping address
      _setShip((ads.where((a) => a.label == 'Delivery address').firstOrNull ?? ads.where((a) => a.shipping).firstOrNull ?? ads.first).label);
      contactPerson = c.contact;
    } else if (pt == 'S' && S.suppliers.any((s) => s.id == pId)) {
      final s = S.sup(pId);
      paymentTerms = 'Net ${s.terms} days';
      billingAddr = '${s.name}, ${s.city}, ${s.state}';
      shippingAddr = '${s.name}, ${s.city}, ${s.state}';
      taxRegNo = s.gstin;
      contactPerson = s.contact;
    }
  }

  /// A new line is empty: the item is chosen, and the quantity and rate come from the person (the rate follows the item).
  void _add() {
    final l = _DocFormLine(item: '', qty: 0, rate: 0, uom: 'Nos', taxCode: 'GST 18%', wh: wh, delivDate: widget.t == 'SO' ? delivDateCtl.text : null);
    l.qtyCtl.text = '';
    l.rateCtl.text = '';
    lines.add(l);
  }

  /// The line items, every field visible without sliding sideways: a table filling the form's width on a laptop,
  /// one card per line (fields wrapped under each other) where the screen is too narrow for the table.
  Widget _lineItems({required bool pr, required bool po, required bool tr, required bool adj, required bool lx, required bool noPrice}) {
    const head = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.soft);
    const small = TextStyle(fontSize: 12.5);
    // text boxes as tall as the dropdowns next to them
    const box = EdgeInsets.symmetric(horizontal: 10, vertical: 15);
    Widget calc(Widget Function() f) => ValueListenableBuilder<int>(valueListenable: _calc, builder: (_, __, ___) => f());
    Widget amount(double Function(int) f, int i) => calc(() => Text(_m(f(i)), style: const TextStyle(fontSize: 12)));
    final tracked = lines.any((l) => l.item.isNotEmpty && S.items.any((p) => p.id == l.item && p.track != 'None'));
    void pickItem(int i, String v) => setState(() {
          lines[i].item = v;
          if (v.isEmpty) return; // description-only line
          final itemObj = S.item(v);
          lines[i].descCtl.text = itemObj.name;
          lines[i].hsnCtl.text = itemObj.hsn;
          lines[i].uom = itemObj.uom;
          lines[i].rateCtl.text = _rateText((widget.t.startsWith('P') || const ['GRN', 'ADJ', 'TR'].contains(widget.t) ? itemObj.cost : itemObj.price) / _fx);
          lines[i].taxCode = S.taxNameFor(itemObj.gst);
          // a request line starts with the item's usual supplier (it can be changed)
          if (pr && lines[i].sup.isEmpty && S.suppliers.any((x) => x.id == itemObj.sup && x.status != 'Inactive')) {
            lines[i].sup = itemObj.sup;
            lines[i].rateCtl.text = _rateText(S.purchasePrice(itemObj.sup, v, lines[i].qty < 1 ? 1 : lines[i].qty.toInt()).rate / _fx);
          }
        });
    Widget num(TextEditingController c) => TextField(controller: c, keyboardType: TextInputType.number, style: small, decoration: const InputDecoration(contentPadding: box), onChanged: (_) => _calc.value++);

    // main row: (heading, narrowest width, share of the spare width, right-aligned, cell)
    final cols = <(String, double, double, bool, Widget Function(int))>[
      ('Item', 140, 2.2, false, (i) => ItemSearchField(value: lines[i].item, wh: lines[i].wh, allowEmpty: pr || po, onChanged: (v) => pickItem(i, v))),
      if (pr)
        ('Supplier', 130, 2.6, false, (i) => ProtoSelect(
              placeholder: 'Select supplier',
              value: lines[i].sup,
              options: [
                const SelOpt('', 'Not decided'),
                for (final x in S.suppliers.where((x) => x.status != 'Inactive' || x.id == lines[i].sup)) SelOpt(x.id, x.name),
              ],
              onChanged: (v) => setState(() => lines[i].sup = v))),
      // wraps onto a second line so a long description is never cut off
      ('Description', 120, 1.2, false, (i) => TextField(controller: lines[i].descCtl, minLines: 1, maxLines: 2, style: small, decoration: const InputDecoration(hintText: 'What is needed', contentPadding: box))),
      ('HSN / SAC', 64, .8, false, (i) => TextField(controller: lines[i].hsnCtl, style: small, decoration: const InputDecoration(hintText: 'Code', contentPadding: box))),
      ('Qty', 52, .7, false, (i) => num(lines[i].qtyCtl)),
      ('UOM', 72, .8, false, (i) => ProtoSelect(value: lines[i].uom, options: S.uoms.map((u) => SelOpt(u.code, u.code)).toList(), onChanged: (v) => setState(() => lines[i].uom = v))),
      if (!noPrice) ('Rate ($_sym)', 68, .9, false, (i) => num(lines[i].rateCtl)),
      if (!noPrice) ('Tax Code', 106, 1, false, (i) => ProtoSelect(value: lines[i].taxCode, options: S.taxNames.map((x) => SelOpt(x, x)).toList(), onChanged: (v) => setState(() => lines[i].taxCode = v))),
      // the star only when a line holds a batch- or serial-tracked item
      if (tr || adj)
        ('Batch / Serial No.${tracked ? ' *' : ''}', 130, 1.6, false, (i) {
          final track = lines[i].item.isEmpty ? 'None' : S.item(lines[i].item).track;
          return TextField(
            controller: lines[i].batchCtl,
            enabled: track != 'None',
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(contentPadding: box, hintText: track == 'Batch' ? 'Batch no. *' : track == 'Serial' ? 'Serial no(s). *' : 'Not tracked'),
          );
        }),
      if (!noPrice) ('Line Total', 72, .3, true, (i) => calc(() => Text(_m(lines[i].lineTotal), style: tsB))),
    ];
    // the manager's extra line fields: a second row under each line, so the main row never slides sideways
    final more = <(String, double, Widget Function(int))>[
      if (_opt && !noPrice) ('Disc %', 70, (i) => num(lines[i].discCtl)),
      if (lx && _opt) ...[
        ('Warehouse', 110, (i) => ProtoSelect(value: lines[i].wh, options: S.warehouses.map((w) => SelOpt(w.id, w.code)).toList(), onChanged: (v) => setState(() => lines[i].wh = v))),
        ((pr || po) ? 'Required Date' : 'Delivery Date', 130, (i) => InkWell(
              onTap: () async {
                final d = await _pickDate(lines[i].delivDate);
                if (d != null) setState(() => lines[i].delivDate = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(R.sm), border: Border.all(color: C.border)),
                child: Row(children: [
                  Expanded(child: Text(lines[i].delivDate, style: const TextStyle(fontSize: 12))),
                  const Icon(Icons.calendar_today_outlined, size: 14, color: C.faint),
                ]),
              ),
            )),
        ('Gross', 90, (i) => amount((i) => lines[i].gross, i)),
        ('Disc Amt', 90, (i) => amount((i) => lines[i].discAmt, i)),
      ],
      if (_opt && !noPrice) ('Taxable', 90, (i) => amount((i) => lines[i].taxable, i)),
      if (lx && _opt) ('Tax Amt', 90, (i) => amount((i) => lines[i].taxAmt, i)),
    ];
    Widget remove(int i) => IconButton(
          tooltip: 'Remove line',
          icon: const Icon(Icons.close, size: 16, color: C.faint),
          onPressed: lines.length == 1 ? null : () => setState(() => lines.removeAt(i).dispose()),
        );
    Widget labelled(String label, Widget field) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(label, style: head)),
          field,
        ]);

    return LayoutBuilder(builder: (ctx, c) {
      const gap = 8.0, del = 32.0;
      final need = cols.fold<double>(0, (a, x) => a + x.$2) + gap * cols.length + del;
      if (c.maxWidth >= need) {
        // table: each column gets its narrowest width plus its share of the room left
        final spare = c.maxWidth - need;
        final shares = cols.fold<double>(0, (a, x) => a + x.$3);
        final w = [for (final x in cols) x.$2 + spare * x.$3 / shares];
        Widget row(List<Widget> cells, Widget? last) => Row(children: [
              for (var k = 0; k < cols.length; k++)
                Padding(
                  padding: const EdgeInsets.only(right: gap),
                  child: SizedBox(width: w[k], child: cols[k].$4 ? Align(alignment: Alignment.centerRight, child: cells[k]) : cells[k]),
                ),
              SizedBox(width: del, child: last),
            ]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(bottom: 10), child: row([for (final x in cols) Text(x.$1, style: head)], null)),
          const Divider(height: 1),
          for (var i = 0; i < lines.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                row([for (final x in cols) x.$5(i)], remove(i)),
                if (more.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(spacing: 14, runSpacing: 10, children: [for (final x in more) SizedBox(width: x.$2, child: labelled(x.$1, x.$3(i)))]),
                  ),
              ]),
            ),
            const Divider(height: 1),
          ],
        ]);
      }
      // narrow screen: one card per line, every field with its heading, wrapped under each other
      final inner = c.maxWidth - 26;
      final per = inner >= 340 ? 2 : 1;
      final fw = (inner - 12 * (per - 1)) / per;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < lines.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(R.r), border: Border.all(color: C.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Expanded(child: Text('Line ${i + 1}', style: tsB)), remove(i)]),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final x in cols) SizedBox(width: x.$1 == 'Item' || x.$1 == 'Description' ? inner : fw, child: labelled(x.$1, x.$5(i))),
                for (final x in more) SizedBox(width: fw, child: labelled(x.$1, x.$3(i))),
              ]),
            ]),
          ),
      ]);
    });
  }

  /// Picking a quotation copies its lines into the order.
  void _applyQuotation(String id) {
    quotationRef = id;
    final q = id.isEmpty ? null : S.doc(id);
    if (q == null) return;
    final old = [...lines];
    lines
      ..clear()
      ..addAll(q.lines.map((l) {
        final p = S.item(l.item);
        return _DocFormLine(item: l.item, qty: l.qty.toDouble(), rate: l.rate, uom: p.uom, taxCode: S.taxNameFor(p.gst), wh: wh, delivDate: delivDateCtl.text, desc: l.desc ?? p.name, hsn: p.hsn);
      }));
    if (lines.isEmpty) _add();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final l in old) {
        l.dispose();
      }
    });
  }

  Future<String?> _pickDate(String current) async {
    final d = await pickDateClean(context, DateTime.tryParse(current) ?? DateTime.now());
    return d == null ? null : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Widget _label(String label, {bool req = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: label),
          if (req) const TextSpan(text: ' *', style: TextStyle(color: C.red)),
        ]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft)),
      );

  Widget _text(String label, TextEditingController ctl, {bool req = false, String? hint, bool number = false, int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, req: req),
        TextField(
          controller: ctl,
          // multi-line boxes keep line breaks and grow as you type
          minLines: maxLines > 1 ? maxLines : null,
          maxLines: maxLines > 1 ? null : 1,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(hintText: hint),
        ),
      ]);

  Widget _date(String label, TextEditingController ctl, {bool req = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, req: req),
        TextField(
          controller: ctl,
          readOnly: true,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(hintText: 'Select date', suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)),
          onTap: () async {
            final d = await _pickDate(ctl.text);
            if (d != null) setState(() => ctl.text = d);
          },
        ),
      ]);

  Widget _readOnly(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        InputDecorator(decoration: const InputDecoration(), child: Text(value, style: const TextStyle(fontSize: 13, color: C.soft))),
      ]);

  @override
  void dispose() {
    for (final l in lines) {
      l.dispose();
    }
    exRateCtl.dispose();
    _calc.dispose();
    headerDiscCtl.dispose();
    freightCtl.dispose();
    packingCtl.dispose();
    otherChargesCtl.dispose();
    remarksCtl.dispose();
    internalNotesCtl.dispose();
    orderDateCtl.dispose();
    custPoNoCtl.dispose();
    custPoDateCtl.dispose();
    delivDateCtl.dispose();
    advanceCtl.dispose();
    tncCtl.dispose();
    for (final c in _x.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _dd(String label, String value, List<Opt> o, void Function(String) f, {bool req = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: label),
            if (req) const TextSpan(text: ' *', style: TextStyle(color: C.red)),
          ]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft)),
        ),
        ProtoSelect(placeholder: 'Select ${label.toLowerCase()}', value: value, options: o.map((x) => SelOpt(x.value, x.label)).toList(), onChanged: (v) => setState(() => f(v))),
      ]);

  String get _note => const {
        'QT': 'Price comes from the trade agreement, then customer’s price list, then item price.',
        'SO': 'On save: price lookup → credit check → approval check → stock reservation.',
        'PR': 'The request is saved as a draft. Open it and press Submit to send it for approval.',
        'PO': 'Price from purchase trade agreement or standard cost. POs above ₹5,00,000 need approval.',
        'TR': 'Dispatch reduces source stock; receipt adds it at destination.',
        'ADJ': 'Adjustments above ₹10,000 in value need approval; smaller ones post straight away.',
      }[widget.t] ??
      '';

  void _save({bool submit = false}) {
    if (S.dt[widget.t]!.party == 'S' && widget.t != 'PR' && party.isEmpty) {
      toast('Select the Supplier');
      return;
    }
    // what a person decides must be chosen: nothing is filled in behind their back
    final unchosen = widget.editId != null ? <String>[] : [
      if (S.dt[widget.t]!.party == 'C' && party.isEmpty) 'Customer',
      if (S.dt[widget.t]!.party == 'C' && salesPerson.isEmpty) 'Sales Person',
      if (const ['QT', 'SO', 'PO'].contains(widget.t) && paymentTerms.isEmpty) 'Payment Terms',
      if (widget.t == 'TR' && to.isEmpty) 'To Warehouse',
      if (widget.t == 'ADJ' && reason.isEmpty) 'Reason',
      if (widget.t == 'ADJ' && (_xs['adj_type'] ?? '').isEmpty) 'Adjustment Type',
    ];
    if (unchosen.isNotEmpty) {
      toast('Please fill: ${unchosen.join(', ')}');
      return;
    }
    if (const ['QT', 'SO', 'PO'].contains(widget.t) && tncCtl.text.trim().isEmpty) {
      toast('Please fill: Terms & Conditions');
      return;
    }
    if (widget.t == 'SO') {
      final missing = [
        if (custPoNoCtl.text.trim().isEmpty) 'Customer PO No.',
        if (billingAddr.trim().isEmpty) 'Billing Address',
        if (shippingAddr.trim().isEmpty) 'Shipping Address',
      ];
      if (missing.isNotEmpty) {
        toast('Please fill: ${missing.join(', ')}');
        return;
      }
      if (delivDateCtl.text.compareTo(orderDateCtl.text) < 0) {
        toast('Delivery Date cannot be before Order Date');
        return;
      }
      if ((double.tryParse(advanceCtl.text.trim()) ?? 0) < 0) {
        toast('Advance Amount cannot be negative');
        return;
      }
    }
    final docDate = _c('doc_date', todayStr()).text;
    if (widget.t == 'QT') {
      if (contactPerson.trim().isEmpty) {
        toast('Please fill: Contact Person');
        return;
      }
      if (_c('valid', addDays(todayStr(), 30)).text.compareTo(docDate) < 0) {
        toast('Valid Until cannot be before Quotation Date');
        return;
      }
    }
    if (widget.t == 'PR') {
      // nothing on a purchase request is mandatory: only the dates must make sense
      if (_c('req_by', addDays(todayStr(), 7)).text.compareTo(docDate) < 0) {
        toast('Required By Date cannot be before Request Date');
        return;
      }
    }
    if (widget.t == 'PO' && _c('exp_del', addDays(todayStr(), 5)).text.compareTo(docDate) < 0) {
      toast('Expected Delivery Date cannot be before PO Date');
      return;
    }
    if (widget.t == 'TR' || widget.t == 'ADJ') {
      for (final l in lines.where((l) => l.item.isNotEmpty)) {
        final p = S.item(l.item);
        if (p.track != 'None' && l.qty != 0 && l.batchCtl.text.trim().isEmpty) {
          toast('Enter the ${p.track == 'Batch' ? 'Batch No.' : 'Serial No(s).'} for ${p.name}');
          return;
        }
      }
    }
    var rows = <({String item, int qty})>[];
    final rates = <double>[]; // the rates shown on the form are the rates saved
    final batchNos = <String>[]; // batch / serial numbers typed for transfers and adjustments
    final descs = <String>[];
    final sups = <String>[]; // purchase request: each line's supplier
    final freeOk = widget.t == 'PR' || widget.t == 'PO';
    for (final l in lines) {
      final q = l.qty.toInt();
      if (q <= 0) continue;
      final desc = l.descCtl.text.trim();
      if (l.item.isEmpty && desc.isEmpty) {
        toast('Each line needs an item or a description');
        return;
      }
      if (l.item.isEmpty && !freeOk) {
        toast('Choose an item for "$desc"');
        return;
      }
      if (l.item.isEmpty) {
        final s = widget.t == 'PR' ? l.sup : party;
        l.item = S.nonStockItem(desc, l.hsnCtl.text.trim(), l.uom, l.taxRate.round(), l.rate * _fx, s.isEmpty ? null : s);
      }
      sups.add(l.sup);
      rows.add((item: l.item, qty: q));
      batchNos.add(widget.t == 'TR' || widget.t == 'ADJ' ? l.batchCtl.text.trim() : '');
      rates.add(l.rate * _fx); // saved in ₹
      descs.add(desc.isEmpty ? S.item(l.item).name : desc);
    }
    if (rows.isEmpty) {
      toast('Add at least one line with quantity > 0');
      return;
    }
    if (widget.t == 'ADJ') {
      // a Valuation Rate typed on the form is used for every line instead of the standard cost
      final vr = double.tryParse(_c('val_rate').text.trim());
      if (vr != null && vr > 0) {
        for (var i = 0; i < rates.length; i++) {
          rates[i] = vr;
        }
      }
    }
    if (widget.t == 'TR' && to == wh) {
      toast('From Warehouse and To Warehouse must differ');
      return;
    }
    final decrease = widget.t == 'ADJ' && (_xs['adj_type'] ?? 'Decrease') == 'Decrease';
    if (widget.t == 'TR' || decrease) {
      for (final r in rows) {
        final av = S.avail(wh, r.item);
        if (r.qty > av) {
          toast('${S.item(r.item).name}: only $av available in ${S.wh(wh).code} — cannot ${widget.t == 'TR' ? 'transfer' : 'decrease'} ${r.qty}');
          return;
        }
      }
      // the batch / serial numbers must really be in the warehouse the stock leaves from
      for (var i = 0; i < rows.length; i++) {
        if (batchNos[i].isEmpty) continue;
        final problem = S.pickProblem(wh, rows[i].item, rows[i].qty, batchNos[i]);
        if (problem != null) {
          toast(problem);
          return;
        }
      }
    }
    if (decrease) rows = [for (final r in rows) (item: r.item, qty: -r.qty)];
    if (widget.t != 'ADJ' && rows.any((r) => r.qty <= 0)) {
      toast('Quantities must be positive');
      return;
    }
    final pt = S.dt[widget.t]!.party;
    void keepDescriptions(Doc d) {
      for (var i = 0; i < d.lines.length && i < descs.length; i++) {
        d.lines[i].desc = descs[i];
      }
      if (widget.t == 'SO') d.custPo = custPoNoCtl.text.trim();
      d.extra = {
        ..._xs,
        for (final x in _x.entries) 't:${x.key}': x.value.text,
        'v:currency': currency, 'v:exrate': exRateCtl.text, 'v:ship': shipMode, 'v:terms': deliveryTerms, 'v:pricelist': priceList, 'v:payterms': paymentTerms,
      };
      if (widget.t == 'TR') {
        final veh = _xs['tr_vehicle'] ?? '—';
        if (veh != '—') d.vehicle = veh;
        d.eta = _c('arrival', addDays(todayStr(), 2)).text;
        d.transferredBy = _xs['tr_by'];
        d.receivedBy = _c('tr_recv').text.trim();
      }
      if (widget.t == 'ADJ') {
        final ap = _xs['approver'] ?? '—';
        d.approvedBy = ap == '—' ? null : ap;
      }
      if (widget.t == 'PR') {
        d.purpose = _c('purpose').text.trim();
        d.need = _c('req_by', addDays(todayStr(), 7)).text;
        d.requester = _xs['req_by_person'] ?? S.user?.name ?? demoUsers.first.name;
        d.dept = (_xs['dept'] ?? '').isEmpty ? null : _xs['dept'];
        // each line keeps its own supplier; the request's supplier is set only when every line has the same one
        for (var i = 0; i < d.lines.length && i < sups.length; i++) {
          d.lines[i].sup = sups[i];
        }
        final distinct = sups.toSet();
        d.party = distinct.length == 1 && distinct.first.isNotEmpty ? distinct.first : null;
      }
    }
    void keepAddresses(Doc d) {
      final b = _addr(billKey), sh = _addr(shipKey);
      final isCust = S.dt[widget.t]!.party == 'C' && S.customers.any((c) => c.id == party);
      if (!isCust && b == null && sh == null) return;
      // a saved address, or the address typed on the form; the place of supply decides CGST+SGST or IGST
      d.billTo = b?.full ?? billingAddr;
      d.shipTo = sh?.full ?? (shippingAddr.trim().isEmpty ? d.billTo : shippingAddr);
      final posState = placeOfSupply.contains(' - ') ? placeOfSupply.split(' - ').last.trim() : '';
      d.shipState = sh?.state ?? (posState.isNotEmpty ? posState : (b?.state ?? S.cust(party).state));
      d.amount = S.calc(d).total;
    }
    if (widget.editId != null) {
      final res = S.updateDocForm(widget.editId!, pt == 'W' ? null : party, wh, widget.t == 'TR' ? to : null, widget.t == 'ADJ' ? reason : null, rows, rates: rates, batchNos: batchNos);
      keepAddresses(S.doc(widget.editId!)!);
      keepDescriptions(S.doc(widget.editId!)!);
      after(submit ? S.prSubmit(widget.editId!) : (widget.t == 'PR' ? Res(res.msg) : res));
      return;
    }
    final d = S.saveDocForm(widget.t, pt == 'W' ? null : party, wh, widget.t == 'TR' ? to : null, widget.t == 'ADJ' ? reason : null, rows, rates: rates, batchNos: batchNos);
    keepAddresses(d);
    keepDescriptions(d);
    if (widget.fromOppId != null && widget.t == 'QT') {
      // quotation made from an opportunity: link both, then show the Draft in the Quotations list
      final res = S.oppQuoted(widget.fromOppId!, d.id);
      closeAll();
      S.go(S.dt['QT']!.view);
      S.refresh();
      toast(res.msg);
      openDoc(d.id); // the new Draft opens as a form page, with Edit and Send to customer
      return;
    }
    if (widget.fromId != null && widget.t == 'SO') {
      // sales order made from an accepted quotation: credit and approval checks have run, show it in Sales Orders
      final res = S.qtOrdered(widget.fromId!, d.id);
      closeAll();
      S.go(S.dt['SO']!.view);
      S.refresh();
      toast(res.msg);
      openDoc(d.id); // the new order opens as a form page, with Edit while it can still be changed
      return;
    }
    if (widget.fromId != null) {
      // order made from a request: link both, then show it in the Purchase Orders list
      final res = S.prOrdered(widget.fromId!, d.id, forSup: widget.fromSup);
      closeAll();
      S.go(S.dt['PO']!.view);
      S.refresh();
      toast(res.msg);
      return;
    }
    after(Res('${d.id} saved · ${d.status}', widget.t == 'PR' ? null : d.id));
  }

  @override
  Widget build(BuildContext context) {
    final pt = S.dt[widget.t]!.party;
    final so = widget.t == 'SO';
    final qt = widget.t == 'QT', pr = widget.t == 'PR', po = widget.t == 'PO', tr = widget.t == 'TR', adj = widget.t == 'ADJ';
    final lx = so || qt || pr || po; // sales & purchase documents get the full line-item columns
    final noPrice = tr || adj; // stock documents carry quantities only
    const dateLabel = {'QT': 'Quotation Date', 'PR': 'Request Date', 'PO': 'PO Date', 'TR': 'Transfer Date', 'ADJ': 'Adjustment Date'};
    final branchOpts = S.branchNames.map((b) => Opt(b, b)).toList();
    // our staff who log in (same people as Requested By)
    final people = [for (final u in staffUsers) u.name];
    final whOpts = S.warehouses.map((w) => Opt(w.id, '${w.code} — ${w.city}')).toList();


    return LayoutBuilder(builder: (ctx, c) {
      final two = c.maxWidth >= 480;
      final half = two ? (c.maxWidth - 14) / 2 : c.maxWidth;
      final editing = widget.editId == null ? null : S.doc(widget.editId!);
      final kids = <Widget>[
        FormStatusBar(
          editing?.status ?? 'Draft',
          editing != null
              ? 'Current status of ${editing.id}. It changes automatically as the document moves forward.'
              : const {
                    'SO': 'On save the credit check runs: the order becomes Confirmed, or Pending Approval / On Hold.',
                    'QT': 'Stays Draft until it is sent to the customer.',
                    'PR': 'Saved as Draft. Nothing is sent until you press Submit on the request.',
                    'PO': 'On save it is sent to the supplier, or goes for approval above the limit.',
                    'TR': 'On save it becomes Requested and waits for dispatch.',
                    'ADJ': 'On save it is posted, or goes for approval above the limit.',
                  }[widget.t] ??
                  'Set automatically on save.',
        ),
        // rejected or cancelled: why, shown right under the status
        if (editing != null && editing.type == 'PO' && editing.extra['ack'] != null)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: NoteBox(Tone.green, 'check', 'Supplier acknowledged the order on ${editing.extra['ack']}.', 'Confirmed through the Supplier Portal by ${editing.extra['ack_by'] ?? S.partyName(editing)}.')),
      if (editing != null && editing.status == 'Rejected' && (editing.reason ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NoteBox(Tone.red, 'x', 'Rejection Reason:', editing.reason!.trim()),
          ),
        if (editing != null && editing.status == 'Cancelled' && (editing.note ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NoteBox(Tone.red, 'x', 'Cancellation Reason:', editing.note!.trim()),
          ),
        Padding(
          key: const ValueKey('ro-hide-info'),
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(color: Color(0x0F3B82F6), borderRadius: BorderRadius.all(Radius.circular(8))),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: C.blue600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(pr ? 'Fill in what you need — nothing on a request is mandatory. Choose the supplier on each line: items from different suppliers become separate purchase orders. The request number is generated automatically.' : _opt ? 'Fields marked * are mandatory; the rest are optional. The document number is generated automatically from Setup > Number Series.' : 'Only mandatory fields (*) are shown. The document number is generated automatically from Setup > Number Series.',
                    style: const TextStyle(fontSize: 11.5, color: C.soft, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
        ),
        const SectionTitle('Document', first: true),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: half, child: _readOnly('${docTitle(widget.t)} No.', widget.editId ?? '${S.dt[widget.t]!.prefix}${(S.dt[widget.t]!.seq + 1).toString().padLeft(4, '0')}')),
          if (widget.fromId != null) SizedBox(width: half, child: _readOnly(widget.t == 'SO' ? 'Against Quotation' : 'Against Request', widget.fromId!)),
          if (so) SizedBox(width: half, child: _date('Order Date', orderDateCtl, req: true)),
          if (dateLabel.containsKey(widget.t)) SizedBox(width: half, child: _date(dateLabel[widget.t]!, _c('doc_date', todayStr()), req: !pr)),
          if (pt == 'C') SizedBox(width: half, child: _dd('Customer', party, S.customers.where((x) => x.status != 'Inactive' || x.id == party).map((x) => Opt(x.id, x.name)).toList(), (v) {
            party = v;
            quotationRef = '';
            _autoFillParty(v);
          }, req: true)),
          // a purchase request chooses the supplier on each line (different items can come from different suppliers)
          if (pt == 'S' && !pr)
            SizedBox(
                width: half,
                child: _dd('Supplier', party, [
                  const Opt('', 'Select supplier'),
                  ...S.suppliers.where((x) => x.status != 'Inactive' || x.id == party).map((x) => Opt(x.id, x.name)),
                ], (v) {
                  party = v;
                  if (v.isNotEmpty) _autoFillParty(v);
                })),
          SizedBox(width: half, child: _dd(widget.t == 'TR' ? 'From Warehouse' : (pr || po) ? 'Deliver To Warehouse' : 'Warehouse', wh, whOpts, (v) => wh = v, req: !pr)),
          if (widget.t == 'TR') SizedBox(width: half, child: _dd('To Warehouse', to, whOpts, (v) => to = v, req: true)),
          if (pt == 'C') SizedBox(width: half, child: _dd('Sales Person', salesPerson, S.salesPersons.where((x) => x.status != 'Inactive' || x.name == salesPerson).map((sp) => Opt(sp.name, sp.name)).toList(), (v) => salesPerson = v, req: true)),
          if (so || qt || po || pr) SizedBox(width: half, child: _dd('Currency', currency, opts(S.currencyCodes), (v) => setState(() => _setCurrency(v)), req: !pr)),
          // only a foreign currency needs an exchange rate (₹ per 1 unit; rates stay in that currency, the ₹ value follows).
          // INR needs none, so no greyed-out field is shown.
          if ((so || qt || po || pr) && currency != 'INR')
            SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Exchange Rate (₹ per 1 $currency)', req: !pr),
              TextField(
                controller: exRateCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(hintText: 'e.g. ${(_cur?.rate ?? 1)}', contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13)),
                onChanged: (_) => _calc.value++,
              ),
            ])),
          if (widget.t == 'ADJ') SizedBox(width: half, child: _dd('Reason', reason, opts(['Damage', 'Expiry write-off', 'Found stock', 'Material issue']), (v) => reason = v, req: true)),
          if (qt) ...[
            SizedBox(width: half, child: _date('Valid Until', _c('valid', addDays(todayStr(), 30)), req: true)),
            SizedBox(width: half, child: _dd('Branch', branch, branchOpts, (v) => branch = v, req: true)),
            if (_opt) SizedBox(width: half, child: _text('Revision No.', _c('rev', '0'))),
            if (_opt) SizedBox(width: half, child: _sel('Quotation Type', 'qt_type', ['Standard', 'Budgetary', 'Revised', 'Tender'])),
          ],
          if (pr) ...[
            // the people who use the system, with their role so the right person is picked
            SizedBox(
                width: half,
                child: _dd('Requested By', _xs['req_by_person'] ?? S.user?.name ?? demoUsers.first.name, [
                  for (final u in staffUsers) Opt(u.name, '${u.name} — ${roleOfName(u.name)}'),
                  // older requests raised by someone who is not a user keep their name
                  if (_xs['req_by_person'] != null && !staffUsers.any((u) => u.name == _xs['req_by_person'])) Opt(_xs['req_by_person']!, _xs['req_by_person']!),
                ], (v) => _xs['req_by_person'] = v)),
            SizedBox(width: half, child: _sel('Department', 'dept', ['Stores', 'Production', 'Maintenance', 'Admin', 'Sales'])),
            SizedBox(width: half, child: _date('Required By Date', _c('req_by', addDays(todayStr(), 7)))),
            if (_opt) SizedBox(width: half, child: _dd('Branch', branch, branchOpts, (v) => branch = v)),
            if (_opt) SizedBox(width: half, child: _sel('Priority', 'priority', ['Normal', 'Urgent', 'Low'])),
          ],
          if (po) ...[
            SizedBox(width: half, child: _dd('Branch', branch, branchOpts, (v) => branch = v, req: true)),
            if (_opt) SizedBox(width: half, child: _sel('Buyer', 'buyer', people)),
            if (_opt) SizedBox(width: half, child: _sel('PR Ref.', 'pr_ref', {'—', if (_xs['pr_ref'] != null) _xs['pr_ref']!, ...S.docsOf('PR').where((d) => d.status == 'Approved').map((d) => d.id)}.toList())),
            if (_opt) SizedBox(width: half, child: _sel('RFQ Ref.', 'rfq_ref', ['—', ...S.docsOf('RFQ').map((d) => d.id)])),
            if (_opt) SizedBox(width: half, child: _text('Supplier Quotation Ref.', _c('sq_ref'), hint: 'Supplier\u2019s quotation number')),
          ],
          if (adj) SizedBox(width: half, child: _sel('Adjustment Type', 'adj_type', ['Decrease', 'Increase'], req: true)),
          if (so) ...[
            SizedBox(width: half, child: _text('Customer PO No.', custPoNoCtl, req: true, hint: 'e.g. MM/PO/2026/118')),
            if (_opt) SizedBox(width: half, child: _date('Customer PO Date', custPoDateCtl)),
            SizedBox(width: half, child: _dd('Branch', branch, S.branchNames.map((b) => Opt(b, b)).toList(), (v) => branch = v, req: true)),
            if (_opt) SizedBox(
                width: half,
                child: _dd('Quotation Ref.', quotationRef, [
                  Opt('', '— None —'),
                  ...S.docsOf('QT').where((q) => q.party == party).map((q) => Opt(q.id, '${q.id} · ${q.status}')),
                ], _applyQuotation)),
          ],
        ]),

        if (qt && _opt) ...[
          const SectionTitle('References'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: half, child: _sel('Opportunity Ref.', 'opp_ref', ['—', ...S.opps.where((o) => o.party == party).map((o) => o.id)])),
            SizedBox(width: half, child: _sel('Lead / Enquiry Ref.', 'lead_ref', ['—', ...S.leads.map((l) => l.id)])),
            SizedBox(width: half, child: _text('Customer RFQ No.', _c('cust_rfq'))),
            SizedBox(width: half, child: _date('Customer RFQ Date', _c('cust_rfq_date'))),
          ]),
        ],
        if (po) ...[
          const SectionTitle('Delivery'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: half, child: _date('Expected Delivery Date', _c('exp_del', addDays(todayStr(), 5)), req: true)),
            if (_opt) SizedBox(width: half, child: _sel('Mode of Shipment', 'po_ship', ['Road — supplier vehicle', 'Road — transporter', 'Courier', 'Rail', 'Self pickup'])),
            if (_opt) SizedBox(width: half, child: _sel('Delivery Terms', 'po_del_terms', ['Door delivery', 'Ex-works', 'FOR destination', 'Freight to pay'])),
            if (_opt) SizedBox(width: half, child: _text('Ship-to Address', _c('ship_to'), hint: 'Leave blank to use the warehouse address')),
          ]),
        ],
        if (tr) ...[
          const SectionTitle('Transport'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: half, child: _date('Expected Arrival', _c('arrival', addDays(todayStr(), 2)))),
            SizedBox(width: half, child: _sel('Vehicle', 'tr_vehicle', ['—', ...S.vehicles])),
            SizedBox(width: half, child: _sel('Transferred By', 'tr_by', people)),
            SizedBox(width: half, child: _text('Received By', _c('tr_recv'))),
          ]),
        ],
        if (adj) ...[
          const SectionTitle('Stock'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: half, child: _text('Valuation Rate (₹)', _c('val_rate'), number: true, hint: 'Leave blank to use standard cost')),
            SizedBox(width: half, child: ValueListenableBuilder<int>(valueListenable: _calc, builder: (_, __, ___) => _readOnly('Value Impact', fmtINR(_totals().subtotal)))),
            SizedBox(width: half, child: _sel('Approved By', 'approver', ['—', 'Srinivas Rao'])),
          ]),
        ],
        if (so) ...[
          const SectionTitle('Delivery'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: half, child: _date('Delivery Date', delivDateCtl, req: true)),
            if (_opt) SizedBox(width: half, child: _dd('Mode of Shipment', shipMode, opts(['Road — own vehicle', 'Road — transporter', 'Courier', 'Rail', 'Customer pickup']), (v) => shipMode = v)),
            if (_opt) SizedBox(width: half, child: _dd('Delivery Terms', deliveryTerms, opts(['Door delivery', 'Ex-warehouse', 'FOR destination', 'Freight to pay']), (v) => deliveryTerms = v)),
            if (_opt) SizedBox(
              width: half,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Partial Delivery Allowed'),
                Row(children: [
                  Checkbox(value: partialDelivery, onChanged: (v) => setState(() => partialDelivery = v ?? false)),
                  Expanded(child: Text(partialDelivery ? 'Yes — ship what is available' : 'No — ship only when complete', style: const TextStyle(fontSize: 13))),
                ]),
              ]),
            ),
          ]),
        ],

        if ((pt == 'C' || pt == 'S') && !pr) ...[
          const SectionTitle('Address & Tax'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: half, child: _dd('Payment Terms', paymentTerms, opts(S.termNames), (v) => paymentTerms = v, req: true)),
            if (_opt) SizedBox(width: half, child: _dd('Price List', priceList, S.priceLists.map((pl) => Opt(pl.name, pl.name)).toList(), (v) => priceList = v)),
            if (pt == 'C') ...() {
              // customer documents: choose from the customer's saved addresses (a dropdown only when there is a choice)
              final bills = _addrs.where((a) => a.billing).toList(), ships = _addrs.where((a) => a.shipping).toList();
              // one saved address (or none): a text box that can be changed; several: choose one of them
              Widget pick(String label, List<Address> list, String key, void Function(String) f, String typed, void Function(String) onType) => list.length > 1
                  ? _dd(label, key, [for (final a in list) Opt(a.label, a.full)], f, req: true)
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label(label, req: true),
                      TextFormField(
                        key: ValueKey('$label:$party:${list.length}'),
                        initialValue: list.isEmpty ? typed : (key.isEmpty ? typed : list.first.full),
                        style: const TextStyle(fontSize: 13),
                        onChanged: onType,
                      ),
                    ]);
              return [
                SizedBox(width: half, child: pick('Billing Address', bills, billKey, _setBill, billingAddr, (v) { billingAddr = v; billKey = ''; })),
                SizedBox(width: half, child: pick('Shipping Address', ships, shipKey, _setShip, shippingAddr, (v) { shippingAddr = v; shipKey = ''; })),
                SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Place of Supply'),
                  TextFormField(key: ValueKey('pos:$party'), initialValue: placeOfSupply, style: const TextStyle(fontSize: 13), onChanged: (v) => placeOfSupply = v),
                ])),
              ];
            }()
            else ...[
            SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Billing Address *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
              TextFormField(initialValue: billingAddr, style: const TextStyle(fontSize: 13), onChanged: (v) => billingAddr = v),
            ])),
            if (so || _opt) SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Shipping Address', req: so),
              TextFormField(initialValue: shippingAddr, style: const TextStyle(fontSize: 13), onChanged: (v) => shippingAddr = v),
            ])),
            ],
            if (_opt && pt != 'C') SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Place of Supply'),
              TextFormField(key: ValueKey('pos:$party'), initialValue: placeOfSupply, style: const TextStyle(fontSize: 13), onChanged: (v) => placeOfSupply = v),
            ])),
            if (_opt) SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Tax Reg. No. (GSTIN)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
              TextFormField(initialValue: taxRegNo, style: const TextStyle(fontSize: 13), onChanged: (v) => taxRegNo = v),
            ])),
            if (qt || _opt) SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Contact Person', req: qt),
              TextFormField(initialValue: contactPerson, style: const TextStyle(fontSize: 13), onChanged: (v) => contactPerson = v),
            ])),
          ]),
        ],

        if ((so || qt || po) && _opt) ...[
          SectionTitle(po ? 'Terms' : 'Commercial Terms'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            if (so) SizedBox(width: half, child: _text('Advance Amount (₹)', advanceCtl, number: true)),
            if (po) SizedBox(width: half, child: _text('Advance %', _c('adv_pct', '0'), number: true)),
            if (qt) ...[
              SizedBox(width: half, child: _sel('Delivery Terms / Incoterms', 'qt_del_terms', ['Door delivery', 'Ex-warehouse', 'FOR destination', 'Freight to pay'])),
              SizedBox(width: half, child: _text('Delivery Period', _c('del_period', '7 days from PO'))),
              SizedBox(width: half, child: _sel('Mode of Shipment', 'qt_ship', ['Road — own vehicle', 'Road — transporter', 'Courier', 'Rail', 'Customer pickup'])),
              SizedBox(width: half, child: _text('Warranty', _c('warranty'), hint: 'e.g. 12 months from invoice')),
            ],
          ]),
        ],

        const SectionTitle('Line Items'),
        KeyedSubtree(
          key: const ValueKey('ro-table'),
          child: IgnorePointer(ignoring: widget.readOnly, child: _lineItems(pr: pr, po: po, tr: tr, adj: adj, lx: lx, noPrice: noPrice)),
        ),
        Align(key: const ValueKey('ro-hide-add'), alignment: Alignment.centerLeft, child: Btn.ghost('Add line', icon: 'plus', small: true, onTap: () => setState(_add))),

        if (_opt && !noPrice) const SectionTitle('Charges & Totals'),
        if (_opt && !noPrice) Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Header Discount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
            TextField(controller: headerDiscCtl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13), onChanged: (_) => _calc.value++),
          ])),
          SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Freight Charges (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
            TextField(controller: freightCtl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13), onChanged: (_) => _calc.value++),
          ])),
          SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Packing & Forwarding (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
            TextField(controller: packingCtl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13), onChanged: (_) => _calc.value++),
          ])),
          SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Other Charges (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
            TextField(controller: otherChargesCtl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13), onChanged: (_) => _calc.value++),
          ])),
        ]),

        if (!noPrice) const SizedBox(height: 12),
        if (!noPrice) ValueListenableBuilder<int>(valueListenable: _calc, builder: (_, __, ___) {
          // recomputed here, so the totals follow every quantity / rate typed
          final (:subtotal, :totalLineDisc, :totalTax, :grandTotal, :roundOff) = _totals();
          return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
          child: Column(children: [
            _totRow(const Text('Subtotal', style: TextStyle(color: C.soft)), Text(_m(subtotal), style: tsB)),
            if (_opt) const SizedBox(height: 4),
            if (_opt) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Line Discounts', style: TextStyle(color: C.soft)), Text('− ${_m(totalLineDisc)}')]),
            const SizedBox(height: 4),
            _totRow(const Text('Tax Total (GST)', style: TextStyle(color: C.soft)), Text(_m(totalTax))),
            const SizedBox(height: 4),
            _totRow(const Text('Round-off', style: TextStyle(color: C.faint)), Text(roundOff.toStringAsFixed(2))),
            const Divider(height: 16),
            _totRow(const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), Text(_m(grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.blue600))),
            // foreign currency: what it comes to in rupees (this ₹ value is what is saved and reported)
            if (currency != 'INR') ...[
              const SizedBox(height: 6),
              _totRow(Text('In Indian Rupees (1 $currency = ₹${_fx.toStringAsFixed(2)})', style: const TextStyle(color: C.soft)), Text(fmtINR(grandTotal * _fx), style: tsB)),
            ],
          ]),
        );
        }),

        if (_opt) const SectionTitle('Other'),
        if (_opt) Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Remarks (Printed)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
            TextField(controller: remarksCtl, maxLines: 2, style: const TextStyle(fontSize: 13)),
          ])),
          SizedBox(width: half, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Internal Notes (Not Printed)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
            TextField(controller: internalNotesCtl, maxLines: 2, style: const TextStyle(fontSize: 13)),
          ])),
        ]),

        if (qt && _opt) ...[
          const SectionTitle('Follow-up'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: half, child: _text('Win Probability %', _c('win_prob', '50'), number: true)),
            SizedBox(width: half, child: _text('Competitors', _c('competitors'))),
            SizedBox(width: half, child: _date('Follow-up Date', _c('follow_up', addDays(todayStr(), 3)))),
          ]),
        ],
        if (pr) ...[
          const SectionTitle('Justification'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: c.maxWidth, child: _text('Business Justification', _c('purpose'), maxLines: 3, hint: 'Why is this purchase needed?')),
            if (_opt) SizedBox(width: half, child: ValueListenableBuilder<int>(valueListenable: _calc, builder: (_, __, ___) => _readOnly('Estimated Amount', _m(_totals().grandTotal)))),
          ]),
        ],
        const SizedBox(height: 10),
        if (so || qt || po) ...[
          const SectionTitle('Terms & Conditions'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(
                width: half,
                child: _dd('T&C Template', tncTemplate, [
                  for (final k in _tncFor(po)) Opt(k, k),
                ], (v) => setState(() {
                      tncTemplate = v;
                      tncCtl.text = _tncTemplates[v] ?? '';
                    }), req: true)),
            SizedBox(width: c.maxWidth, child: _text('Terms & Conditions', tncCtl, req: true, maxLines: 5, hint: 'Printed at the bottom of the document — edit if needed')),
          ]),
          const SizedBox(height: 4),
        ],
        if (po && editing != null)
          for (final inv in S.docsOf('PI').where((p) => p.ref == editing.id && p.status != 'Rejected' && supplierInvoiceSent(p))) ...[
            const SectionTitle('Supplier Invoice'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoteBox(Tone.green, 'file', 'The supplier has sent invoice ${inv.supInv}.', 'It is checked automatically against this order and the goods received · ${inv.match?.msg ?? 'waiting for the goods receipt'}.'),
            ),
            Wrap(spacing: 14, runSpacing: 14, children: [
              SizedBox(width: half, child: _readOnly('Supplier Invoice No.', inv.supInv ?? '—')),
              SizedBox(width: half, child: _readOnly('Invoice Date', inv.date)),
              SizedBox(width: half, child: _readOnly('Purchase Invoice', inv.id)),
              SizedBox(width: half, child: _readOnly('Status', inv.status)),
              SizedBox(width: half, child: _readOnly('Invoice Amount', fmtINR(S.calc(inv).total))),
              SizedBox(width: half, child: _readOnly('Due Date', inv.due ?? '—')),
            ]),
            const SizedBox(height: 12),
          ],
        Text(_note, key: const ValueKey('ro-hide-note'), style: const TextStyle(fontSize: 12, color: C.faint)),
        const SizedBox(height: 16),
        Wrap(key: const ValueKey('ro-hide-buttons'), alignment: WrapAlignment.end, spacing: 10, children: [
          Btn.secondary('Cancel', onTap: () => Navigator.of(context).pop()),
          if (widget.editId != null && widget.t == 'PR' && S.doc(widget.editId!)?.status == 'Draft') ...[
            // blue, no icon (same look as the other main buttons on the form)
            Btn('Save changes', onTap: _save),
            Btn('Submit for approval', icon: 'check', onTap: () => _save(submit: true)),
          ] else
            Btn(widget.editId != null ? 'Save changes' : widget.fromOppId != null ? 'Create quotation' : widget.fromId != null ? (widget.t == 'SO' ? 'Create sales order' : 'Create purchase order') : 'Create ${docTitle(widget.t)}', icon: widget.editId != null ? null : 'check', onTap: _save),
        ]),
      ];
      if (!widget.readOnly) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
      // read-only: the form is shown as it was filled in, without Save / Cancel and the edit-only hints;
      // nothing can be changed, but the line items can still be scrolled sideways
      bool keyed(Widget w, String prefix) => w.key is ValueKey && (w.key as ValueKey).value.toString().startsWith(prefix);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final w in kids)
          if (!keyed(w, 'ro-hide')) keyed(w, 'ro-table') ? w : IgnorePointer(child: w),
      ]);
    });
  }
}

/// A totals line: label on the left, amount on the right; both shrink on narrow screens instead of overflowing.
Widget _totRow(Widget label, Widget value) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(child: label),
      const SizedBox(width: 10),
      // amount stays at the right edge and shrinks on narrow screens
      Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: value)),
    ]);


/// The number the next document of type [t] will get (preview only).
String nextNo(String t) => '${S.dt[t]!.prefix}${(S.dt[t]!.seq + 1).toString().padLeft(4, '0')}';

/// Document type label in title case, e.g. 'Sales order' → 'Sales Order'.
String docTitle(String t) => S.dt[t]!.label.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

// ================================================================ party / item drawers
Widget partyDocs(bool Function(Doc) pred) {
  final ds = S.docs.where(pred).toList();
  if (ds.isEmpty) return const Empty('No documents');
  return Column(children: [
    for (final d in ds) ActivityRow('file', '${d.id} · ${S.dt[d.type]!.label}', '${d.date} · ${fmtINR(d.amount)}', trailing: StatusBadge(d.status), onTap: () => openDocNav(d.id)),
  ]);
}

void openCustomerPanel(String id) {
  final c = S.cust(id);
  final out = S.outstanding(id);
  final od = S.overdueInv(id);
  final pl = S.priceLists.where((l) => l.group == c.group).firstOrNull ?? S.priceLists.firstOrNull;
  final used = c.limit == 0 ? 0.0 : out / c.limit * 100;
  openPanel(
    header: (_) => recHead(panelHead(c.name, '${c.id} · ${c.group}', status: StatusBadge(c.status)), id),
    body: (_) => RecordBody([
      TabDef('Details', () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (od.isNotEmpty) NoteBox(Tone.red, 'clock', '${od.length} overdue invoice(s).', 'New orders go on credit hold until cleared.'),
            KvGrid([
              Kv.t('Customer ID', c.id), Kv.t('GSTIN', c.gstin), Kv.t('City · State', '${c.city} · ${c.state}'), Kv.t('Contact', '${c.contact} · ${c.phone}'),
              Kv.t('Customer group', c.group), Kv.t('Price list', pl == null ? '—' : '${pl.name}${pl.disc > 0 ? ' (−${pl.disc}%)' : ''}'), Kv.t('Payment terms', 'Net ${c.terms} days'),
              Kv.t('Tax on sales', c.state == S.companyInfo['state'] ? 'CGST + SGST' : 'IGST'), Kv.t('Credit limit', fmtINR(c.limit)), Kv.t('Outstanding', fmtINR(out)),
              Kv.t('Available credit', fmtINR(math.max(0, c.limit - out))),
              if (c.email.isNotEmpty) Kv.t('Email', c.email),
              Kv.t('GST registration', c.gstType),
              if (c.billTo.isNotEmpty) Kv.t('Billing address', c.billTo),
              if (c.shipTo.isNotEmpty) Kv.t('Shipping address', c.shipTo),
            ]),
            const SectionTitle('Credit used'),
            Bar(used),
            Padding(padding: const EdgeInsets.only(top: 5), child: Text('${used.round()}% of limit used', style: tsFaint)),
          ])),
      TabDef('Orders', () => partyDocs((d) => d.type == 'SO' && d.party == id)),
      TabDef('Invoices', () => partyDocs((d) => d.type == 'INV' && d.party == id)),
      TabDef('Payments', () => partyDocs((d) => d.type == 'CP' && d.party == id)),
      TabDef('Addresses', () => AddressesTab(id)),
      TabDef('Attachments', () => AttachmentsTab(id)),
    ]),
    footer: (ctx) => [
      Btn.secondary('Edit', icon: 'edit', onTap: () { closeAll(); editCustomer(c); }),
      deleteBtn(() => deleteCustomer(c)),
      Btn.secondary(c.status == 'Credit Hold' ? 'Remove hold' : 'Put on hold', icon: c.status == 'Credit Hold' ? 'unlock' : 'lock', onTap: () {
        c.status = c.status == 'Credit Hold' ? 'Active' : 'Credit Hold';
        closeAll();
        S.refresh();
        toast('${c.name} · ${c.status}');
      }),
      Btn('New sales order', icon: 'plus', onTap: () {
        closeAll();
        openDocForm('SO', party: id);
      }),
    ],
  );
}

void openSupplierPanel(String id) {
  final s = S.sup(id);
  openPanel(
    header: (_) => recHead(panelHead(s.name, '${s.id} · Supplier', status: StatusBadge(s.status)), id),
    body: (_) => RecordBody([
      TabDef('Details', () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KvGrid([
              Kv.t('Supplier ID', s.id), Kv.t('GSTIN', s.gstin), Kv.t('City · State', '${s.city} · ${s.state}'), Kv.t('Contact', s.contact),
              if (s.phone.trim().isNotEmpty) Kv.t('Mobile', s.phone),
              if (s.email.isNotEmpty) Kv.t('Email', s.email),
              Kv.t('GST registration', s.gstType),
              if (s.address.isNotEmpty) Kv.t('Address', s.address),
              Kv.t('Payment terms', 'Net ${s.terms} days'), Kv.t('Lead time', '${s.lead} days'), Kv.t('Tax on purchases', s.state == S.companyInfo['state'] ? 'CGST + SGST' : 'IGST'),
            ]),
            const SectionTitle('Performance'),
            LegendRow(C.green, 'On-time delivery', '${s.otd}%'),
            Bar(s.otd.toDouble(), color: C.green),
            const SizedBox(height: 10),
            LegendRow(C.blue600, 'Quality acceptance', '${s.quality}%'),
            Bar(s.quality.toDouble()),
          ])),
      TabDef('Purchase orders', () => partyDocs((d) => d.type == 'PO' && d.party == id)),
      TabDef('Invoices', () => partyDocs((d) => d.type == 'PI' && d.party == id)),
      TabDef('Attachments', () => AttachmentsTab(id)),
    ]),
    footer: (_) => [
      Btn.secondary('Edit', icon: 'edit', onTap: () { closeAll(); editSupplier(s); }),
      deleteBtn(() => deleteSupplier(s)),
      Btn('New purchase order', icon: 'plus', onTap: () {
        closeAll();
        openDocForm('PO', party: id);
      }),
    ],
  );
}

void openItemPanel(String id) {
  final p = S.item(id);
  final led = S.ledger.where((l) => l.item == id).toList();
  openPanel(
    header: (_) => recHead(panelHead(p.name, '${p.id} · ${p.cat}'), id),
    body: (_) => RecordBody([
      TabDef('Details', () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KvGrid([
              Kv.t('Item code', p.id), Kv.t('Category', p.cat), Kv.t('HSN · GST', '${p.hsn} · ${p.gst}%'), Kv.t('Unit', p.uom), Kv.t('Standard cost', fmtINR(p.cost)),
              Kv.t('Base sale price', fmtINR(p.price)), Kv.t('Reorder level', '${p.reorder}'), Kv.t('Min. Order Qty · Order Multiple', '${p.moq} · ${p.mult}'), Kv.t('Lead time', '${p.lead} days'),
              Kv.t('Preferred supplier', S.sup(p.sup).name), Kv.t('Tracking', p.track), Kv.t('Default bin', S.suggestBin(p.id)),
            ]),
            const SectionTitle('Stock by warehouse'),
            for (final w in S.warehouses)
              ActivityRow('home', '${w.code} · ${S.stk(w.id, p.id).onhand} on hand', 'Reserved ${S.stk(w.id, p.id).reserved} · Available ${S.avail(w.id, p.id)}',
                  trailing: StatusBadge(S.avail(w.id, p.id) < p.reorder ? 'Below reorder' : (S.avail(w.id, p.id) < p.reorder * 1.5 ? 'Low' : 'OK'))),
          ])),
      TabDef('Ledger', () => led.isEmpty
          ? const Empty('No movements yet')
          : Column(children: [
              for (final l in led)
                ActivityRow(l.qty < 0 ? 'minus' : 'plus', '${l.qty > 0 ? '+' : ''}${l.qty} · ${l.type}', '${l.ref} · ${S.wh(l.wh).code} · ${l.date}', tone: l.qty < 0 ? Tone.red : Tone.green, onTap: () => openDocNav(l.ref)),
            ])),
      TabDef('Pricing', () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KvGrid([for (final l in S.priceLists) Kv.t('${l.name} list', fmtINR((p.price * (100 - l.disc) / 100).roundToDouble()))]),
            const SizedBox(height: 14),
            for (final t in S.tradeAgreements.where((t) => t.item == id))
              NoteBox(Tone.blue, 'tag', t.id, '${t.kind} · ${t.kind == 'Sales' ? S.cust(t.party).name : S.sup(t.party).name} · ${fmtINR(t.price)} from ${t.minQty} units'),
          ])),
      TabDef('Attachments', () => AttachmentsTab(id)),
    ]),
    footer: (_) => [
      Btn.secondary('Edit', icon: 'edit', onTap: () { closeAll(); editItem(p); }),
      deleteBtn(() => deleteItem(p)),
      Btn.secondary('Adjust stock', icon: 'sliders', onTap: () {
        closeAll();
        openDocForm('ADJ');
      }),
      Btn('Request purchase', icon: 'bag', onTap: () {
        closeAll();
        openDocForm('PR', party: p.sup);
      }),
    ],
  );
}

/// Record page title with the attachment pin on the right.
Widget recHead(Widget title, String attachKey) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: title), AttachPin(attachKey)]);

/// Attachment key for a master record: its code (e.g. LEAD-0101 from "LEAD-0101 · Lead") when the subtitle starts with one, else the title.
String _recKey(String title, String sub) {
  final first = sub.split(' · ').first;
  return RegExp(r'\d').hasMatch(first) ? first : '$title|$sub';
}

/// Generic key/value page for master records.
void recPanel(String title, String sub, List<Kv> kvs, {List<TabDef> extra = const [], List<Widget> Function(BuildContext)? footer, Widget? top, String? id, String? formSection}) {
  // the record's status goes to the top, next to the title
  final st = kvs.where((k) => k.label == 'Status' || k.label == 'Stage').firstOrNull;
  final rest = kvs.where((k) => k != st).toList();
  openPanel(
    header: (_) => recHead(panelHead(title, sub, status: st == null ? null : (st.value is Text ? StatusBadge((st.value as Text).data ?? '') : st.value)), id ?? _recKey(title, sub)),
    body: (_) => RecordBody([
      TabDef('Details', () => formSection != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (top != null) top, KvForm(formSection, kvs)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // document-style heading: name and number, status, then a dark rule
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(sub, style: const TextStyle(fontSize: 12.5, color: C.faint)),
                ]),
              ),
              if (st != null) st.value is Text ? StatusBadge((st.value as Text).data ?? '') : st.value,
            ]),
            const Padding(padding: EdgeInsets.only(top: 14, bottom: 4), child: Divider(height: 1, thickness: 1.4, color: C.text)),
            if (top != null) top,
            KvGrid(rest),
          ])),
      ...extra,
      TabDef('Attachments', () => AttachmentsTab(id ?? _recKey(title, sub))),
    ]),
    footer: footer,
  );
}

/// Picks a document and continues into the matching action dialog.
void pickDoc(String title, String label, List<Doc> ds, void Function(Doc) next, String empty, String note) {
  mform(
    title,
    [
      F('doc', label,
          type: 'select',
          req: true,
          full: true,
          options: ds.isEmpty
              ? [const Opt('', '— none available —')]
              : ds.map((d) => Opt(d.id, '${d.id} · ${S.partyName(d)} · ${fmtINR(d.type == 'INV' || d.type == 'PI' ? d.amount - d.paid : d.amount)}')).toList()),
    ],
    (v, ctx) {
      final d = S.doc(v['doc'] as String);
      if (d == null) return false;
      Navigator.of(ctx).pop();
      next(d);
      return false;
    },
    btn: 'Continue',
    icon: 'swap',
    disabled: ds.isEmpty,
    intro: ds.isEmpty ? empty : note,
  );
}
