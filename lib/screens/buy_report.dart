import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/auth.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/overlays.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'doc_report.dart';
import 'sales_proc.dart' show newRfqForm;

/// Purchase request, purchase order, goods receipt, purchase invoice and purchase return
/// pages: a download icon at the top (once the document can be shared), the document as a
/// clean report, then the next step to take and the documents that belong to it.
void openBuyReport(Doc d) {
  final inv = d.type == 'PO' ? S.docsOf('PI').where((p) => p.ref == d.id && p.status != 'Rejected').firstOrNull : null;
  openPanel(
    header: (_) => Row(children: [
      Expanded(child: panelHead(d.id, d.party == null ? docTitle(d.type) : '${docTitle(d.type)} · ${S.partyName(d)}', status: StatusBadge(d.status))),
      if (d.type != 'PR' && canDownloadBuyDoc(d)) ...[
        Btn.secondary('Download PDF', icon: 'download', small: true, onTap: () => downloadBuyDoc(d)),
        const SizedBox(width: 8),
      ],
    ]),
    body: (_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.type == 'PR' && d.status == 'Rejected' && (d.reason ?? '').isNotEmpty)
        _PrRejectionBanner(d.reason!),
      if (d.type == 'GRN' && (d.qcResult == 'Failed' || d.qcResult == 'Partially passed' || d.lines.any((l) => (l.acc > 0 || qcDone(d)) && l.qty > l.acc)))
        _GrnQcRejectionBanner(d),
      DocReport(d),
      if (d.type == 'PO' && inv != null && supplierInvoiceSent(inv))
        _PoSupplierInvoiceCard(po: d, inv: inv),
      if (d.type == 'PI') _ThreeWayMatch(d),
      _NextSteps(d),
      // the supplier's invoice shows at the bottom once the supplier has sent it (and not before)
      if (d.type == 'PI' && supplierInvoiceSent(d)) _PoSupplierInvoiceCard(po: S.doc(d.ref ?? '') ?? d, inv: d, showView: false),
    ]),
  );
}

/// A purchase request can be downloaded once approved, rejected, or ordered.
/// A purchase invoice can be downloaded as soon as the supplier has sent it.
bool canDownloadBuyDoc(Doc d) {
  if (d.type == 'PR') {
    return const ['Approved', 'Rejected', 'Ordered'].contains(d.status) ||
        S.docsOf('PO').any((p) => p.ref == d.id || d.refs.contains(p.id));
  }
  if (d.type == 'PI') return supplierInvoiceSent(d);
  return true;
}

/// The supplier has sent its invoice: it has an invoice number and is no longer a draft.
bool supplierInvoiceSent(Doc pi) => pi.supInv != null && pi.status != 'Draft';

/// Downloads the document in its clean PDF format.
void downloadBuyDoc(Doc d) {
  switch (d.type) {
    case 'GRN':
      downloadGrn(d);
      break;
    case 'PI':
      downloadSupplierInvoice(d);
      break;
    case 'PRT':
      downloadPrt(d);
      break;
    case 'INV':
      downloadInvoice(d);
      break;
    default:
      downloadOrder(d);
  }
}

// ---------------------------------------------------------------- PR → PO
/// Opens the full purchase order form filled in from the approved request, so it can be
/// checked and changed. Nothing is saved until Create purchase order is pressed.
/// A request whose lines have different suppliers becomes one purchase order per supplier: pick the supplier to order from next.
void openPoFromPr(Doc pr) {
  final left = S.prSuppliersToOrder(pr);
  void open(String sup) => openFormPage('New Purchase Order · from ${pr.id}${sup.isEmpty ? '' : ' · ${S.sup(sup).name}'}', DocForm('PO', party: sup.isEmpty ? null : sup, fromId: pr.id, fromSup: sup));
  if (left.length <= 1) {
    open(left.isEmpty ? (pr.party ?? '') : left.first);
    return;
  }
  final groups = S.prBySupplier(pr);
  mform('Purchase order from ${pr.id}', [
    F('sup', 'Supplier to order from', type: 'select', req: true, full: true, def: left.first, options: [
      for (final x in left) Opt(x, '${x.isEmpty ? 'Supplier not chosen yet' : S.sup(x).name} · ${groups[x]!.length} line(s)'),
    ]),
  ], (v, ctx) {
    Navigator.of(ctx).pop();
    open(v['sup'] as String);
    return false;
  }, btn: 'Continue', icon: 'swap', intro: 'This request has items from ${left.length} suppliers, so each supplier gets its own purchase order. Pick the supplier to order from now; the request stays Approved until every supplier is ordered.');
}

