import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// A buying document shown as a clean, printed-style report (purchase request, purchase
/// order, goods receipt, purchase invoice): title and number, details as label / value
/// lines, a bordered table and totals. Nothing on it can be edited.
class DocReport extends StatelessWidget {
  final Doc d;
  const DocReport(this.d, {super.key});

  static const _titles = {
    'PR': 'PURCHASE REQUEST',
    'PO': 'PURCHASE ORDER',
    'GRN': 'GOODS RECEIPT NOTE',
    'PI': 'PURCHASE INVOICE',
    'INV': 'TAX INVOICE',
    'PRT': 'PURCHASE RETURN',
    'QT': 'QUOTATION',
    'SO': 'SALES ORDER',
  };

  Widget _info(List<(String, String)> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 140, child: Text(r.$1, style: const TextStyle(fontSize: 12.5, color: C.faint))),
              Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
          ),
      ]);

  Widget _cell(String v, {bool head = false, bool right = false, bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(head ? v.toUpperCase() : v,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
                fontSize: head ? 10.5 : 12.5,
                letterSpacing: head ? .4 : 0,
                fontWeight: head || bold ? FontWeight.w700 : FontWeight.w400,
                color: head ? C.soft : color ?? C.text)),
      );

  @override
  Widget build(BuildContext context) {
    final t = d.type;
    final custDoc = S.dt[t]!.party == 'C';
    final sup = d.party == null || custDoc ? null : S.suppliers.where((s) => s.id == d.party).firstOrNull;
    final cust = d.party == null || !custDoc ? null : S.customers.where((c) => c.id == d.party).firstOrNull;
    // sales invoice: the order and delivery note it was raised from
    final so = t == 'INV' && d.ref != null ? S.doc(d.ref!) : null;
    final dn = t == 'INV' ? S.docsOf('DN').where((x) => x.ref == d.ref || x.id == d.ref).firstOrNull : null;
    final w = S.wh(d.wh);
    final calc = S.calc(d);
    final po = (t == 'GRN' || t == 'PI') && d.ref != null ? S.doc(d.ref!) : null;
    final grn = t == 'PI' && po != null ? S.docsOf('GRN').where((g) => g.ref == po.id).firstOrNull : null;
    final qcOk = t == 'GRN' && qcDone(d);
    const border = BorderSide(color: C.border);

    final left = <(String, String)>[
      // no supplier chosen: show the rest of the details only
      if (sup != null) ...[
        ('Supplier', sup.name),
        ('GSTIN', sup.gstin),
        ('Address', '${sup.city}, ${sup.state}'),
      ],
      if (cust != null) ...[
        ('Bill to', cust.name),
        ('GSTIN', cust.gstin),
        ('Address', d.billTo ?? '${cust.city}, ${cust.state}'),
        if (d.shipTo != null && d.shipTo != d.billTo) ('Ship to', d.shipTo!),
      ],
      (t == 'GRN' ? 'Received at' : t == 'PRT' ? 'Return from' : t == 'INV' ? 'Dispatched from' : 'Deliver to', '${w.code} — ${w.name}'),
    ];
    final right = <(String, String)>[
      if (t == 'PR') ...[
        ('Request date', d.date),
        if (d.need != null) ('Required by', d.need!),
        ('Requested by', d.requester ?? (d.source ?? '').split('— ').last),
        if (d.dept != null) ('Department', d.dept!),
      ],
      if (t == 'PO') ...[
        ('PO date', d.date),
        ('Expected by', d.need ?? d.delivery ?? '—'),
        if (d.ref != null) ('Against request', d.ref!),
        ('Tax type', calc.inter ? 'IGST (inter-state)' : 'CGST + SGST (intra-state)'),
      ],
      if (t == 'GRN') ...[
        ('GRN date', d.date),
        ('PO number', d.ref ?? '—'),
        if ((d.challan ?? '').isNotEmpty) ('Supplier challan', d.challan!),
        ('Received by', (d.by ?? 'Warehouse').split(' (').first),
        ('Quality check', qcOk ? '${d.qcResult ?? 'Done'} · ${d.qcBy ?? ''}' : d.status == 'QC Requested' ? 'With the QC team' : 'Pending'),
      ],
      if (t == 'PRT') ...[
        ('Return date', d.date),
        ('GRN number', d.ref ?? '—'),
        ('PO number', (d.ref == null ? null : S.doc(d.ref!))?.ref ?? '—'),
        ('Reason', d.reason ?? '—'),
      ],
      if (t == 'INV') ...[
        ('Invoice date', d.date),
        ('Due date', d.due ?? '—'),
        ('Sales order', so?.type == 'SO' ? so!.id : '—'),
        // the customer's own purchase order number travels with the order onto the invoice
        ('Customer PO No.', ((so?.custPo ?? d.custPo) ?? '').trim().isEmpty ? '—' : (so?.custPo ?? d.custPo)!),
        if (dn != null) ('Delivery note', dn.id),
        if ((d.eway ?? '').isNotEmpty) ('E-way bill', d.eway!),
        if ((d.irn ?? '').isNotEmpty) ('e-Invoice IRN', d.irn!.length > 18 ? '${d.irn!.substring(0, 18)}…' : d.irn!),
      ],
      if (t == 'PI') ...[
        ('Supplier invoice', d.supInv ?? '—'),
        ('Invoice date', d.date),
        ('Due date', d.due ?? '—'),
        ('PO / GRN', '${po?.id ?? '—'} / ${grn?.id ?? 'not received'}'),
      ],
    ];

    // table columns per document
    final heads = t == 'GRN'
        ? ['#', 'Description', 'HSN / SAC', 'Ordered', 'Received', 'Accepted', 'Rejected']
        : ['#', 'Description', 'HSN / SAC', 'Qty', t == 'PR' ? 'Est. rate' : 'Rate', 'GST', 'Amount'];
    List<String> rowOf(Line l, int i) {
      final p = S.item(l.item);
      if (t == 'GRN') {
        final ordered = po?.lines.where((x) => x.item == l.item).firstOrNull?.qty ?? l.qty;
        // accepted / rejected are known only once the QC result is posted
        final acc = qcOk ? l.acc : null;
        final rej = qcOk ? (l.qty - l.acc) : null;
        return ['${i + 1}', '', p.hsn, '$ordered ${p.uom}', '${l.qty} ${p.uom}', acc != null ? '$acc' : 'Pending', rej != null ? '$rej' : '—'];
      }
      return ['${i + 1}', '', p.hsn, '${l.qty.abs()} ${p.uom}', fmtINR(l.rate), '${p.gst}%', fmtINR(l.qty.abs() * l.rate)];
    }

    return LayoutBuilder(builder: (ctx, c) {
      final two = c.maxWidth >= 640;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // document title: side by side, stacked on phones
        () {
          final company = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(S.currentCompany, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('GSTIN ${S.companyInfo['gstin']}', style: const TextStyle(fontSize: 12, color: C.faint)),
          ]);
          final align = two ? CrossAxisAlignment.end : CrossAxisAlignment.start;
          final title = Column(crossAxisAlignment: align, children: [
            Text(_titles[t] ?? t, textAlign: two ? TextAlign.right : TextAlign.left, style: TextStyle(fontSize: two ? 18 : 16, fontWeight: FontWeight.w800, letterSpacing: .5)),
            const SizedBox(height: 4),
            Text(d.id, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            StatusBadge(d.status),
          ]);
          if (!two) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [company, const SizedBox(height: 14), title]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: company), const SizedBox(width: 12), title]);
        }(),
        const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, thickness: 1.4, color: C.text)),
        // details
        if (two) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _info(left)), const SizedBox(width: 30), Expanded(child: _info(right))]) else ...[_info(left), _info(right)],
        if (t == 'PR' && (d.purpose ?? '').isNotEmpty) ...[const SizedBox(height: 4), _info([('Justification', d.purpose!)])],
        if (const ['PR', 'PI', 'PRT', 'QT', 'SO'].contains(t) && d.status == 'Rejected' && (d.reason ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFCA5A5))),
            child: Row(children: [
              const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Rejection Reason: ', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B), fontSize: 13)),
                  TextSpan(text: d.reason!, style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 12.5)),
                ])),
              ),
            ]),
          ),
        ],
        if (t == 'GRN' && qcOk) ...[const SizedBox(height: 4), _info([('Rejection reason', qcRejectionText(d))])],
        if (t == 'PRT' && (d.note ?? '').isNotEmpty) ...[const SizedBox(height: 4), _info([('Remarks', d.note!)])],
        if (t == 'PI' && d.match != null) ...[const SizedBox(height: 4), _info([('Verification', d.match!.msg)])],
        const SizedBox(height: 18),
        // line items
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            // phones: keep the table readable and scroll it sideways
            width: c.maxWidth < 640 ? 640 : c.maxWidth,
            child: Table(
              border: const TableBorder(top: border, bottom: border, left: border, right: border, horizontalInside: border),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {0: FixedColumnWidth(40), 1: FlexColumnWidth(3), 2: IntrinsicColumnWidth(), 3: IntrinsicColumnWidth(), 4: IntrinsicColumnWidth(), 5: IntrinsicColumnWidth(), 6: IntrinsicColumnWidth()},
              children: [
                TableRow(decoration: const BoxDecoration(color: C.bg), children: [
                  for (var i = 0; i < heads.length; i++) _cell(heads[i], head: true, right: i >= 3),
                ]),
                for (var i = 0; i < d.lines.length; i++)
                  () {
                    final l = d.lines[i];
                    final p = S.item(l.item);
                    final cells = rowOf(l, i);
                    return TableRow(children: [
                      _cell(cells[0]),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.desc ?? p.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          Text(p.id, style: const TextStyle(fontSize: 11, color: C.faint)),
                        ]),
                      ),
                      _cell(cells[2]),
                      for (var k = 3; k < cells.length; k++)
                        _cell(
                          cells[k],
                          right: true,
                          bold: (k == cells.length - 1 && t != 'GRN') || (t == 'GRN' && k == 6 && cells[6] != '—' && cells[6] != '0'),
                          color: t == 'GRN' && k == 6 && cells[6] != '—' && cells[6] != '0'
                              ? const Color(0xFFDC2626)
                              : t == 'GRN' && k == 5 && cells[5] != 'Pending' && cells[5] != '0'
                                  ? const Color(0xFF16A34A)
                                  : null,
                        ),
                    ]);
                  }(),
              ],
            ),
          ),
        ),
        // totals (not for a goods receipt)
        if (t != 'GRN') ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 280,
              child: Column(children: [
                for (final row in [('Subtotal', calc.sub), (calc.inter ? 'IGST' : 'CGST + SGST', calc.tax)])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [Expanded(child: Text(row.$1, style: const TextStyle(fontSize: 12.5, color: C.soft))), Text(fmtINR(row.$2), style: const TextStyle(fontSize: 12.5))]),
                  ),
                const Divider(height: 14, color: C.text),
                Row(children: [
                  Expanded(child: Text(t == 'PR' ? 'Estimated total' : 'Total', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                  Text(fmtINR(calc.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                // sales invoice: what has been paid and what is still due
                if (t == 'INV') ...[
                  const SizedBox(height: 8),
                  for (final row in [('Received', d.paid), ('Balance due', d.amount - d.paid)])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(child: Text(row.$1, style: TextStyle(fontSize: 12.5, color: row.$1 == 'Balance due' && row.$2 > 0 ? C.red : C.soft, fontWeight: row.$1 == 'Balance due' ? FontWeight.w700 : FontWeight.w400))),
                        Text(fmtINR(row.$2), style: TextStyle(fontSize: 12.5, color: row.$1 == 'Balance due' && row.$2 > 0 ? C.red : C.text, fontWeight: row.$1 == 'Balance due' ? FontWeight.w700 : FontWeight.w400)),
                      ]),
                    ),
                ],
              ]),
            ),
          ),
        ],
      ]);
    });
  }
}
