import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/overlays.dart';
import '../ui/select.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'attachments.dart';
import 'common.dart';

/// Goods receipt against a purchase order, laid out like the purchase order form:
/// document details on top, the order lines as a table with the quantity received,
/// then remarks. Create goods receipt posts it and shows it in the Goods Receipts list.
void openGrnForm(Doc po) => openFormPage('New Goods Receipt · from ${po.id}', GrnForm(po));

/// A created goods receipt opens as the same form, filled in as it was received and not changeable,
/// with its quality check and storage bins; the next step is the button at the bottom.
void openGrnRecord(Doc g) {
  final po = g.ref == null ? null : S.doc(g.ref!);
  openFormPage(
    'Goods Receipt · ${g.id}',
    GrnForm(po ?? g, grn: g),
    subtitle: g.status == 'QC Requested'
        ? 'This document is no longer changeable · with the QC team; the QC report appears here when they post the result'
        : qcDone(g)
            ? 'This document is no longer changeable · the QC report can be downloaded at the bottom'
            : 'This document is no longer changeable · the next step is the button at the bottom',
    headerActions: [AttachPin(g.id), const SizedBox(width: 6), IconBtn('download', () => downloadGrn(g), tip: 'Download PDF')],
    actions: (_) => actionsFor(g, nextOnly: true),
  );
}

class GrnForm extends StatefulWidget {
  final Doc po;
  /// The created receipt: the form shows it as it was filled in, read-only.
  final Doc? grn;
  const GrnForm(this.po, {super.key, this.grn});
  @override
  State<GrnForm> createState() => _GrnFormState();
}

class _GrnFormState extends State<GrnForm> {
  late String wh, receivedBy;
  final dateCtl = TextEditingController(text: todayStr());
  final vehicleCtl = TextEditingController();
  final remarksCtl = TextEditingController();
  late final List<TextEditingController> qty, batch, exp, mfg, serials;
  static const _people = ['Kiran Kumar (Warehouse)', 'Ravi Teja (Warehouse)', 'Suresh N (Stores)'];

  Doc get po => widget.po;
  Doc? get g => widget.grn;
  bool get rec => widget.grn != null;
  /// New receipt: the order lines. Created receipt: the lines it received.
  List<Line> get lines => rec ? g!.lines : po.lines;
  int _ordered(Line l) => rec ? (po.lines.where((x) => x.item == l.item).firstOrNull?.qty ?? l.qty) : l.qty;