// ---------------------------------------------------------------- 3-way match
/// Purchase order, goods receipt and supplier invoice side by side, line by line, so
/// the system checks them automatically.
class _ThreeWayMatch extends StatelessWidget {
  final Doc pi;
  const _ThreeWayMatch(this.pi);

  Widget _tile(String label, String no, String? sub, VoidCallback? onView) => Container(
        width: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: C.faint)),
              const SizedBox(height: 2),
              Text(no, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              if (sub != null) Text(sub, style: const TextStyle(fontSize: 11.5, color: C.soft)),
            ]),
          ),
          if (onView != null) Btn.ghost('View', small: true, onTap: onView),
        ]),
      );

  Widget _c(String v, {bool head = false, bool right = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(head ? v.toUpperCase() : v,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
                fontSize: head ? 10.5 : 12.5,
                letterSpacing: head ? .4 : 0,
                fontWeight: head || color != null ? FontWeight.w700 : FontWeight.w400,
                color: color ?? (head ? C.soft : C.text))),
      );

  @override
  Widget build(BuildContext context) {
    final po = pi.ref == null ? null : S.doc(pi.ref!);
    if (po == null) return const SizedBox.shrink();
    final grns = S.docsOf('GRN').where((g) => g.ref == po.id).toList();
    final verified = const ['Approved', 'Paid'].contains(pi.status);
    final tol = S.params.matchTolerance;
    const border = BorderSide(color: C.border);

    final rows = <TableRow>[
      TableRow(decoration: const BoxDecoration(color: C.bg), children: [
        _c('Item', head: true),
        _c('PO qty', head: true, right: true),
        _c('PO rate', head: true, right: true),
        _c('Received', head: true, right: true),
        _c('Accepted', head: true, right: true),
        _c('Invoiced qty', head: true, right: true),
        _c('Invoice rate', head: true, right: true),
        _c('Check', head: true),
      ]),
    ];
    for (final l in pi.lines) {
      final pl = po.lines.where((x) => x.item == l.item).firstOrNull;
      final recv = pl?.recv ?? 0;
      final acc = grns.where(qcDone).fold<int>(0, (a, g) => a + g.lines.where((x) => x.item == l.item).fold<int>(0, (b, x) => b + x.acc));
      // rejected units already returned on a debit note settle the difference
      final back = S.docsOf('PRT').where((r) => r.status == 'Returned' && grns.any((g) => g.id == r.ref)).fold<int>(0, (a, r) => a + r.lines.where((x) => x.item == l.item).fold<int>(0, (b, x) => b + x.qty));
      final rateDiff = pl == null ? 100.0 : ((l.rate - pl.rate) / pl.rate * 100).abs();
      final String check;
      if (pl == null) {
        check = 'Not on PO';
      } else if (recv == 0) {
        check = 'Not received';
      } else if (!grns.any(qcDone)) {
        check = 'Waiting for QC';
      } else if (l.qty > acc + back) {
        check = 'Qty differs';
      } else if (rateDiff > tol) {
        check = 'Rate differs';
      } else {
        check = 'Matches';
      }
      rows.add(TableRow(children: [
        _c(l.desc ?? S.item(l.item).name),
        _c('${pl?.qty ?? 0}', right: true),
        _c(pl == null ? '—' : fmtINR(pl.rate), right: true),
        _c('$recv', right: true),
        _c(grns.any(qcDone) ? '$acc' : 'QC pending', right: true),
        _c('${l.qty}', right: true),
        _c(fmtINR(l.rate), right: true),
        _c(check, color: check == 'Matches' ? C.green : C.red),
      ]));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Divider(height: 1, color: C.border),
        const SizedBox(height: 16),
        const Text('3-way match', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          verified
              ? 'Checked: the invoice matches the purchase order and the goods received.'
              : 'The system checks the purchase order, the goods receipt and this invoice automatically.',
          style: const TextStyle(fontSize: 12, color: C.soft),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _tile('1 · Purchase order', po.id, '${fmtINR(po.amount)} · ${po.status}', () => openDoc(po.id)),
          if (grns.isEmpty) _tile('2 · Goods receipt', 'Not received yet', null, null),
          for (final g in grns) _tile('2 · Goods receipt', g.id, g.status, () => openDoc(g.id)),
          _tile('3 · Supplier invoice', pi.supInv ?? pi.id, '${fmtINR(pi.amount)} · this document', null),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (ctx, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              // phones: keep the columns readable and scroll sideways
              width: c.maxWidth < 760 ? 760 : c.maxWidth,
              child: Table(
                border: const TableBorder(top: border, bottom: border, left: border, right: border, horizontalInside: border),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {0: FlexColumnWidth(2.4)},
                children: rows,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Rate tolerance ${tol.toStringAsFixed(0)}% · the invoiced quantity cannot be more than the quantity accepted at QC (rejects returned on a debit note are settled).',
              style: const TextStyle(fontSize: 11.5, color: C.faint)),
        ),
      ]),
    );
  }
}

