import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/auth.dart';
import '../core/export_builders.dart' show buildPurchaseOrderPdf;
import '../core/export_helper.dart' show viewPdf;
import '../core/store.dart';
import '../ui/overlays.dart';
import '../ui/select.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart' show downloadSupplierInvoice, downloadOrder, docCurrency, openDoc;

/// Buy › Supplier Portal: what a supplier sees after logging in.
/// After sending the goods the supplier generates its tax invoice against our purchase order;
/// the invoice then appears in Buy › Supplier Invoices for Accounts to verify and pay.
class SupplierPortalView extends StatefulWidget {
  const SupplierPortalView({super.key});
  @override
  State<SupplierPortalView> createState() => _SupplierPortalViewState();
}

String _portalSupplier = '';

class _SupplierPortalViewState extends State<SupplierPortalView> {
  String get sup {
    // a supplier login always sees its own company
    if (S.isSupplier) return S.user?.party ?? '';
    final active = S.suppliers.where((s) => s.status != 'Inactive').toList();
    if (!active.any((s) => s.id == _portalSupplier)) {
      // start with a supplier that has an order to invoice
      final withPo = active.where((s) => _toInvoice(s.id).isNotEmpty).firstOrNull;
      _portalSupplier = (withPo ?? active.firstOrNull)?.id ?? '';
    }
    return _portalSupplier;
  }

  static const _billable = ['Sent to Supplier', 'Partially Received', 'Received', 'Closed'];

  List<Doc> _pos(String s) => S.docsOf('PO').where((d) => d.party == s && _billable.contains(d.status)).toList();
  Doc? _invoiceOf(Doc po) => S.docsOf('PI').where((p) => p.ref == po.id && p.status != 'Rejected').firstOrNull;
  List<Doc> _toInvoice(String s) => _pos(s).where((po) => _invoiceOf(po) == null).toList();

  String _items(Doc d) => d.lines.map((l) => '${S.item(l.item).name} × ${l.qty} ${S.item(l.item).uom}').join(', ');

  /// The supplier confirms it has received the order and will supply it.
  void _acknowledge(Doc po) {
    po.extra['ack'] = todayStr();
    po.extra['ack_by'] = S.isSupplier ? '${S.user!.name} (${S.sup(po.party!).name})' : S.sup(po.party!).name;
    S.logDoc(po, 'Order acknowledged by the supplier', po.extra['ack_by']!);
    S.refresh();
    setState(() {});
    toast('${po.id} acknowledged · ${S.currentCompany} can see it on the order');
  }

  Future<void> _viewPo(Doc po) async => viewPdf(await buildPurchaseOrderPdf(po));

  void _generate(Doc po) {
    final s = S.sup(po.party!);
    // the invoice is in the currency the order was placed in
    final (cur, fx) = docCurrency(po);
    String money(double inr) => cur == 'INR' ? fmtINR(inr) : '$cur ${(inr / fx).toStringAsFixed(2)}';
    final prefix = s.name.split(' ').first.toUpperCase();
    final no = '${prefix.substring(0, prefix.length < 3 ? prefix.length : 3)}/INV/${4100 + S.docsOf('PI').length}';
    mform('Generate invoice · ${po.id}', [
      const F.header('Invoice'),
      F.calc('po', 'Purchase Order', def: po.id),
      F.calc('buyer', 'Bill To', def: S.currentCompany),
      F('no', 'Invoice No.', req: true, def: no),
      F('date', 'Invoice Date', type: 'date', req: true, def: todayStr()),
      const F.header('Goods sent'),
      for (final l in po.lines) ...[
        F('q_${l.item}', '${S.item(l.item).name} · Qty sent (ordered ${l.qty})', type: 'number', req: true, def: '${l.qty}'),
        F('r_${l.item}', '${S.item(l.item).name} · Rate in $cur (PO ${money(l.rate)})', type: 'number', req: true, def: (l.rate / fx).toStringAsFixed(cur == 'INR' ? 2 : 4)),
      ],
    ], (v, _) {
      final qtys = <String, int>{};
      final rates = <String, double>{};
      for (final l in po.lines) {
        final q = (v['q_${l.item}'] as num).toInt();
        if (q > l.qty) {
          toast('${S.item(l.item).name}: cannot bill more than the ${l.qty} ordered');
          return false;
        }
        qtys[l.item] = q;
        rates[l.item] = (v['r_${l.item}'] as num).toDouble() * fx; // kept in ₹
      }
      if (qtys.values.every((q) => q == 0)) {
        toast('Enter the quantity sent for at least one item');
        return false;
      }
      final r = S.supplierRaiseInvoice(po.id, (v['no'] as String).trim(), v['date'] as String, qtys, rates);
      S.refresh();
      setState(() {});
      toast(r.msg);
      return true;
    }, btn: 'Send invoice', icon: 'upload', status: 'Draft', statusNote: 'Sent to ${S.currentCompany} as Received from Supplier; they verify it against the goods received.');
  }