  @override
  void initState() {
    super.initState();
    wh = rec ? g!.wh : po.wh;
    receivedBy = rec ? (g!.by ?? _people.first) : _people.first;
    TextEditingController c([String t = '']) => TextEditingController(text: t);
    qty = [for (final l in lines) c(rec ? '${l.qty}' : '${l.qty - l.recv}')];
    batch = [for (final l in lines) c(rec && S.item(l.item).track == 'Batch' ? l.batch : '')];
    exp = [for (final l in lines) c(rec ? (g!.extra['exp:${l.item}'] ?? '') : '')];
    mfg = [for (final l in lines) c(rec ? (g!.extra['mfg:${l.item}'] ?? '') : '')];
    serials = [
      for (final l in lines)
        c(rec && S.item(l.item).track == 'Serial'
            ? (l.batch.isNotEmpty ? l.batch : S.serials.where((s) => s.ref == g!.id && s.item == l.item).map((s) => s.id).join(', '))
            : '')
    ];
    if (rec) {
      dateCtl.text = g!.date;
      vehicleCtl.text = g!.vehicle ?? '';
      remarksCtl.text = g!.log.where((e) => e.what.startsWith('Remarks: ')).map((e) => e.what.substring(9)).firstOrNull ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [dateCtl, vehicleCtl, remarksCtl, ...qty, ...batch, ...exp, ...mfg, ...serials]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- fields (same look as the PO form)
  Widget _label(String label, {bool req = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: label),
          if (req) const TextSpan(text: ' *', style: TextStyle(color: C.red)),
        ]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft)),
      );

  Widget _readOnly(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        InputDecorator(decoration: const InputDecoration(), child: Text(value, style: const TextStyle(fontSize: 13, color: C.soft))),
      ]);

  Widget _text(String label, TextEditingController ctl, {bool req = false, String? hint, int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, req: req),
        TextField(
          controller: ctl,
          minLines: maxLines > 1 ? maxLines : null,
          maxLines: maxLines > 1 ? null : 1,
          keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
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
            final d = await pickDateClean(context, DateTime.tryParse(ctl.text) ?? DateTime.now());
            if (d != null) {
              setState(() => ctl.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
            }
          },
        ),
      ]);

  Widget _dd(String label, String value, List<Opt> o, void Function(String) f, {bool req = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, req: req),
        ProtoSelect(value: value, options: o.map((x) => SelOpt(x.value, x.label)).toList(), onChanged: (v) => setState(() => f(v))),
      ]);

  Widget _cell(String v, {bool head = false, bool right = false, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(head ? v.toUpperCase() : v,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontSize: head ? 10.5 : 12.5, letterSpacing: head ? .4 : 0, fontWeight: head || bold ? FontWeight.w700 : FontWeight.w400, color: head ? C.soft : C.text)),
      );

  // ---------------------------------------------------------------- save
  void _create() {
    final qs = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final p = S.item(l.item);
      final name = l.desc ?? p.name;
      final q = int.tryParse(qty[i].text.trim());
      if (q == null || q < 0) {
        toast('$name: enter the Received Qty');
        return;
      }
      final open = l.qty - l.recv;
      if (q > open) {
        toast('$name: Received Qty ($q) cannot be more than the quantity still open on the order ($open)');
        return;
      }
      if (q > 0 && p.track == 'Batch') {
        if (batch[i].text.trim().isEmpty || exp[i].text.isEmpty) {
          toast('$name: enter the Batch No. and Expiry Date');
          return;
        }
        if (exp[i].text.compareTo(todayStr()) <= 0) {
          toast('$name: Expiry Date must be after today');
          return;
        }
        if (mfg[i].text.isNotEmpty && mfg[i].text.compareTo(exp[i].text) >= 0) {
          toast('$name: Manufacture Date must be before Expiry Date');
          return;
        }
      }
      if (q > 0 && p.track == 'Serial') {
        final list = serials[i].text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
        if (list.length != q) {
          toast('$name: enter $q serial number(s) · ${list.length} entered');
          return;
        }
        // a serial number identifies one unit: no repeats in the list, none already in stock records
        final repeated = {for (final x in list) if (list.where((y) => y.toLowerCase() == x.toLowerCase()).length > 1) x};
        if (repeated.isNotEmpty) {
          toast('$name: serial number ${repeated.first} is entered twice');
          return;
        }
        final known = list.where((x) => S.serials.any((s) => s.item == p.id && s.id.toLowerCase() == x.toLowerCase())).toList();
        if (known.isNotEmpty) {
          toast('$name: serial number ${known.first} already exists');
          return;
        }
      }
      qs.add(q);
    }
    if (qs.every((q) => q == 0)) {
      toast('Enter the Received Qty for at least one item');
      return;
    }
    final res = S.poReceive(po.id, qs, '');
    final g = res.open == null ? null : S.doc(res.open!);
    if (g == null) {
      toast(res.msg);
      return;
    }
    g.date = dateCtl.text;
    g.by = receivedBy;
    if (vehicleCtl.text.trim().isNotEmpty) g.vehicle = vehicleCtl.text.trim();
    if (remarksCtl.text.trim().isNotEmpty) S.logDoc(g, 'Remarks: ${remarksCtl.text.trim()}', receivedBy);
    // keep the batch / serial numbers typed at receipt, so they appear in Batches & Serial Numbers
    for (var i = 0; i < lines.length; i++) {
      final p = S.item(lines[i].item);
      if (qs[i] <= 0) continue;
      final gl = g.lines.where((x) => x.item == p.id).firstOrNull;
      if (gl != null && p.track != 'None') gl.batch = p.track == 'Batch' ? batch[i].text.trim() : serials[i].text.trim();
      if (p.track == 'Batch') {
        g.extra['exp:${p.id}'] = exp[i].text;
        if (mfg[i].text.isNotEmpty) g.extra['mfg:${p.id}'] = mfg[i].text;
        // the same batch arriving again (another part of the order) adds to that batch instead of repeating it
        final same = S.batches.where((b) => b.id == batch[i].text.trim() && b.item == p.id && b.wh == wh).firstOrNull;
        if (same != null) {
          same.qty += qs[i];
        } else {
          S.batches.add(Batch(batch[i].text.trim(), p.id, wh, qs[i], mfg[i].text.isEmpty ? todayStr() : mfg[i].text, exp[i].text, po.party ?? '', 'Released'));
        }
      }
      if (p.track == 'Serial') {
        for (final sn in serials[i].text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty)) {
          S.serials.add(Serial(sn, p.id, wh, 'Available', g.id));
        }
      }
    }
    // show it in the Goods Receipts list
    closeAll();
    S.go(S.dt['GRN']!.view);
    S.refresh();
    toast(res.msg);
  }

  @override
  Widget build(BuildContext context) {
    final sup = po.party == null ? null : S.suppliers.where((s) => s.id == po.party).firstOrNull;
    const border = BorderSide(color: C.border);
    final qcShown = rec && qcDone(g!);
    final people = [..._people, if (!_people.contains(receivedBy)) receivedBy];
    return LayoutBuilder(builder: (ctx, c) {
      final two = c.maxWidth >= 480;
      final half = two ? (c.maxWidth - 14) / 2 : c.maxWidth;
      final form = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!rec) const FormStatusBar('Draft', 'Becomes QC Pending when created; the goods wait in the receiving area until QC.'),
        if (rec) ...[
          FormStatusBar(g!.status, 'Current status of ${g!.id}. It changes automatically as the goods go through QC and into the bins.'),
          // what happened after receipt: QC report and storage bins
          if (g!.qcSent != null)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: NoteBox(Tone.green, 'check', 'QC report ready (${g!.qcSent}).', 'Use Download QC report at the bottom.')),
          if (S.docsOf('PA').any((p) => p.ref == g!.id && p.status == 'To Do'))
            Padding(padding: const EdgeInsets.only(bottom: 12), child: NoteBox(Tone.blue, 'package', 'Next: bin allocation.', 'The accepted goods are waiting in Buy › Bin Allocation to be put into storage bins.')),
          if (qcDone(g!) && g!.lines.any((l) => l.qty > l.acc))
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NoteBox(Tone.red, 'refund', '${g!.lines.fold<int>(0, (a, l) => a + l.qty - l.acc)} unit(s) rejected at QC.', S.docsOf('PRT').where((r) => r.ref == g!.id).map((r) => r.id).isNotEmpty
                    ? 'Purchase return ${S.docsOf('PRT').where((r) => r.ref == g!.id).map((r) => r.id).join(', ')} was raised automatically · dispatch it from Buy › Purchase Returns.'
                    : 'Send them back to the supplier from Buy › Purchase Returns › New return.')),
        ],
        const SectionTitle('Document', first: true),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: half, child: _readOnly('GRN No.', rec ? g!.id : nextNo('GRN'))),
          SizedBox(width: half, child: _date('GRN Date', dateCtl, req: true)),
          SizedBox(width: half, child: _readOnly('PO No.', po.id)),
          SizedBox(width: half, child: _readOnly('PO Date', po.date)),
        ]),
        const SectionTitle('Supplier'),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: half, child: _readOnly('Supplier', sup?.name ?? '—')),
          SizedBox(width: half, child: _readOnly('Supplier GSTIN', sup?.gstin ?? '—')),
        ]),
        const SectionTitle('Receiving'),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(
              width: half,
              child: _dd('Receiving Warehouse', wh, S.warehouses.map((w) => Opt(w.id, '${w.code} — ${w.city}')).toList(), (v) => wh = v, req: true)),
          SizedBox(width: half, child: _dd('Received By', receivedBy, [for (final p in people) Opt(p, p)], (v) => receivedBy = v, req: true)),
          SizedBox(width: half, child: _text('Vehicle No.', vehicleCtl, hint: 'e.g. AP 31 TX 4410')),
        ]),
        const SectionTitle('Line Items'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: c.maxWidth < 760 ? 760 : c.maxWidth,
            child: Table(
              border: const TableBorder(top: border, bottom: border, left: border, right: border, horizontalInside: border),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {0: FixedColumnWidth(40), 1: FlexColumnWidth(3), 5: FixedColumnWidth(120)},
              children: [
                TableRow(decoration: const BoxDecoration(color: C.bg), children: [
                  _cell('#', head: true),
                  _cell('Item / Description', head: true),
                  _cell('HSN / SAC', head: true),
                  _cell('Ordered', head: true, right: true),
                  if (!rec) _cell('Already received', head: true, right: true),
                  _cell('Received qty *', head: true, right: true),
                  // after QC: what was accepted into stock and what was rejected
                  if (qcShown) ...[_cell('Accepted', head: true, right: true), _cell('Rejected', head: true, right: true)],
                  _cell('UOM', head: true),
                  _cell('Rate', head: true, right: true),
                ]),
                for (var i = 0; i < lines.length; i++)
                  TableRow(children: [
                    _cell('${i + 1}'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lines[i].desc ?? S.item(lines[i].item).name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text(lines[i].item, style: const TextStyle(fontSize: 11, color: C.faint)),
                      ]),
                    ),
                    _cell(S.item(lines[i].item).hsn),
                    _cell('${_ordered(lines[i])}', right: true),
                    if (!rec) _cell('${lines[i].recv}', right: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: TextField(
                        controller: qty[i],
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                    if (qcShown) ...[
                      _cell('${lines[i].acc}', right: true, bold: true),
                      _cell('${lines[i].qty - lines[i].acc}', right: true, bold: lines[i].qty > lines[i].acc),
                    ],
                    _cell(S.item(lines[i].item).uom),
                    _cell(fmtINR(lines[i].rate), right: true),
                  ]),
              ],
            ),
          ),
        ),
        // batch / serial details only for tracked items
        for (var i = 0; i < lines.length; i++)
          if (S.item(lines[i].item).track != 'None') ...[
            SectionTitle('${lines[i].desc ?? S.item(lines[i].item).name} · ${S.item(lines[i].item).track} details'),
            Wrap(spacing: 14, runSpacing: 14, children: [
              if (S.item(lines[i].item).track == 'Batch') ...[
                SizedBox(width: half, child: _text('Batch No.', batch[i], req: true, hint: 'From the supplier’s label')),
                SizedBox(width: half, child: _date('Expiry Date', exp[i], req: true)),
                SizedBox(width: half, child: _date('Manufacture Date', mfg[i])),
              ] else
                SizedBox(width: c.maxWidth, child: _text('Serial Nos.', serials[i], req: true, hint: 'One per unit, separated by commas')),
            ]),
          ],
        if (rec && (g!.status == 'QC Requested' || qcDone(g!))) ...[
          const SectionTitle('Quality Check'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: half, child: _readOnly('QC Status', qcDone(g!) ? 'QC done' : 'With QC team')),
            SizedBox(width: half, child: _readOnly('QC Result', qcDone(g!) ? (g!.qcResult ?? (lines.every((l) => l.acc >= l.qty) ? 'Passed' : 'Partially passed')) : '—')),
            SizedBox(width: half, child: _readOnly('Inspected By', g!.qcBy ?? '—')),
            SizedBox(width: half, child: _readOnly('QC Date', g!.qcDate ?? '—')),
            SizedBox(width: half, child: _readOnly('QC Report', g!.qcSent != null ? 'Ready · ${g!.qcSent}' : '—')),
            if (qcDone(g!)) SizedBox(width: c.maxWidth, child: _readOnly('Rejection Reason', qcRejectionText(g!))),
          ]),
        ],
        if (rec && S.binsOf(g!).isNotEmpty) ...[
          const SectionTitle('Storage Bins'),
          Wrap(spacing: 14, runSpacing: 14, children: [
            for (final e in S.binsOf(g!).entries) SizedBox(width: half, child: _readOnly(e.key, '${e.value} · ${S.wh(g!.wh).code}')),
          ]),
        ],
        const SectionTitle('Remarks'),
        _text('Remarks', remarksCtl, maxLines: 3, hint: rec ? '—' : 'e.g. 2 cartons slightly damaged on arrival'),
        if (!rec) ...[
          const SizedBox(height: 10),
          const Text('Quantities start at what is still open on the order. Change them if the delivery is short.', style: TextStyle(fontSize: 12, color: C.faint)),
          const SizedBox(height: 16),
          Wrap(alignment: WrapAlignment.end, spacing: 10, children: [
            Btn.secondary('Cancel', onTap: () => Navigator.of(context).pop()),
            Btn('Create goods receipt', icon: 'check', onTap: _create),
          ]),
        ],
      ]);
      // a created receipt is shown exactly as it was filled in, not changeable
      return rec ? IgnorePointer(child: form) : form;
    });
  }
}