/// Rejecting an invoice or a return always records why; the reason shows on the document.
void _rejectWithReason(Doc d, List<String> reasons) => mform('Reject ${docTitle(d.type)} · ${d.id}', [
      F('why', 'Reason', type: 'select', req: true, options: opts(reasons)),
      const F('details', 'Details', type: 'textarea', full: true, show: true),
    ], (v, _) {
      final dt = (v['details'] as String).trim();
      after(S.reject(d.id, dt.isEmpty ? v['why'] as String : '${v['why']} · $dt'));
      return false;
    }, btn: 'Reject', icon: 'x', status: d.status, statusNote: 'Becomes Rejected; the reason is saved and shown on the document.');

// ---------------------------------------------------------------- next step + documents
class _NextSteps extends StatelessWidget {
  final Doc d;
  const _NextSteps(this.d);

  void _run(Res r) => after(r);

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    final id = d.id;
    final steps = <Widget>[];
    String? info;
    final docs = <(String, String, VoidCallback)>[]; // button, document no., download

    switch (d.type) {
      case 'PR':
        if (s == 'Draft') {
          steps.addAll([
            Btn.secondary('Edit request', icon: 'edit', onTap: () => editDoc(d)),
            Btn('Submit for approval', icon: 'check', onTap: () => _run(S.prSubmit(id))),
          ]);
        }
        if (s == 'Pending Approval') {
          steps.addAll([
            Btn.danger('Reject', icon: 'x', onTap: () => dlgRejectPr(d)),
            Btn('Approve request', icon: 'check', onTap: () => _run(S.prApprove(id))),
          ]);
        }
        if (s == 'Approved') {
          // not sure of the price: ask suppliers first (their quotations come in through the Supplier Portal)
          steps.add(Btn.secondary('Ask suppliers for quotes', icon: 'msg', onTap: () => newRfqForm(pr: id)));
          steps.add(Btn('Convert to purchase order', icon: 'swap', onTap: () => openPoFromPr(d)));
          steps.add(Btn.secondary('Download purchase request', icon: 'download', onTap: () => downloadBuyDoc(d)));
        }
        if (s == 'RFQ Sent') {
          final rfq = S.docsOf('RFQ').where((r) => r.ref == id).firstOrNull;
          info = 'Quotations asked from suppliers · the order is made from the best one';
          if (rfq != null) steps.add(Btn('View request for quotation · ${rfq.id}', icon: 'msg', onTap: () => openDoc(rfq.id)));
        }
        if (s == 'Rejected') {
          info = 'Request rejected by SCM Manager · Reason: ${d.reason ?? 'No reason specified'}';
          steps.add(Btn.secondary('Download purchase request', icon: 'download', onTap: () => downloadBuyDoc(d)));
        }
        if (s == 'Ordered') {
          final po = S.docsOf('PO').where((p) => p.ref == id || d.refs.contains(p.id)).firstOrNull;
          if (po != null) {
            steps.add(Btn.secondary('View purchase order · ${po.id}', icon: 'bag', onTap: () => openDoc(po.id)));
          }
          steps.add(Btn.secondary('Download purchase request', icon: 'download', onTap: () => downloadBuyDoc(d)));
        }
        break;
      case 'PO':
        if (canEditDoc(d)) steps.add(Btn.secondary('Edit', icon: 'edit', onTap: () => editDoc(d)));
        if (s == 'Pending Approval' || s == 'Draft') steps.add(Btn('Approve & send to supplier', icon: 'check', onTap: () => _run(S.poApprove(id))));
        if (s == 'Sent to Supplier' || s == 'Partially Received') steps.add(Btn('Goods received', icon: 'inbox', onTap: () => dlgReceive(d)));
        // goods received: the goods receipt can be downloaded from the order
        for (final g in S.docsOf('GRN').where((g) => g.ref == id)) {
          docs.add(('Download goods receipt', g.id, () => downloadGrn(g)));
        }
        break;
      case 'GRN':
        if (s == 'QC Pending') steps.add(Btn('Raise QC', icon: 'checksq', onTap: () => _run(S.grnRaiseQc([id]))));
        // with the QC team: they inspect and post the result in Buy › Quality Check (nothing to press here)
        if (s == 'QC Requested') info = 'With the QC team for inspection. The QC report appears here as soon as the QC team posts the result.';
        // once the QC team has posted the result, the QC report is what is left: it can be downloaded
        if (qcDone(d) && d.qcSent != null) steps.add(Btn('Download QC report', icon: 'download', onTap: () => downloadQc(d)));
        break;
      case 'PI':
        // the system checks every invoice against the purchase order and goods receipt by itself (no Verify / Reject buttons)
        if (s == 'Awaiting Goods Receipt') info = 'Waiting for the goods receipt and QC. The invoice is checked automatically as soon as the QC result is posted.';
        if (s == 'Pending Approval') steps.add(Btn('Approve difference', icon: 'check', onTap: () => _run(S.piApprove(id))));
        break;
      case 'INV':
        if (s != 'Paid' && S.canAct('INV', 'Record payment')) steps.add(Btn('Record payment', icon: 'wallet', onTap: () => dlgPay(d)));
        if (S.canCreate('SR')) steps.add(Btn.secondary('Create return', icon: 'refund', onTap: () => dlgSalesReturn(d)));
        if (s == 'Paid') info = 'Fully paid.';
        // receipts for the payments recorded against this invoice
        for (final cp in S.docsOf('CP').where((c) => c.ref == id)) {
          docs.add(('Download receipt', cp.id, () => downloadReceipt(cp)));
        }
        break;
      case 'PRT':
        if (s == 'Submitted') {
          steps.addAll([
            Btn.danger('Reject', icon: 'x', onTap: () => _rejectWithReason(d, ['Goods to be kept', 'Supplier will replace on site', 'Wrong quantity on the return', 'Other'])),
            Btn('Approve return', icon: 'check', onTap: () => _run(S.prtApprove(id))),
          ]);
        }
        if (s == 'Approved' || s == 'Requested') steps.add(Btn('Dispatch items', icon: 'truck', onTap: () => _run(S.prtDispatch(id))));
        if (s == 'Returned') info = 'Items dispatched to the supplier · debit note ${d.refs.where((x) => x.startsWith('DBN')).join(', ')}';
        break;
    }