  Widget _row(String icon, String title, String sub, Widget? status, List<Widget> actions, {VoidCallback? onTap}) => LayoutBuilder(builder: (ctx, c) {
        // phones: the buttons go under the order instead of beside it
        final narrow = c.maxWidth < 640;
        final info = InkWell(
              onTap: onTap,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 30, height: 30, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)), child: Icon(ic(icon), size: 14, color: C.soft)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(title, style: tsB), if (status != null) status]),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 12, color: C.faint)),
                  ]),
                ),
              ]),
            );
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
          child: narrow
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  info,
                  if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8, left: 42), child: Wrap(spacing: 8, runSpacing: 6, children: actions)),
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: info),
                  if (actions.isNotEmpty) ...[const SizedBox(width: 12), Wrap(spacing: 8, runSpacing: 6, children: actions)],
                ]),
        );
      });

  Widget _section(String title, String hint, List<Widget> rows, String empty) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: CardBox(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CardHead(title, hint: hint),
            Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: rows.isEmpty ? Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Empty(empty)) : Column(children: rows)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = sup;
    if (s.isEmpty) return const Empty('No active suppliers');
    final supplier = S.sup(s);
    final pos = _pos(s);
    final invs = S.docsOf('PI').where((p) => p.party == s).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(S.isSupplier ? supplier.name : 'Supplier Portal',
          sub: S.isSupplier ? 'Purchase orders from ${S.currentCompany} · acknowledge them, then send your invoice once the goods are sent' : 'What a supplier sees after logging in: its purchase orders and the invoices it raised'),
      if (!S.isSupplier) ...[
        const NoteBox(Tone.blue, 'store', 'Demo: choose the supplier you are acting as.',
            'Each supplier logs in with its own account (e.g. supplier@andhracorrugators.com) and sees only its own orders. Invoices sent here arrive in Buy › Purchase Invoices.'),
        const SizedBox(height: 14),
      ],
      Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
        if (!S.isSupplier) SizedBox(
          width: 340,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Logged in as supplier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft)),
            const SizedBox(height: 6),
            ProtoSelect(
              value: s,
              options: [for (final x in S.suppliers.where((x) => x.status != 'Inactive')) SelOpt(x.id, x.name)],
              onChanged: (v) => setState(() => _portalSupplier = v),
            ),
          ]),
        ),
        Text('GSTIN ${supplier.gstin} · ${supplier.city}, ${supplier.state}', style: const TextStyle(fontSize: 12, color: C.faint)),
      ]),
      const SizedBox(height: 16),
      StatRow([
        Stat('Purchase orders', '${pos.length}', 'Received', 'bag', Tone.blue),
        Stat('To acknowledge', '${pos.where((p) => p.status == 'Sent to Supplier' && p.extra['ack'] == null).length}', 'New', 'bell', Tone.red, up: false),
        Stat('To invoice', '${_toInvoice(s).length}', 'Action', 'file', Tone.amber, up: false),
        Stat('Invoices sent', '${invs.length}', 'Sent', 'file', Tone.purple),
        Stat('Approved by ${S.currentCompany.split(' ').first}', '${invs.where((p) => p.status == 'Approved' || p.status == 'Paid').length}', 'Approved', 'check', Tone.green),
      ], max: 5, compact: true),
      _section(
        'Purchase orders',
        'Acknowledge each new order, then send the invoice after sending the goods',
        [
          for (final po in pos)
            () {
              final inv = _invoiceOf(po);
              return _row(
                'bag',
                '${po.id} · ${fmtINR(po.amount)}',
                '${po.date} · deliver to ${S.wh(po.wh).code} by ${po.need ?? po.delivery ?? '—'} · ${_items(po)}${po.extra['ack'] != null ? ' · acknowledged ${po.extra['ack']}' : ''}',
                po.status == 'Sent to Supplier' && po.extra['ack'] == null ? const StatusBadge('New order', tone: Tone.red) : StatusBadge(po.status),
                [
                  Btn.ghost('View PO', icon: 'eye', small: true, onTap: () => _viewPo(po)),
                  Btn.secondary('Download', icon: 'download', small: true, onTap: () => downloadOrder(po)),
                  if (po.status == 'Sent to Supplier' && po.extra['ack'] == null)
                    Btn('Acknowledge', icon: 'check', small: true, onTap: () => _acknowledge(po))
                  else if (inv == null)
                    Btn('Generate invoice', icon: 'file', small: true, onTap: () => _generate(po))
                  else
                    Text('Invoiced · ${inv.supInv ?? inv.id}', style: const TextStyle(fontSize: 12, color: C.faint)),
                ],
              );
            }(),
        ],
        'No purchase orders from ${S.currentCompany} yet.',
      ),
      _section(
        'Invoices sent',
        'Status as updated by ${S.currentCompany}',
        [
          for (final p in invs)
            _row(
              'file',
              '${p.supInv ?? p.id} · ${fmtINR(p.amount)}',
              '${p.date} · PO ${p.ref ?? '—'} · ${p.status == 'Paid' ? 'paid in full' : p.paid > 0 ? 'paid ${fmtINR(p.paid)} of ${fmtINR(p.amount)}' : 'due ${p.due ?? '—'}'} · ${p.match?.msg ?? 'Waiting for verification'}',
              StatusBadge(p.status),
              [Btn.secondary('Download', icon: 'download', small: true, onTap: () => downloadSupplierInvoice(p))],
              onTap: () => openDoc(p.id),
            ),
        ],
        'No invoices sent yet.',
      ),
    ]);
  }
}
