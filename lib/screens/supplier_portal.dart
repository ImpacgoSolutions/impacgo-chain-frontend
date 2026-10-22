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
import 'common.dart' show downloadSupplierInvoice, downloadOrder, docCurrency;

/// The Supplier Portal: what a supplier sees after logging in, on three screens —
/// requests for quotation (send a quotation or decline), purchase orders (accept with a delivery date, or reject
/// with a reason) and invoices (send the invoice for what was delivered, then follow it until it is paid).
/// Everything the supplier does shows up straight away on the Buy screens of the company.
enum SupplierPage { rfqs, orders, invoices }

String _portalSupplier = '';

/// The supplier the portal shows: a supplier login always sees its own company; the manager chooses one to act as.
String portalSupplier() {
  if (S.isSupplier) return S.user?.party ?? '';
  final active = S.suppliers.where((s) => s.status != 'Inactive').toList();
  if (!active.any((s) => s.id == _portalSupplier)) _portalSupplier = active.firstOrNull?.id ?? '';
  return _portalSupplier;
}

int _newest(Doc a, Doc b) => b.date.compareTo(a.date) != 0 ? b.date.compareTo(a.date) : b.id.compareTo(a.id);

/// Requests for quotation sent to this supplier.
List<Doc> supplierRfqs([String? s]) {
  final sup = s ?? portalSupplier();
  return S.docsOf('RFQ').where((r) => r.invited.contains(sup) || r.party == sup || r.quotes.any((q) => q.sup == sup)).toList()..sort(_newest);
}

bool _rfqOpen(Doc r) => r.status == 'Awaiting Quotes' || r.status == 'Quotes Received';

/// Requests still waiting for this supplier's quotation.
List<Doc> supplierToQuote() {
  final s = portalSupplier();
  return supplierRfqs(s).where((r) => _rfqOpen(r) && !r.quotes.any((q) => q.sup == s) && r.extra['decline:$s'] == null).toList();
}

/// Orders the supplier has received (not the ones still being approved inside the company).
List<Doc> supplierOrders([String? s]) {
  final sup = s ?? portalSupplier();
  const shown = ['Sent to Supplier', 'Partially Received', 'Received', 'Closed', 'Cancelled'];
  return S.docsOf('PO').where((d) => d.party == sup && shown.contains(d.status) && (d.status != 'Cancelled' || d.extra['ack'] != null || d.extra['sup_reject'] != null || d.log.any((e) => e.what.contains('Sent to Supplier')))).toList()..sort(_newest);
}

/// New orders waiting for the supplier to accept or reject.
List<Doc> supplierNewOrders() => supplierOrders().where((d) => d.status == 'Sent to Supplier' && d.extra['ack'] == null).toList();

Doc? _invoiceOf(Doc po) => S.docsOf('PI').where((p) => p.ref == po.id && p.status != 'Rejected').firstOrNull;

/// Accepted or delivered orders that have no invoice yet.
List<Doc> supplierToInvoice() => supplierOrders()
    .where((d) => const ['Sent to Supplier', 'Partially Received', 'Received', 'Closed'].contains(d.status) && (d.status != 'Sent to Supplier' || d.extra['ack'] != null) && _invoiceOf(d) == null)
    .toList();

class SupplierPortalView extends StatefulWidget {
  final SupplierPage page;
  const SupplierPortalView(this.page, {super.key});
  @override
  State<SupplierPortalView> createState() => _SupplierPortalViewState();
}

class _SupplierPortalViewState extends State<SupplierPortalView> {
  void _done(Res r) {
    S.refresh();
    setState(() {});
    toast(r.msg);
  }

  String _itemsOf(Doc d) => d.lines.map((l) => '${l.desc ?? S.item(l.item).name} × ${l.qty} ${S.item(l.item).uom}').join(', ');

  // ---------------------------------------------------------------- RFQs & quotations
  /// The supplier's own view of a request: what it still has to do, or how it ended.
  (String, Tone) _rfqState(Doc r, String s) {
    if (r.extra['decline:$s'] != null) return ('Declined', Tone.gray);
    if (r.status == 'Cancelled') return ('Closed', Tone.gray);
    if (r.status == 'Awarded') {
      final won = S.docsOf('PO').any((p) => p.ref == r.id && p.party == s && p.status != 'Cancelled');
      return won ? ('Won · order received', Tone.green) : ('Not selected', Tone.gray);
    }
    if (r.quotes.any((q) => q.sup == s)) return ('Quotation sent', Tone.blue);
    return (r.close != null && r.close!.compareTo(todayStr()) < 0 ? 'Quote overdue' : 'Quote needed', Tone.amber);
  }