    // a button is shown only to the people responsible for that step (approvals and rejections: the SCM Manager)
    steps.retainWhere((w) => w is! Btn || S.canAct(d.type, w.label));
    if (steps.isEmpty && docs.isEmpty && info == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Divider(height: 1, color: C.border),
        if (info != null) ...[
          const SizedBox(height: 14),
          Text(info, style: const TextStyle(fontSize: 12.5, color: C.soft)),
        ],
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Next step', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: steps),
        ],
        if (docs.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Documents', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final x in docs)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
              // the button drops under the document number on phones
              child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 6, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.description_outlined, size: 18, color: C.soft),
                  const SizedBox(width: 10),
                  Text(x.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                Btn.secondary(x.$1, icon: 'download', small: true, onTap: x.$3),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _PrRejectionBanner extends StatelessWidget {
  final String reason;
  const _PrRejectionBanner(this.reason);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF87171)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Purchase Request Rejected by SCM Manager', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B), fontSize: 13.5)),
            const SizedBox(height: 4),
            Text('Reason: $reason', style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 13, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

class _GrnQcRejectionBanner extends StatelessWidget {
  final Doc grn;
  const _GrnQcRejectionBanner(this.grn);

  @override
  Widget build(BuildContext context) {
    final rejQty = grn.lines.fold<int>(0, (sum, l) => sum + (l.qty > l.acc ? l.qty - l.acc : 0));
    final accQty = grn.lines.fold<int>(0, (sum, l) => sum + l.acc);
    final prt = S.docsOf('PRT').where((p) => p.ref == grn.id && p.status != 'Rejected').firstOrNull;
    final isFullRejection = accQty == 0 && rejQty > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF87171)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.highlight_off_rounded, color: Color(0xFFDC2626), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isFullRejection
                    ? 'Quality Check Failed: All $rejQty units rejected by QC Inspector'
                    : 'Quality Check: $rejQty unit(s) rejected by QC Inspector ($accQty accepted)',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B), fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Reason: ${(grn.qcNote ?? '').isNotEmpty ? grn.qcNote! : 'Items damaged in transit / failing inspection standards'}'
                '${(grn.qcBy ?? '').isNotEmpty ? ' · Inspected by ${grn.qcBy}' : ''}',
                style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 13, height: 1.3),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (prt != null) ...[
            Btn.secondary('View purchase return · ${prt.id}', icon: 'file', small: true, onTap: () => openDoc(prt.id)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
              child: Text('Return status: ${prt.status}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF991B1B))),
            ),
          ] else ...[
            Btn.danger('Raise purchase return for $rejQty rejected unit(s)', icon: 'refund', small: true, onTap: () => dlgPurchaseReturn(grn)),
          ],
        ]),
      ]),
    );
  }
}

class _PoSupplierInvoiceCard extends StatelessWidget {
  final Doc po;
  final Doc inv;
  /// false on the invoice's own page (a button to open itself makes no sense)
  final bool showView;
  const _PoSupplierInvoiceCard({required this.po, required this.inv, this.showView = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.receipt_long_outlined, size: 20, color: C.blue600),
          const SizedBox(width: 8),
          const Expanded(child: Text('Supplier invoice · sent by the supplier', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          // right-aligned; a long status shortens itself on phones
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 170), child: StatusBadge(inv.status)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 20, runSpacing: 8, children: [
          _infoTile('Invoice No.', inv.supInv ?? inv.id),
          _infoTile('Invoice Date', inv.date),
          _infoTile('Invoice Amount', fmtINR(inv.amount)),
          if (inv.due != null) _infoTile('Due Date', inv.due!),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Btn('Download purchase invoice', icon: 'download', small: true, onTap: () => downloadSupplierInvoice(inv)),
          if (showView) Btn.secondary('View invoice', icon: 'eye', small: true, onTap: () => openDoc(inv.id)),
        ]),
      ]),
    );
  }

  Widget _infoTile(String label, String val) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: C.faint)),
        const SizedBox(height: 1),
        Text(val, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]);
}
