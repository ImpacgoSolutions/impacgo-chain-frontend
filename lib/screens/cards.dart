import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'logistics.dart' show drivers;

/// The four summary cards shown under the page title of every screen.
/// Each card counts live records, so the numbers change as work is done.
Widget screenCards(String id) {
  final c = _cards(id);
  if (c == null) return const SizedBox.shrink();
  return StatRow(c, max: 4, compact: true);
}

int _n(String t, [List<String>? st]) => S.docsOf(t).where((d) => st == null || st.contains(d.status)).length;
double _amt(String t, [List<String>? st]) => S.docsOf(t).where((d) => st == null || st.contains(d.status)).fold(0.0, (a, d) => a + d.amount);
int _qty(Iterable<Doc> ds, int Function(Line l) f) => ds.fold(0, (a, d) => a + d.lines.fold(0, (b, l) => b + f(l)));
String _q(num v) => fmtNum(v);

Stat _s(String label, String value, String badge, String icon, Tone tone, {bool up = true}) => Stat(label, value, badge, icon, tone, up: up);

List<Stat>? _cards(String id) {
  switch (id) {
    // ---------------------------------------------------------------- Buy
    case 'preqs':
      return [
        _s('Total requests', '${_n('PR')}', 'All', 'clipboard', Tone.blue),
        _s('Pending approval', '${_n('PR', ['Pending Approval'])}', 'Manager', 'clock', Tone.amber, up: false),
        _s('Approved · to order', '${_n('PR', ['Approved'])}', 'Ready', 'check', Tone.green),
        _s('Ordered', '${_n('PR', ['Ordered', 'RFQ Sent'])}', 'Done', 'bag', Tone.purple),
      ];
    case 'rfqs':
      return [
        _s('Total RFQs', '${_n('RFQ')}', 'All', 'file', Tone.blue),
        _s('Awaiting quotes', '${_n('RFQ', ['Awaiting Quotes'])}', 'Suppliers', 'clock', Tone.amber, up: false),
        _s('Quotes received', '${_n('RFQ', ['Quotes Received'])}', 'To award', 'inbox', Tone.purple),
        _s('Awarded', '${_n('RFQ', ['Awarded'])}', 'PO raised', 'check', Tone.green),
      ];
    case 'squotes':
      final rfqs = S.docsOf('RFQ').where((r) => r.quotes.isNotEmpty).toList();
      final quotes = rfqs.fold<int>(0, (a, r) => a + r.quotes.length);
      double saving = 0;
      for (final r in rfqs.where((r) => r.quotes.length > 1)) {
        final rates = r.quotes.map((q) => q.rate).toList()..sort();
        saving += (rates.last - rates.first) * (r.lines.isEmpty ? 0 : r.lines.first.qty);
      }
      final sups = {for (final r in rfqs) for (final q in r.quotes) q.sup}.length;
      return [
        _s('Quotations received', '$quotes', 'All', 'file', Tone.blue),
        _s('RFQs compared', '${rfqs.where((r) => r.quotes.length > 1).length}', '2+ quotes', 'swap', Tone.purple),
        _s('Best-price saving', fmtINR(saving), 'vs highest', 'wallet', Tone.green),
        _s('Suppliers quoted', '$sups', 'Suppliers', 'store', Tone.amber),
      ];
    case 'pinvoices':
      double approved = 0;
      for (final d in S.docsOf('PI').where((d) => d.status == 'Approved')) {
        approved += d.amount - d.paid;
      }
      return [
        _s('Waiting for goods', '${_n('PI', ['Awaiting Goods Receipt'])}', 'Auto-check', 'inbox', Tone.blue),
        _s('Differences to approve', '${_n('PI', ['Pending Approval'])}', 'Manager', 'alert', Tone.amber, up: false),
        _s('Approved for payment', '${_n('PI', ['Approved'])}', 'Finance', 'check', Tone.green),
        _s('Approved value', fmtINR(approved), 'Finance', 'wallet', Tone.purple),
      ];
    case 'porders':
      const open = ['Pending Approval', 'Sent to Supplier', 'Partially Received'];
      return [
        _s('Total POs', '${_n('PO')}', 'All', 'bag', Tone.blue),
        _s('Pending approval', '${_n('PO', ['Pending Approval'])}', 'Manager', 'clock', Tone.amber, up: false),
        _s('Waiting for goods', '${_n('PO', ['Sent to Supplier', 'Partially Received'])}', 'Receive', 'inbox', Tone.purple),
        _s('Open PO value', fmtINR(_amt('PO', open)), 'Open', 'wallet', Tone.green),
      ];
    case 'grns':
      final done = S.docsOf('GRN').where(qcDone);
      final acc = _qty(done, (l) => l.acc > 0 ? l.acc : l.qty);
      final rec = _qty(done, (l) => l.qty);
      return [
        _s('Total GRNs', '${_n('GRN')}', 'All', 'inbox', Tone.blue),
        _s('QC pending', '${_n('GRN', ['QC Pending', 'QC Requested'])}', 'Inspect', 'clock', Tone.amber, up: false),
        _s('Accepted qty', _q(acc), 'After QC', 'check', Tone.green),
        _s('Rejected qty', _q(rec - acc), 'Returned', 'refund', Tone.red, up: false),
      ];
    case 'qc':
      final done = S.docsOf('GRN').where(qcDone);
      final acc = _qty(done, (l) => l.acc);
      final rec = _qty(done, (l) => l.qty);
      return [
        _s('Waiting for QC', '${_n('GRN', ['QC Pending'])}', 'Raise on GRN', 'clock', Tone.amber, up: false),
        _s('With QC team', '${_n('GRN', ['QC Requested'])}', 'Inspect', 'checksq', Tone.blue, up: false),
        _s('Accepted qty', _q(acc), 'Into stock', 'check', Tone.green),
        _s('Rejected qty', _q(rec - acc), 'Returned', 'refund', Tone.red, up: false),
      ];
    case 'putaway':
      return [
        _s('Total tasks', '${_n('PA')}', 'All', 'package', Tone.blue),
        _s('To do', '${_n('PA', ['To Do'])}', 'Allocate', 'clock', Tone.amber, up: false),
        _s('Completed', '${_n('PA', ['Completed'])}', 'In bins', 'check', Tone.green),
        _s('Qty to allocate', _q(_qty(S.docsOf('PA').where((d) => d.status == 'To Do'), (l) => l.qty)), 'Waiting', 'box', Tone.purple),
      ];
    case 'preturns':
      return [
        _s('Total returns', '${_n('PRT')}', 'All', 'refund', Tone.blue),
        _s('To dispatch', '${_n('PRT', ['Submitted', 'Approved'])}', 'Open', 'clock', Tone.amber, up: false),
        _s('Dispatched to supplier', '${_n('PRT', ['Dispatched', 'Returned'])}', 'Sent', 'truck', Tone.green),
        _s('Return value', fmtINR(_amt('PRT')), 'All', 'wallet', Tone.purple),
      ];
    // ---------------------------------------------------------------- Sell
    case 'leads':
      return [
        _s('Total leads', '${S.leads.length}', 'All', 'target', Tone.blue),
        _s('New', '${S.leads.where((l) => l.status == 'New').length}', 'Follow up', 'clock', Tone.amber, up: false),
        _s('Contacted', '${S.leads.where((l) => l.status == 'Contacted').length}', 'In talks', 'msg', Tone.purple),
        _s('Qualified / converted', '${S.leads.where((l) => ['Qualified', 'Converted'].contains(l.status)).length}', 'Won', 'check', Tone.green),
      ];
    case 'quotes':
      return [
        _s('Total quotations', '${_n('QT')}', 'All', 'file', Tone.blue),
        _s('Draft', '${_n('QT', ['Draft'])}', 'To send', 'edit', Tone.amber, up: false),
        _s('Sent', '${_n('QT', ['Sent'])}', 'Awaiting', 'msg', Tone.purple),
        _s('Quoted value', fmtINR(_amt('QT', ['Draft', 'Sent'])), 'Open', 'wallet', Tone.green),
      ];
    case 'sorders':
      const open = ['Pending Approval', 'On Hold', 'Confirmed', 'Picking', 'Packed'];
      return [
        _s('Total orders', '${_n('SO')}', 'All', 'cart', Tone.blue),
        _s('Approval / on hold', '${_n('SO', ['Pending Approval', 'On Hold'])}', 'Manager', 'clock', Tone.amber, up: false),
        _s('Confirmed · to release', '${_n('SO', ['Confirmed'])}', 'Warehouse', 'check', Tone.purple),
        _s('Open order value', fmtINR(_amt('SO', open)), 'Open', 'wallet', Tone.green),
      ];
    case 'picking':
      return [
        _s('Pick lists', '${_n('PK')}', 'All', 'package', Tone.blue),
        _s('To pick', '${_n('PK', ['To Pick'])}', 'Pick now', 'clock', Tone.amber, up: false),
        _s('Picked', '${_n('PK', ['Picked'])}', 'Done', 'check', Tone.green),
        _s('Qty to pick', _q(_qty(S.docsOf('PK').where((d) => d.status == 'To Pick'), (l) => l.qty)), 'Units', 'box', Tone.purple),
      ];
    case 'packing':
      return [
        _s('Packing tasks', '${_n('PCK')}', 'All', 'package', Tone.blue),
        _s('To pack', '${_n('PCK', ['Packing'])}', 'Pack now', 'clock', Tone.amber, up: false),
        _s('Packed', '${_n('PCK', ['Packed'])}', 'Done', 'check', Tone.green),
        _s('Cartons packed', '${S.docsOf('PCK').fold<int>(0, (a, d) => a + (d.cartons ?? 0))}', 'Cartons', 'box', Tone.purple),
      ];
    case 'deliveries':
      return [
        _s('Deliveries', '${_n('DN')}', 'All', 'truck', Tone.blue),
        _s('Ready to dispatch', '${_n('DN', ['Ready to Dispatch'])}', 'Dispatch', 'clock', Tone.amber, up: false),
        _s('Dispatched', '${_n('DN', ['Dispatched'])}', 'On road', 'truck', Tone.purple),
        _s('Delivered', '${_n('DN', ['Delivered'])}', 'Done', 'check', Tone.green),
      ];
    case 'dtracking':
      return [
        _s('Shipments', '${_n('SHP')}', 'All', 'truck', Tone.blue),
        _s('In transit', '${_n('SHP', ['Booked', 'Picked Up', 'In Transit'])}', 'On road', 'clock', Tone.amber, up: false),
        _s('Out for delivery', '${_n('SHP', ['Out for Delivery'])}', 'Today', 'map', Tone.purple),
        _s('Delivered', '${_n('SHP', ['Delivered'])}', 'Done', 'check', Tone.green),
      ];
    case 'sreturns':
      return [
        _s('Total returns', '${_n('SR')}', 'All', 'refund', Tone.blue),
        _s('Requested', '${_n('SR', ['Requested'])}', 'Pick up', 'clock', Tone.amber, up: false),
        _s('Received back', '${_n('SR', ['Received', 'Credited'])}', 'In stock', 'check', Tone.green),
        _s('Return value', fmtINR(_amt('SR')), 'All', 'wallet', Tone.purple),
      ];
    // ---------------------------------------------------------------- Stock
    case 'ledger':
      final ins = S.ledger.where((e) => e.qty > 0).fold<int>(0, (a, e) => a + e.qty);
      final outs = S.ledger.where((e) => e.qty < 0).fold<int>(0, (a, e) => a - e.qty);
      return [
        _s('Movements', '${S.ledger.length}', 'All', 'file', Tone.blue),
        _s('Quantity in', _q(ins), 'Received', 'inbox', Tone.green),
        _s('Quantity out', _q(outs), 'Issued', 'truck', Tone.amber),
        _s('Items moved', '${{for (final e in S.ledger) e.item}.length}', 'Items', 'box', Tone.purple),
      ];
    case 'batches':
      final today = todayStr();
      return [
        _s('Batches', '${S.batches.length}', 'All', 'clipboard', Tone.blue),
        _s('Expiring in 60 days', '${S.batches.where((b) => b.exp.compareTo(today) > 0 && b.exp.compareTo(addDays(today, 60)) <= 0).length}', 'Sell first', 'clock', Tone.amber, up: false),
        _s('Expired', '${S.batches.where((b) => b.exp.isNotEmpty && b.exp.compareTo(today) <= 0).length}', 'Write off', 'alert', Tone.red, up: false),
        _s('Serial numbers', '${S.serials.length}', 'Tracked', 'tag', Tone.purple),
      ];
    case 'transfers':
      return [
        _s('Total transfers', '${_n('TR')}', 'All', 'swap', Tone.blue),
        _s('Requested', '${_n('TR', ['Requested'])}', 'To dispatch', 'clock', Tone.amber, up: false),
        _s('In transit', '${_n('TR', ['In Transit'])}', 'On road', 'truck', Tone.purple),
        _s('Received', '${_n('TR', ['Received'])}', 'Done', 'check', Tone.green),
      ];
    case 'adjust':
      return [
        _s('Total adjustments', '${_n('ADJ')}', 'All', 'sliders', Tone.blue),
        _s('Pending approval', '${_n('ADJ', ['Pending Approval'])}', 'Manager', 'clock', Tone.amber, up: false),
        _s('Posted', '${_n('ADJ', ['Posted'])}', 'Done', 'check', Tone.green),
        _s('Adjustment value', fmtINR(S.docsOf('ADJ').fold<double>(0, (a, d) => a + d.amount.abs())), 'All', 'wallet', Tone.purple),
      ];
    case 'counting':
      final variances = S.docsOf('CC').fold<int>(0, (a, d) => a + d.lines.where((l) => l.cnt != null && l.sys != null && l.cnt != l.sys).length);
      return [
        _s('Stock counts', '${_n('CC')}', 'All', 'clipboard', Tone.blue),
        _s('Counting', '${_n('CC', ['Counting'])}', 'Open', 'clock', Tone.amber, up: false),
        _s('Completed', '${_n('CC', ['Completed'])}', 'Done', 'check', Tone.green),
        _s('Differences found', '$variances', 'Adjusted', 'alert', Tone.red, up: false),
      ];
    // ---------------------------------------------------------------- Setup
    case 'params':
      return [
        _s('Branches', '${S.branches.length}', '${S.branches.where((b) => b.status == 'Active').length} active', 'home', Tone.blue),
        _s('Number series', '${S.dt.length}', 'Documents', 'tag', Tone.purple),
        _s('PO approval above', fmtINR(S.params.poApproval), 'Limit', 'bag', Tone.amber),
        _s('SO approval above', fmtINR(S.params.soApproval), 'Limit', 'cart', Tone.green),
      ];
    case 'series':
      return [
        _s('Document types', '${S.dt.length}', 'Series', 'tag', Tone.blue),
        _s('Documents created', '${S.docs.length}', 'This year', 'file', Tone.green),
        _s('Sales series', '${S.dt.values.where((t) => t.party == 'C').length}', 'Customer', 'cart', Tone.purple),
        _s('Purchase series', '${S.dt.values.where((t) => t.party == 'S').length}', 'Supplier', 'bag', Tone.amber),
      ];
    case 'tax':
      final rates = {for (final p in S.items) p.gst}.toList()..sort();
      return [
        _s('GST rates in use', '${rates.length}', rates.map((r) => '$r%').join(' · '), 'receipt', Tone.blue),
        _s('Items taxed', '${S.items.length}', 'With HSN', 'box', Tone.purple),
        _s('Company state', '${S.companyInfo['state']}', 'CGST + SGST', 'home', Tone.green),
        _s('Other states', 'IGST', 'Interstate', 'truck', Tone.amber),
      ];
    case 'warehouses':
      double value = 0;
      for (final w in S.warehouses) {
        for (final p in S.items) {
          value += S.stk(w.id, p.id).onhand * p.cost;
        }
      }
      return [
        _s('Warehouses', '${S.warehouses.length}', 'Active', 'home', Tone.blue),
        _s('Bins / locations', '${S.bins.length}', 'All', 'grid', Tone.purple),
        _s('Cities', '${{for (final w in S.warehouses) w.city}.length}', 'Locations', 'map', Tone.amber),
        _s('Stock value', fmtINR(value), 'At cost', 'wallet', Tone.green),
      ];
    case 'bins':
      return [
        _s('Bins / locations', '${S.bins.length}', 'All', 'grid', Tone.blue),
        _s('In use', '${S.bins.where((b) => b.use > 0).length}', 'Occupied', 'box', Tone.green),
        _s('Empty', '${S.bins.where((b) => b.use == 0).length}', 'Free', 'inbox', Tone.amber),
        _s('Zones', '${{for (final b in S.bins) b.zone}.length}', 'Areas', 'map', Tone.purple),
      ];
    case 'items':
    case 'itemcategories':
    case 'itemsetup':
      // items (not item × warehouse) that are below their reorder level somewhere
      final low = S.items.where((p) => S.warehouses.any((w) => S.avail(w.id, p.id) < p.reorder)).length;
      return [
        _s('Total items', '${S.items.length}', 'Active', 'box', Tone.blue),
        _s('Categories', '${S.categories.length}', 'Groups', 'grid', Tone.purple),
        _s('Batch / serial items', '${S.items.where((p) => p.track != 'None').length}', 'Tracked', 'tag', Tone.amber),
        _s('Below reorder level', '$low', 'Buy now', 'alert', Tone.red, up: false),
      ];
    case 'pricing':
      return [
        _s('Price lists', '${S.priceLists.length}', 'All', 'wallet', Tone.blue),
        _s('Active price lists', '${S.priceLists.where((p) => p.status == 'Active').length}', 'Active', 'check', Tone.green),
        _s('Trade agreements', '${S.tradeAgreements.length}', 'Special', 'file', Tone.purple),
        _s('Customer groups', '${S.customerGroups.length}', 'Groups', 'users', Tone.amber),
      ];
    case 'customers':
      return [
        _s('Total customers', '${S.customers.length}', 'All', 'users', Tone.blue),
        _s('Active', '${S.customers.where((c) => c.status == 'Active').length}', 'Buying', 'check', Tone.green),
        _s('On credit hold', '${S.customers.where((c) => ['On Hold', 'Credit Hold'].contains(c.status)).length}', 'Blocked', 'alert', Tone.red, up: false),
        _s('Total credit limit', fmtINR(S.customers.fold<double>(0, (a, c) => a + c.limit)), 'All', 'wallet', Tone.purple),
      ];
    case 'contacts':
      return [
        _s('Contacts', '${S.contacts.length}', 'All', 'users', Tone.blue),
        _s('Primary contacts', '${S.contacts.where((c) => c.primary == 'Yes').length}', 'Main', 'check', Tone.green),
        _s('Customers covered', '${{for (final c in S.contacts) c.cust}.length}', 'With contact', 'users', Tone.purple),
        _s('Without a contact', '${S.customers.where((c) => !S.contacts.any((x) => x.cust == c.id)).length}', 'Add one', 'alert', Tone.amber, up: false),
      ];
    case 'suppliers':
      final avg = S.suppliers.isEmpty ? 0 : S.suppliers.fold<int>(0, (a, s) => a + s.lead) / S.suppliers.length;
      return [
        _s('Total suppliers', '${S.suppliers.length}', 'All', 'store', Tone.blue),
        _s('Approved', '${S.suppliers.where((s) => s.status == 'Approved').length}', 'Buy from', 'check', Tone.green),
        _s('On hold', '${S.suppliers.where((s) => s.status == 'On Hold').length}', 'Blocked', 'alert', Tone.red, up: false),
        _s('Avg. lead time', '${avg.toStringAsFixed(1)} days', 'Delivery', 'clock', Tone.purple),
      ];
    case 'salespersons':
      return [
        _s('Sales persons', '${S.salesPersons.length}', 'All', 'target', Tone.blue),
        _s('Active', '${S.salesPersons.where((s) => s.status == 'Active').length}', 'Selling', 'check', Tone.green),
        _s('Territories', '${S.territories.length}', 'Areas', 'map', Tone.purple),
        _s('Quarter target', fmtINR(S.salesPersons.fold<double>(0, (a, s) => a + s.target)), 'Total', 'wallet', Tone.amber),
      ];
    case 'vehicles':
    case 'drivers':
      final soon = addDays(todayStr(), 60);
      return [
        _s('Vehicles', '${S.fleet.length}', 'Fleet', 'truck', Tone.blue),
        _s('Drivers', '${drivers.length}', 'All', 'users', Tone.purple),
        _s('Active drivers', '${drivers.where((d) => d.status == 'Active').length}', 'On duty', 'check', Tone.green),
        _s('Licence expiring', '${drivers.where((d) => d.expiry.compareTo(soon) <= 0).length}', '60 days', 'alert', Tone.amber, up: false),
      ];
  }
  return null;
}