  void _quote(Doc r, String s) {
    final mine = r.quotes.where((q) => q.sup == s).firstOrNull;
    final l = r.lines.first;
    final it = S.item(l.item);
    mform(mine == null ? 'Send quotation · ${r.id}' : 'Update quotation · ${r.id}', [
      const F.header('Request'),
      F.calc('rfq', 'RFQ No.', def: r.id),
      F.calc('item', 'Item', def: '${l.desc ?? it.name} (${it.id})'),
      F.calc('qty', 'Quantity', def: '${l.qty} ${it.uom}'),
      F.calc('wh', 'Deliver To', def: '${S.wh(r.wh).code} — ${S.wh(r.wh).city}'),
      F.calc('due', 'Quote Due By', def: r.close ?? '—'),
      const F.header('Your quotation'),
      F('rate', 'Rate per ${it.uom} (₹, before GST)', type: 'number', req: true, def: mine == null ? '' : mine.rate.toStringAsFixed(2)),
      F('days', 'Delivery Lead Time (days)', type: 'number', req: true, def: '${mine?.lead ?? S.sup(s).lead}'),
      F('valid', 'Quotation Valid Until', type: 'date', req: true, def: mine?.valid ?? addDays(todayStr(), 14)),
      F('note', 'Remarks', type: 'textarea', full: true, def: r.extra['qnote:$s'] ?? '', hint: 'e.g. freight included, minimum order quantity'),
    ], (v, _) {
      final rate = (v['rate'] as num).toDouble();
      if (rate <= 0) {
        toast('Enter a rate above zero');
        return false;
      }
      _done(S.supplierQuote(r.id, s, rate, (v['days'] as num).toInt(), v['valid'] as String, (v['note'] as String?) ?? ''));
      return true;
    }, btn: mine == null ? 'Send quotation' : 'Update quotation', icon: 'upload', status: mine == null ? 'Draft' : 'Sent', statusNote: 'Sent to ${S.currentCompany}; they compare the quotations and order from the best one.');
  }

  void _decline(Doc r, String s) {
    mform('Decline · ${r.id}', [
      const F('reason', 'Reason', type: 'select', req: true, full: true, custom: true, options: [
        Opt('Item not available', 'Item not available'),
        Opt('Cannot supply this quantity', 'Cannot supply this quantity'),
        Opt('Cannot meet the delivery date', 'Cannot meet the delivery date'),
        Opt('Price not workable', 'Price not workable'),
      ]),
    ], (v, _) {
      _done(S.supplierDeclineRfq(r.id, s, v['reason'] as String));
      return true;
    }, btn: 'Decline request', icon: 'x');
  }

  Widget _rfqs(String s) {
    final rfqs = supplierRfqs(s);
    final open = rfqs.where((r) => _rfqOpen(r) && r.extra['decline:$s'] == null).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StatRow([
        Stat('To quote', '${supplierToQuote().length}', 'Action', 'msg', Tone.amber, up: false),
        Stat('Quotations sent', '${rfqs.where((r) => r.quotes.any((q) => q.sup == s)).length}', 'Sent', 'upload', Tone.blue),
        Stat('Won', '${rfqs.where((r) => _rfqState(r, s).$1.startsWith('Won')).length}', 'Orders', 'check', Tone.green),
        Stat('Requests received', '${rfqs.length}', 'All', 'file', Tone.purple),
      ], max: 4, compact: true),
      _section(
        'Requests for quotation',
        'Send your price before the due date · update it while the request is open',
        [
          for (final r in rfqs)
            () {
              final st = _rfqState(r, s);
              final mine = r.quotes.where((q) => q.sup == s).firstOrNull;
              final l = r.lines.first;
              final it = S.item(l.item);
              final canQuote = open.contains(r);
              return _row(
                'msg',
                '${r.id} · ${l.desc ?? it.name} × ${l.qty} ${it.uom}',
                [
                  'Quote by ${r.close ?? '—'}',
                  'deliver to ${S.wh(r.wh).code}, ${S.wh(r.wh).city}',
                  if (mine != null) 'your quote ${fmtINR(mine.rate)} per ${it.uom} · ${mine.lead} days · valid until ${mine.valid}',
                  if (r.extra['decline:$s'] != null) 'declined: ${r.extra['decline:$s']}',
                ].join(' · '),
                StatusBadge(st.$1, tone: st.$2),
                [
                  if (canQuote && mine == null) Btn.ghost('Decline', icon: 'x', small: true, onTap: () => _decline(r, s)),
                  if (canQuote) Btn(mine == null ? 'Send quotation' : 'Update quotation', icon: mine == null ? 'upload' : 'edit', small: true, onTap: () => _quote(r, s)),
                ],
              );
            }(),
        ],
        'No requests for quotation from ${S.currentCompany} yet.',
      ),
    ]);
  }

  // ---------------------------------------------------------------- purchase orders
  (String, Tone) _poState(Doc po) {
    if (po.extra['sup_reject'] != null) return ('Rejected', Tone.gray);
    if (po.status == 'Cancelled') return ('Cancelled', Tone.gray);
    if (po.status == 'Sent to Supplier') return po.extra['ack'] == null ? ('New order', Tone.red) : ('Accepted', Tone.blue);
    if (po.status == 'Partially Received') return ('Partly delivered', Tone.amber);
    return ('Delivered', Tone.green);
  }

  void _accept(Doc po) {
    mform('Accept order · ${po.id}', [
      const F.header('Order'),
      F.calc('po', 'Purchase Order', def: po.id),
      F.calc('value', 'Order Value', def: fmtINR(po.amount)),
      F.calc('wanted', 'Wanted By', def: po.need ?? po.delivery ?? '—'),
      F.calc('to', 'Deliver To', def: '${S.wh(po.wh).code} — ${S.wh(po.wh).name}, ${S.wh(po.wh).city}'),
      const F.header('Your confirmation'),
      F('date', 'Confirmed Delivery Date', type: 'date', req: true, def: po.need ?? po.delivery ?? addDays(todayStr(), S.sup(po.party!).lead)),
      const F('note', 'Remarks', type: 'textarea', full: true, hint: 'e.g. dispatch by our own vehicle'),
    ], (v, _) {
      _done(S.supplierAcceptPo(po.id, v['date'] as String, (v['note'] as String?) ?? ''));
      return true;
    }, btn: 'Accept order', icon: 'check', status: 'New order', statusNote: 'Becomes Accepted; ${S.currentCompany} sees the confirmed delivery date on the order.');
  }

  void _reject(Doc po) {
    mform('Reject order · ${po.id}', [
      const F('reason', 'Reason', type: 'select', req: true, full: true, custom: true, options: [
        Opt('Item not available', 'Item not available'),
        Opt('Price has changed', 'Price has changed'),
        Opt('Cannot meet the delivery date', 'Cannot meet the delivery date'),
        Opt('Cannot supply this quantity', 'Cannot supply this quantity'),
      ]),
    ], (v, _) {
      _done(S.supplierRejectPo(po.id, v['reason'] as String));
      return true;
    }, btn: 'Reject order', icon: 'x', status: 'New order', statusNote: 'The order is cancelled with your reason, so ${S.currentCompany} can order from another supplier.');
  }

  Future<void> _viewPo(Doc po) async => viewPdf(await buildPurchaseOrderPdf(po));

  Widget _orders(String s) {
    final pos = supplierOrders(s);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StatRow([
        Stat('New orders', '${supplierNewOrders().length}', 'To accept', 'bell', Tone.red, up: false),
        Stat('Accepted', '${pos.where((p) => _poState(p).$1 == 'Accepted').length}', 'To deliver', 'truck', Tone.blue),
        Stat('Delivered', '${pos.where((p) => _poState(p).$1.contains('elivered')).length}', 'Received', 'check', Tone.green),
        Stat('Order value', fmtINR(pos.where((p) => p.status != 'Cancelled').fold<double>(0, (a, p) => a + p.amount)), 'All orders', 'bag', Tone.purple),
      ], max: 4, compact: true),
      _section(
        'Purchase orders',
        'Accept each new order with your delivery date, or reject it with a reason',
        [
          for (final po in pos)
            () {
              final st = _poState(po);
              return _row(
                'bag',
                '${po.id} · ${fmtINR(po.amount)}',
                [
                  po.date,
                  'deliver to ${S.wh(po.wh).code} by ${po.extra['ack_date'] ?? po.need ?? po.delivery ?? '—'}',
                  _itemsOf(po),
                  if (po.extra['ack'] != null) 'accepted ${po.extra['ack']}',
                  if (po.extra['sup_reject'] != null) 'reason: ${po.extra['sup_reject']}',
                ].join(' · '),
                StatusBadge(st.$1, tone: st.$2),
                [
                  Btn.ghost('View', icon: 'eye', small: true, onTap: () => _viewPo(po)),
                  Btn.secondary('Download', icon: 'download', small: true, onTap: () => downloadOrder(po)),
                  if (st.$1 == 'New order') ...[
                    Btn.danger('Reject', icon: 'x', small: true, onTap: () => _reject(po)),
                    Btn('Accept', icon: 'check', small: true, onTap: () => _accept(po)),
                  ],
                ],
              );
            }(),
        ],
        'No purchase orders from ${S.currentCompany} yet.',
      ),
    ]);
  }

  // ---------------------------------------------------------------- invoices
  void _generate(Doc po) {
    final s = S.sup(po.party!);
    // the invoice is in the currency the order was placed in
    final (cur, fx) = docCurrency(po);
    String money(double inr) => cur == 'INR' ? fmtINR(inr) : '$cur ${(inr / fx).toStringAsFixed(2)}';
    final prefix = s.name.split(' ').first.toUpperCase();
    final no = '${prefix.substring(0, prefix.length < 3 ? prefix.length : 3)}/INV/${4100 + S.docsOf('PI').length}';
    mform('Send invoice · ${po.id}', [
      const F.header('Invoice'),
      F.calc('po', 'Purchase Order', def: po.id),
      F.calc('buyer', 'Bill To', def: S.currentCompany),
      F('no', 'Invoice No.', req: true, def: no),
      F('date', 'Invoice Date', type: 'date', req: true, def: todayStr()),
      const F.header('Goods sent'),
      for (final l in po.lines) ...[
        F('q_${l.item}', '${l.desc ?? S.item(l.item).name} · Qty sent (ordered ${l.qty})', type: 'number', req: true, def: '${l.recv > 0 ? l.recv : l.qty}'),
        F('r_${l.item}', '${l.desc ?? S.item(l.item).name} · Rate in $cur (PO ${money(l.rate)})', type: 'number', req: true, def: (l.rate / fx).toStringAsFixed(cur == 'INR' ? 2 : 4)),
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
      if (S.supplierInvoiceExists(po.party, v['no'] as String)) {
        toast('Invoice ${(v['no'] as String).trim()} has already been sent');
        return false;
      }
      _done(S.supplierRaiseInvoice(po.id, (v['no'] as String).trim(), v['date'] as String, qtys, rates));
      return true;
    }, btn: 'Send invoice', icon: 'upload', status: 'Draft', statusNote: '${S.currentCompany} checks it against the order and the goods received, then pays it.');
  }

  /// The invoice as the supplier sees it: being checked, approved for payment, paid.
  (String, Tone) _invState(Doc p) {
    if (p.status == 'Paid') return ('Paid', Tone.green);
    if (p.paid > 0) return ('Part paid', Tone.teal);
    if (p.status == 'Approved') return ('Approved for payment', Tone.blue);
    if (p.status == 'Rejected') return ('Rejected', Tone.red);
    if (p.status == 'Pending Approval') return ('Under review', Tone.amber);
    return ('Being checked', Tone.purple);
  }

  Widget _invoices(String s) {
    final toBill = supplierToInvoice();
    final invs = S.docsOf('PI').where((p) => p.party == s).toList()..sort(_newest);
    final unpaid = invs.where((p) => p.status != 'Paid' && p.status != 'Rejected').fold<double>(0, (a, p) => a + p.amount - p.paid);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StatRow([
        Stat('To invoice', '${toBill.length}', 'Orders', 'file', Tone.amber, up: false),
        Stat('Invoices sent', '${invs.length}', 'All', 'upload', Tone.purple),
        Stat('Waiting for payment', fmtINR(unpaid), 'Unpaid', 'clock', Tone.blue),
        Stat('Paid', fmtINR(invs.fold<double>(0, (a, p) => a + p.paid)), 'Received', 'check', Tone.green),
      ], max: 4, compact: true),
      _section(
        'Orders to invoice',
        'Send the invoice once the goods are on their way',
        [
          for (final po in toBill)
            _row('bag', '${po.id} · ${fmtINR(po.amount)}', '${po.date} · ${_itemsOf(po)} · ${po.status == 'Sent to Supplier' ? 'accepted ${po.extra['ack'] ?? ''}' : po.status.toLowerCase()}', StatusBadge(_poState(po).$1, tone: _poState(po).$2), [
              Btn('Send invoice', icon: 'upload', small: true, onTap: () => _generate(po)),
            ]),
        ],
        'Nothing to invoice right now.',
      ),
      _section(
        'Invoices sent',
        'Status as updated by ${S.currentCompany}',
        [
          for (final p in invs)
            () {
              final st = _invState(p);
              return _row(
                'file',
                '${p.supInv ?? p.id} · ${fmtINR(p.amount)}',
                [
                  p.date,
                  'PO ${p.ref ?? '—'}',
                  p.status == 'Paid' ? 'paid in full' : p.paid > 0 ? 'paid ${fmtINR(p.paid)} of ${fmtINR(p.amount)}' : 'due ${p.due ?? '—'}',
                  if (p.status == 'Pending Approval' && p.match != null) p.match!.msg,
                ].join(' · '),
                StatusBadge(st.$1, tone: st.$2),
                [Btn.secondary('Download', icon: 'download', small: true, onTap: () => downloadSupplierInvoice(p))],
              );
            }(),
        ],
        'No invoices sent yet.',
      ),
    ]);
  }

  // ---------------------------------------------------------------- layout
  Widget _row(String icon, String title, String sub, Widget? status, List<Widget> actions) => LayoutBuilder(builder: (ctx, c) {
        // phones: the buttons go under the line instead of beside it
        final narrow = c.maxWidth < 640;
        final info = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)), child: Icon(ic(icon), size: 15, color: C.soft)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(title, style: tsB), if (status != null) status]),
              const SizedBox(height: 3),
              Text(sub, style: const TextStyle(fontSize: 12, color: C.faint)),
            ]),
          ),
        ]);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
          child: narrow
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  info,
                  if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10, left: 44), child: Wrap(spacing: 8, runSpacing: 6, children: actions)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: rows.isEmpty ? Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Empty(empty)) : Column(children: rows),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = portalSupplier();
    if (s.isEmpty) return const Empty('No active suppliers');
    final supplier = S.sup(s);
    const titles = {
      SupplierPage.rfqs: ('RFQs & Quotations', 'Requests for prices from'),
      SupplierPage.orders: ('Purchase Orders', 'Orders placed with you by'),
      SupplierPage.invoices: ('Invoices', 'Your invoices to'),
    };
    final (title, lead) = titles[widget.page]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title, sub: '$lead ${S.currentCompany} · ${supplier.name}'),
      // the manager acts as one supplier at a time (a supplier login always sees its own company)
      if (!S.isSupplier)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: C.blue50, borderRadius: BorderRadius.circular(R.sm), border: Border.all(color: C.border)),
            child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Icon(Icons.storefront_outlined, size: 16, color: C.blue600),
              const Text('Viewing the portal as', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              SizedBox(
                width: 260,
                child: ProtoSelect(
                  value: s,
                  options: [for (final x in S.suppliers.where((x) => x.status != 'Inactive')) SelOpt(x.id, x.name)],
                  onChanged: (v) {
                    _portalSupplier = v;
                    S.refresh();
                  },
                ),
              ),
              Text('GSTIN ${supplier.gstin} · ${supplier.city}', style: const TextStyle(fontSize: 12, color: C.faint)),
            ]),
          ),
        ),
      switch (widget.page) {
        SupplierPage.rfqs => _rfqs(s),
        SupplierPage.orders => _orders(s),
        SupplierPage.invoices => _invoices(s),
      },
    ]);
  }
}
