import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/overlays.dart';
import 'common.dart';
import 'logistics.dart' show Driver, drivers;
import 'masters.dart' show gstinOk;

/// Edit forms for master records. Each opens pre-filled with the current values;
/// "Save changes" updates the record in place.

List<String> _with(List<String> base, String current) => current.isEmpty || base.contains(current) ? base : [current, ...base];
List<String> get _terms => S.termNames;
int _days(String t) => int.tryParse(RegExp(r'\d+').firstMatch(t)?.group(0) ?? '') ?? 0;

/// "Net 30 days" → 30 ("Advance" and "Immediate" → 0). Used by every form that has Payment Terms.
int termDays(String t) => S.termDaysOf(t);

void editCustomer(Customer c) {
  mform('Edit customer · ${c.id}', [
    const F.header('Customer'),
    F('code', 'Customer Code', type: 'readonly', def: c.id),
    F('name', 'Customer Name', req: true, def: c.name),
    F('phone', 'Mobile No.', def: c.phone, hint: 'Mobile or Email required'),
    F('email', 'Email', type: 'email', def: c.email, hint: 'Mobile or Email required'),
    const F.header('GST & Address'),
    F('gst_reg', 'GST Registration Type', type: 'select', req: true, def: c.gstin == 'Unregistered' ? 'Unregistered' : 'Registered', options: opts(['Registered', 'Unregistered'])),
    F('gstin', 'GSTIN', when: 'gst_reg', whenIs: 'Registered', def: c.gstin == 'Unregistered' ? '' : c.gstin, hint: '37ABCDE1234F1Z5', help: 'First two digits must match the state'),
    F('state', 'State', type: 'select', req: true, def: c.state, options: opts(_with(kStates, c.state))),
    F('addr1', 'Billing Address', req: true, full: true, def: c.billTo.isEmpty ? '${c.name}, ${c.city}, ${c.state}' : c.billTo),
    F('ship_addr', 'Shipping Address', req: true, full: true, def: c.shipTo.isEmpty ? (c.billTo.isEmpty ? '${c.name}, ${c.city}, ${c.state}' : c.billTo) : c.shipTo, hint: 'Same as billing address if goods go there'),
    const F.header('Terms'),
    F('terms', 'Payment Terms', type: 'select', req: true, def: 'Net ${c.terms} days', options: opts(_with(_terms, 'Net ${c.terms} days'))),
    F('city', 'City', def: c.city),
    F('group', 'Customer Group', type: 'select', def: c.group, options: opts(_with(S.customerGroups.map((g) => g.name).toList(), c.group))),
    F('contact', 'Contact Person', def: c.contact),
    F('limit', 'Credit Limit (₹)', type: 'number', def: c.limit.toStringAsFixed(0)),
    F('sp', 'Sales Person', type: 'select', def: S.salesPersons.where((s) => s.terr == S.terrOf[c.id]).firstOrNull?.name ?? '', options: opts(S.salesPersons.map((s) => s.name).toList())),
    F('status', 'Status', type: 'select', def: c.status, options: opts(_with(['Active', 'On Hold', 'Credit Hold', 'Inactive'], c.status))),
  ], (v, _) {
    final g = ((v['gstin'] as String?) ?? '').trim().toUpperCase();
    if (g.isNotEmpty && !gstinOk(g, v['state'] as String)) {
      toast('GSTIN format is wrong or does not match ${v['state']}');
      return false;
    }
    c
      ..name = (v['name'] as String).trim()
      ..phone = v['phone'] as String
      ..email = (v['email'] as String).trim()
      ..contact = (v['contact'] as String).trim().isEmpty ? '—' : (v['contact'] as String).trim()
      ..gstType = v['gst_reg'] as String
      ..gstin = g.isEmpty ? 'Unregistered' : g
      ..state = v['state'] as String
      ..billTo = (v['addr1'] as String).trim()
      ..shipTo = (v['ship_addr'] as String).trim()
      ..city = (v['city'] as String).trim()
      ..group = v['group'] as String
      ..terms = _days(v['terms'] as String)
      ..limit = ((v['limit'] ?? 0) as num).toDouble()
      ..status = v['status'] as String;
    final sp = S.salesPersons.where((s) => s.name == v['sp']).firstOrNull;
    if (sp != null) S.terrOf[c.id] = sp.terr;
    S.syncCustomerAddresses(c);
    after(Res('Customer ${c.id} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editSupplier(Supplier s) {
  mform('Edit supplier · ${s.id}', [
    const F.header('Supplier'),
    F('code', 'Supplier Code', type: 'readonly', def: s.id),
    F('name', 'Supplier Name', req: true, def: s.name),
    F('phone', 'Mobile No.', def: s.phone, hint: 'Mobile or Email required'),
    F('email', 'Email', type: 'email', def: s.email, hint: 'Mobile or Email required'),
    const F.header('GST & Address'),
    F('gst_reg', 'GST Registration Type', type: 'select', req: true, def: s.gstin == 'Unregistered' ? 'Unregistered' : 'Registered', options: opts(['Registered', 'Unregistered'])),
    F('gstin', 'GSTIN', when: 'gst_reg', whenIs: 'Registered', def: s.gstin == 'Unregistered' ? '' : s.gstin, hint: '33ABCDE1234F1Z5', help: 'First two digits must match the state'),
    F('state', 'State', type: 'select', req: true, def: s.state, options: opts(_with(kStates, s.state))),
    F('addr1', 'Address', req: true, full: true, def: s.address.isEmpty ? '${s.name}, ${s.city}, ${s.state}' : s.address),
    const F.header('Terms'),
    F('terms', 'Payment Terms', type: 'select', req: true, def: 'Net ${s.terms} days', options: opts(_with(_terms, 'Net ${s.terms} days'))),
    F('city', 'City', def: s.city),
    F('contact', 'Contact Person', def: s.contact),
    F('lead', 'Lead Time (days)', type: 'number', def: '${s.lead}'),
    F('status', 'Status', type: 'select', def: s.status, options: opts(_with(['Approved', 'On Probation', 'On Hold', 'Inactive'], s.status))),
  ], (v, _) {
    final g = ((v['gstin'] as String?) ?? '').trim().toUpperCase();
    if (g.isNotEmpty && !gstinOk(g, v['state'] as String)) {
      toast('GSTIN format is wrong or does not match ${v['state']}');
      return false;
    }
    s
      ..name = (v['name'] as String).trim()
      ..phone = v['phone'] as String
      ..email = (v['email'] as String).trim()
      ..address = (v['addr1'] as String).trim()
      ..gstType = v['gst_reg'] as String
      ..contact = (v['contact'] as String).trim().isEmpty ? '—' : (v['contact'] as String).trim()
      ..gstin = g.isEmpty ? 'Unregistered' : g
      ..state = v['state'] as String
      ..city = (v['city'] as String).trim()
      ..terms = _days(v['terms'] as String)
      ..lead = ((v['lead'] ?? 0) as num).toInt()
      ..status = v['status'] as String;
    after(Res('Supplier ${s.id} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editItem(Item p) {
  final hasStock = S.warehouses.any((w) => S.stk(w.id, p.id).onhand != 0);
  mform('Edit item · ${p.id}', [
    const F.header('Item'),
    F('code', 'Item Code', type: 'readonly', def: p.id),
    F('name', 'Item Name', req: true, def: p.name),
    F('type', 'Item Type', type: 'select', req: true, def: p.type, options: opts(['Goods', 'Service'])),
    F('cat', 'Category', type: 'select', req: true, def: p.cat, options: opts(_with(S.categories, p.cat))),
    F('uom', 'UOM', type: 'select', req: true, def: p.uom, options: S.uoms.map((u) => Opt(u.code, '${u.code} · ${u.name}')).toList()),
    F('hsn', 'HSN Code', req: true, def: p.hsn),
    F('gst', 'Tax Code', type: 'select', req: true, def: S.taxNameFor(p.gst), options: opts(S.taxNames)),
    hasStock
        ? F('track', 'Tracking', type: 'readonly', def: p.track)
        : F('track', 'Tracking', type: 'select', req: true, def: p.track, options: opts(['None', 'Batch', 'Serial'])),
    const F.header('Price & Stock'),
    F('cost', 'Purchase Price (₹)', type: 'number', req: true, def: p.cost.toStringAsFixed(2)),
    F('price', 'Selling Price (₹)', type: 'number', req: true, def: p.price.toStringAsFixed(2)),
    F('shelf_life', 'Shelf Life (days)', type: 'number', when: 'track', whenIs: 'Batch', def: p.shelfLife == 0 ? '' : '${p.shelfLife}', hint: 'Used to calculate expiry at GRN'),
    F('sup', 'Preferred Supplier', type: 'select', req: true, def: p.sup, options: S.suppliers.map((s) => Opt(s.id, s.name)).toList()),
    F('reorder', 'Reorder Level', type: 'number', def: '${p.reorder}'),
    F('moq', 'Min Order Qty', type: 'number', def: '${p.moq}'),
    F('lead', 'Lead Time (days)', type: 'number', def: '${p.lead}'),
    F('status', 'Status', type: 'select', def: p.status, options: opts(['Active', 'Inactive', 'Discontinued'])),
  ], (v, _) {
    final cost = ((v['cost'] ?? 0) as num).toDouble(), price = ((v['price'] ?? 0) as num).toDouble();
    if (price < cost) {
      toast('Selling Price is below Purchase Price — check the values');
      return false;
    }
    p
      ..name = (v['name'] as String).trim()
      ..type = v['type'] as String
      ..cat = v['cat'] as String
      ..uom = v['uom'] as String
      ..hsn = v['hsn'] as String
      ..gst = S.taxRateOf(v['gst'] as String).round()
      ..track = v['track'] as String
      ..cost = cost
      ..price = price
      ..shelfLife = ((v['shelf_life'] ?? 0) as num).toInt()
      ..sup = v['sup'] as String
      ..reorder = ((v['reorder'] ?? 0) as num).toInt()
      ..moq = ((v['moq'] ?? 0) as num).toInt()
      ..lead = ((v['lead'] ?? 0) as num).toInt()
      ..status = v['status'] as String;
    after(Res('Item ${p.id} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check', note: hasStock ? 'Tracking cannot change while the item has stock.' : null);
}

void editWarehouse(Warehouse w) {
  mform('Edit warehouse · ${w.code}', [
    const F.header('Warehouse'),
    F('code', 'Warehouse Code', type: 'readonly', def: w.code),
    F('name', 'Warehouse Name', req: true, def: w.name),
    F('branch', 'Branch', type: 'select', req: true, def: w.branch.isEmpty ? '${w.city} Branch' : w.branch, options: opts(_with(S.warehouses.map((x) => '${x.city} Branch').toSet().toList(), w.branch.isEmpty ? '${w.city} Branch' : w.branch))),
    F('city', 'City', req: true, def: w.city),
    F('state', 'State', type: 'select', req: true, def: w.state, options: opts(_with(kStates, w.state))),
    F('site', 'Site', type: 'select', def: w.site, options: [const Opt('', '— none —'), ...S.sites.map((s) => Opt(s.id, s.name))]),
    F('type', 'Type', type: 'select', def: w.type, options: opts(_with(['Central Fulfillment', 'Regional Hub', 'Transit Depot', 'Raw Material Store'], w.type))),
    F('mgr', 'Manager', def: w.manager),
    F('cap', 'Capacity', def: w.area, hint: 'e.g. 50,000 sq ft'),
    F('status', 'Status', type: 'select', def: w.status, options: opts(_with(['Active', 'Inactive'], w.status))),
  ], (v, _) {
    final i = S.warehouses.indexWhere((x) => x.id == w.id);
    final nw = Warehouse(w.id, w.code, (v['name'] as String).trim(), (v['city'] as String).trim(), v['state'] as String, w.gstin, (v['mgr'] as String).trim().isEmpty ? 'Manager' : (v['mgr'] as String).trim(), v['type'] as String,
        (v['cap'] as String).trim().isEmpty ? w.area : (v['cap'] as String).trim(), w.docks, v['status'] as String, w.wms,
        branch: v['branch'] as String, site: v['site'] as String);
    S.warehouses[i] = nw;
    if (S.currentWh.id == w.id) S.currentWh = nw;
    after(Res('Warehouse ${w.code} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

/// Choose a warehouse, then edit it.
void editWarehousePick() {
  mform('Edit warehouse', [
    F('wh', 'Warehouse', type: 'select', req: true, def: S.currentWh.id, full: true, options: S.warehouses.map((w) => Opt(w.id, '${w.code} — ${w.name}')).toList()),
  ], (v, ctx) {
    Future.microtask(() => editWarehouse(S.wh(v['wh'] as String)));
    return true;
  }, btn: 'Continue', icon: 'edit');
}

void editBin(Bin b) {
  mform('Edit bin · ${b.code}', [
    const F.header('Bin'),
    F('wh', 'Warehouse', type: 'readonly', def: '${S.wh(b.wh).code} — ${S.wh(b.wh).city}'),
    F('code', 'Bin Code', type: 'readonly', def: b.code),
    F('zone', 'Zone', type: 'select', req: true, def: b.zone, options: opts(_with(['A · Picking Area', 'B · Bulk storage', 'Receiving dock', 'Quarantine', 'Dispatch bay'], b.zone))),
    F('type', 'Bin Type', type: 'select', req: true, def: b.type, options: opts(_with(['Picking', 'Reserve', 'Inbound staging', 'QC hold / damaged', 'Outbound staging'], b.type))),
    F('cap', 'Capacity', def: b.cap),
    F('status', 'Status', type: 'select', def: b.status, options: opts(_with(['Active', 'Inactive'], b.status))),
  ], (v, _) {
    b
      ..zone = v['zone'] as String
      ..type = v['type'] as String
      ..cap = (v['cap'] as String).trim().isEmpty ? b.cap : (v['cap'] as String).trim()
      ..status = v['status'] as String;
    after(Res('Bin ${b.code} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editPriceList(PriceList p) {
  mform('Edit price list · ${p.id}', [
    const F.header('Price List'),
    F('name', 'Price List Name', req: true, def: p.name),
    F('group', 'Customer Group', type: 'select', req: true, def: p.group, options: opts(_with(S.customerGroups.map((g) => g.name).toList(), p.group))),
    F('disc', 'Discount on Base Price %', type: 'number', req: true, def: '${p.disc}'),
    F('valid', 'Validity', req: true, def: p.valid),
    F('status', 'Status', type: 'select', req: true, def: p.status, options: opts(_with(['Active', 'Inactive', 'Draft'], p.status))),
  ], (v, _) {
    p
      ..name = v['name'] as String
      ..group = v['group'] as String
      ..disc = ((v['disc'] ?? 0) as num).toInt()
      ..valid = v['valid'] as String
      ..status = v['status'] as String;
    after(Res('Price list ${p.id} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editContact(Contact c) {
  mform('Edit contact · ${c.name}', [
    const F.header('Contact'),
    F('cust', 'Customer', type: 'select', req: true, def: c.cust, options: S.customers.map((x) => Opt(x.id, x.name)).toList()),
    F('name', 'Contact Name', req: true, def: c.name),
    F('phone', 'Mobile No.', req: true, def: c.phone),
    F('role', 'Designation', def: c.role),
    F('email', 'Email', type: 'email', def: c.email),
    F('primary', 'Primary Contact', type: 'select', def: c.primary, options: opts(['No', 'Yes'])),
  ], (v, _) {
    if (v['primary'] == 'Yes') {
      for (final x in S.contacts) {
        if (x.cust == v['cust'] && x != c) x.primary = 'No';
      }
    }
    c
      ..cust = v['cust'] as String
      ..name = v['name'] as String
      ..phone = v['phone'] as String
      ..role = (v['role'] as String).isEmpty ? 'Contact' : v['role'] as String
      ..email = v['email'] as String
      ..primary = v['primary'] as String;
    after(Res('Contact ${c.name} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editSalesPerson(SalesPerson s) {
  mform('Edit sales person · ${s.id}', [
    const F.header('Sales Person'),
    F('name', 'Name', req: true, def: s.name),
    F('phone', 'Mobile No.', req: true, def: s.phone),
    F('email', 'Email', type: 'email', def: s.email, hint: 'name@impacgo.com'),
    F('terr', 'Territory', type: 'select', def: s.terr, options: S.territories.map((t) => Opt(t.id, t.name)).toList()),
    F('target', 'Quarterly Target (₹)', type: 'number', def: s.target.toStringAsFixed(0)),
    F('status', 'Status', type: 'select', def: s.status, options: opts(_with(['Active', 'Inactive'], s.status))),
  ], (v, _) {
    s
      ..name = (v['name'] as String).trim()
      ..phone = v['phone'] as String
      ..email = (v['email'] as String).trim()
      ..terr = v['terr'] as String
      ..target = ((v['target'] ?? 0) as num).toDouble()
      ..status = v['status'] as String;
    after(Res('Sales person ${s.id} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editVehicle(Vehicle v0) {
  mform('Edit vehicle · ${v0.id}', [
    const F.header('Vehicle'),
    F('name', 'Vehicle No. / Name', req: true, def: v0.name),
    F('wh', 'Home Warehouse', type: 'select', req: true, def: v0.wh, options: S.warehouses.map((w) => Opt(w.id, w.code)).toList()),
    F('driver', 'Assigned Driver', type: 'select', req: true, def: v0.driver, options: opts(_with(['Unassigned', ...drivers.where((d) => d.status != 'Inactive').map((d) => d.name)], v0.driver))),
    F('type', 'Vehicle Type', type: 'readonly', def: v0.type),
    F('own', 'Ownership', type: 'select', def: v0.own, options: opts(['Own', 'Leased', 'Carrier'])),
    F('status', 'Status', type: 'select', req: true, def: v0.status, options: opts(['Available', 'Assigned', 'On Route', 'Under Maintenance'])),
    F('cap', 'Capacity', def: v0.cap),
  ], (v, _) {
    final old = v0.name;
    v0
      ..name = (v['name'] as String).trim()
      ..wh = v['wh'] as String
      ..driver = v['driver'] as String
      ..own = v['own'] as String
      ..status = v['status'] as String
      ..cap = (v['cap'] as String).trim().isEmpty ? v0.cap : (v['cap'] as String).trim();
    final i = S.vehicles.indexOf(old);
    if (i >= 0) S.vehicles[i] = v0.name;
    after(Res('Vehicle ${v0.id} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editDriver(Driver d) {
  mform('Edit driver · ${d.name}', [
    const F.header('Driver'),
    F('name', 'Driver Name', req: true, def: d.name),
    F('phone', 'Mobile No.', req: true, def: d.phone),
    F('licence', 'Licence No.', req: true, def: d.licence),
    F('expiry', 'Licence Expiry', type: 'date', def: d.expiry),
    F('address', 'Address', full: true, def: d.address),
    F('status', 'Status', type: 'select', def: d.status, options: opts(_with(['Active', 'On Leave', 'Inactive'], d.status))),
  ], (v, _) {
    d
      ..name = (v['name'] as String).trim()
      ..phone = v['phone'] as String
      ..licence = (v['licence'] as String).trim()
      ..expiry = v['expiry'] as String
      ..address = (v['address'] as String).trim()
      ..status = v['status'] as String;
    after(Res('Driver ${d.name} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

/// Lead sources in the dropdown; a source typed with "Other" is added here for the next lead.
final leadSources = <String>['Website enquiry', 'Referral', 'Trade show', 'Cold call'];
void rememberLeadSource(String s) {
  if (s.trim().isNotEmpty && !leadSources.contains(s)) leadSources.add(s);
}

/// [record] opens the lead as its own page (the form it was created with): [extra] are the next-step buttons,
/// [headerActions] the icons at the top, and [onSaved] runs after saving instead of closing the page.
void editLead(Lead l, {bool record = false, bool readOnly = false, List<Widget> Function(BuildContext)? extra, List<Widget> headerActions = const [], VoidCallback? onSaved}) {
  mform(record ? '${l.company} · ${l.id}' : 'Edit lead · ${l.id}', [
    const F.header('Lead'),
    F('date', 'Lead Date', type: 'date', req: true, def: l.date),
    F('co', 'Company Name', req: true, def: l.company),
    F('ct', 'Contact Person', req: true, def: l.contact),
    F('phone', 'Mobile No.', def: l.phone, hint: 'Mobile or Email required'),
    F('email', 'Email', type: 'email', def: l.email, hint: 'Mobile or Email required'),
    F('src', 'Lead Source', type: 'select', req: true, custom: true, def: l.source, options: opts(_with(leadSources, l.source))),
    F('owner', 'Sales Person', type: 'select', req: true, def: l.owner, options: opts(_with(S.salesPersons.where((s) => s.status != 'Inactive').map((s) => s.name).toList(), l.owner))),
    F('city', 'City', req: true, def: l.city),
    F('st', 'State', type: 'select', req: true, def: l.state, options: opts(_with(kStates, l.state))),
    F('item', 'Product Interest', type: 'select', req: true, def: l.interest, options: S.items.map((p) => Opt(p.id, p.name)).toList()),
    F('val', 'Estimated Value (₹)', type: 'number', req: true, def: l.value.toStringAsFixed(0)),
    F('status', 'Status', type: 'select', req: true, def: l.status, options: opts(_with(['New', 'Contacted', 'Qualified', 'Unqualified', 'Lost'], l.status))),
    if (l.opp != null) F('opp_ref', 'Opportunity', type: 'readonly', def: l.opp!),
    if (l.status == 'Lost' && l.lostReason != null) F('lost_reason_view', 'Lost Reason', type: 'readonly', full: true, def: l.lostReason!),
  ], (v, _) {
    final phone = (v['phone'] as String).trim(), email = (v['email'] as String).trim();
    if ((phone.isEmpty || phone == '+91') && email.isEmpty && (l.phone.isNotEmpty || l.email.isNotEmpty)) {
      toast('Enter a mobile number or an email');
      return false;
    }
    l
      ..date = v['date'] as String
      ..company = v['co'] as String
      ..contact = v['ct'] as String
      ..phone = phone
      ..email = email
      ..source = v['src'] as String
      ..owner = v['owner'] as String
      ..city = (v['city'] as String).isEmpty ? l.city : v['city'] as String
      ..state = (v['st'] as String).isEmpty ? l.state : v['st'] as String
      ..interest = (v['item'] as String).isEmpty ? l.interest : v['item'] as String
      ..value = ((v['val'] ?? 0) as num).toDouble()
      ..status = v['status'] as String;
    rememberLeadSource(l.source);
    if (onSaved != null) {
      onSaved();
    } else {
      after(Res('Lead ${l.id} updated'));
    }
    return false;
  }, btn: 'Save changes', icon: 'check', extra: extra, headerActions: headerActions, cancel: !record, readOnly: readOnly);
}

void editOpp(Opportunity o, {bool record = false, bool readOnly = false, List<Widget> Function(BuildContext)? extra, List<Widget> headerActions = const [], VoidCallback? onSaved}) {
  final line = o.lines.firstOrNull;
  // the same fields, in the same order, as the form the opportunity was created with
  mform(record ? '${o.title} · ${o.id}' : 'Edit opportunity · ${o.id}', [
    const F.header('Opportunity'),
    F('opp_no', 'Opportunity No.', type: 'readonly', def: o.id),
    F('cust', 'Customer', type: 'readonly', def: S.cust(o.party).name),
    F('title', 'Opportunity Name', req: true, def: o.title),
    F('owner', 'Sales Person', type: 'select', req: true, def: o.owner, options: opts(_with(S.salesPersons.where((s) => s.status != 'Inactive').map((s) => s.name).toList(), o.owner))),
    F('val', 'Estimated Value (₹)', type: 'number', req: true, def: o.value.toStringAsFixed(0)),
    F('close', 'Expected Close Date', type: 'date', req: true, def: o.close),
    F('stage', 'Stage', type: 'select', req: true, custom: true, def: o.stage, options: opts(_with(['Prospecting', 'Proposal', 'Proposal Sent', 'Negotiation'], o.stage))),
    F('prob', 'Win Probability (%)', type: 'number', def: '${o.prob}'),
    F('lead_ref', 'Lead Ref.', type: 'readonly', def: o.lead ?? '—'),
    const F.header('Line Item'),
    F('item', 'Product', type: 'select', req: true, def: line?.item ?? '', options: S.items.map((p) => Opt(p.id, '${p.name} (${p.id})')).toList()),
    F('qty', 'Qty', type: 'number', req: true, def: '${line?.qty ?? 1}'),
    if (o.quote != null) F('quote_ref', 'Quotation', type: 'readonly', def: o.quote!),
    if (o.stage == 'Lost' && o.lostReason != null) F('lost_reason_view', 'Lost Reason', type: 'readonly', full: true, def: o.lostReason!),
  ], (v, _) {
    final item = v['item'] as String, qty = ((v['qty'] ?? 1) as num).toInt();
    if (o.lines.isEmpty) {
      o.lines.add(OppLine(item, qty));
    } else {
      o.lines.first
        ..item = item
        ..qty = qty;
    }
    o
      ..title = v['title'] as String
      ..value = ((v['val'] ?? 0) as num).toDouble()
      ..close = v['close'] as String
      ..stage = v['stage'] as String
      ..owner = v['owner'] as String
      ..prob = ((v['prob'] ?? 0) as num).toInt();
    if (onSaved != null) {
      onSaved();
    } else {
      after(Res('Opportunity ${o.id} updated'));
    }
    return false;
  }, btn: 'Save changes', icon: 'check', extra: extra, headerActions: headerActions, cancel: !record, readOnly: readOnly);
}

void editCustomerGroup(CustomerGroup g) {
  final terms = S.termNames;
  mform('Edit customer group · ${g.id}', [
    const F.header('General'),
    F('name', 'Group Name', req: true, def: g.name),
    F('parent', 'Parent Group', def: g.parent),
    F('desc', 'Description', full: true, def: g.desc == '—' ? '' : g.desc),
    F('price', 'Default Price List', type: 'select', def: g.price, options: S.priceLists.map((p) => Opt(p.id, '${p.name}${p.disc > 0 ? ' (−${p.disc}%)' : ''}')).toList()),
    F('terms', 'Default Payment Terms', type: 'select', def: g.terms == 0 ? 'Advance' : 'Net ${g.terms} days', options: opts(_with(terms, g.terms == 0 ? 'Advance' : 'Net ${g.terms} days'))),
    F('credit', 'Default Credit Limit (₹)', type: 'number', def: g.credit.toStringAsFixed(0)),
    F('status', 'Status', type: 'select', req: true, def: g.status, options: opts(['Active', 'Inactive'])),
  ], (v, _) {
    final name = (v['name'] as String).trim();
    if (S.customerGroups.any((x) => x != g && x.name == name)) {
      toast('A group called "$name" already exists');
      return false;
    }
    // customers keep their group by name, so a renamed group takes its customers with it
    if (name != g.name) {
      for (final c in S.customers.where((c) => c.group == g.name)) {
        c.group = name;
      }
    }
    final t = v['terms'] as String;
    g
      ..name = name
      ..parent = (v['parent'] as String).trim()
      ..status = v['status'] as String
      ..desc = (v['desc'] as String).trim().isEmpty ? '—' : (v['desc'] as String).trim()
      ..price = v['price'] as String
      ..terms = t == 'Advance' ? 0 : int.tryParse(t.split(' ')[1]) ?? g.terms
      ..credit = ((v['credit'] ?? g.credit) as num).toDouble();
    after(Res('Group $name updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editCategory(String old) {
  mform('Edit item category', [
    const F.header('Category'),
    F('name', 'Category Name', req: true, def: old),
  ], (v, _) {
    final name = (v['name'] as String).trim();
    if (name != old && S.categories.contains(name)) {
      toast('Category already exists');
      return false;
    }
    // items keep their category by name, so a renamed category takes its items with it
    final i = S.categories.indexOf(old);
    if (i >= 0) S.categories[i] = name;
    for (final p in S.items.where((p) => p.cat == old)) {
      p.cat = name;
    }
    after(Res('Category renamed to $name'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editUom(Uom u) {
  mform('Edit unit of measure · ${u.code}', [
    const F.header('Unit of Measure'),
    F('code', 'UOM Code', type: 'readonly', def: u.code),
    F('name', 'UOM Name', req: true, def: u.name),
    F('type', 'UOM Type', type: 'select', def: u.type, options: opts(_with(['Count', 'Pack', 'Weight', 'Volume', 'Length'], u.type))),
    F('base', 'Base UOM', def: u.base),
    F('factor', 'Conversion to Base', type: 'number', def: u.factor % 1 == 0 ? '${u.factor.toInt()}' : '${u.factor}'),
  ], (v, _) {
    u
      ..name = (v['name'] as String).trim()
      ..type = v['type'] as String
      ..base = (v['base'] as String).trim().isEmpty ? u.base : (v['base'] as String).trim()
      ..factor = ((v['factor'] ?? u.factor) as num).toDouble();
    after(Res('Unit ${u.code} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editTerritory(Territory t) {
  final people = S.salesPersons.where((s) => s.status != 'Inactive').map((s) => s.name).toList();
  mform('Edit territory · ${t.id}', [
    const F.header('General'),
    F('name', 'Territory Name', req: true, def: t.name),
    F('code', 'Territory Code', def: t.code, hint: 'e.g. TER-05'),
    F('parent', 'Parent Territory', type: 'select', def: t.parent, options: opts(_with(['—', ...S.territories.where((x) => x != t).map((x) => x.name)], t.parent))),
    F('country', 'Country', def: t.country),
    F('states', 'States Covered', req: true, def: t.states),
    F('cities', 'Key Cities', req: true, full: true, def: t.cities),
    F('mgr', 'Territory Manager', type: 'select', def: t.manager, options: opts(_with(people, t.manager))),
    F('wh', 'Dispatch Warehouse', type: 'select', def: t.wh, options: S.warehouses.map((w) => Opt(w.id, w.code)).toList()),
    F('target_rev', 'Target Revenue (₹)', type: 'number', def: t.targetRev == 0 ? '' : t.targetRev.toStringAsFixed(0)),
    F('status', 'Status', type: 'select', def: t.status, options: opts(['Active', 'Inactive'])),
  ], (v, _) {
    t
      ..name = (v['name'] as String).trim()
      ..code = (v['code'] as String).trim()
      ..parent = v['parent'] as String
      ..country = (v['country'] as String).trim().isEmpty ? 'India' : (v['country'] as String).trim()
      ..states = (v['states'] as String).trim()
      ..cities = (v['cities'] as String).trim()
      ..manager = v['mgr'] as String
      ..wh = v['wh'] as String
      ..targetRev = ((v['target_rev'] ?? 0) as num).toDouble()
      ..status = v['status'] as String;
    after(Res('Territory ${t.name} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

/// Creates a number series for a document type. A document type uses one series at a time: either the new one
/// becomes the active series right away (the old one is kept, and can be made active again), or it is saved to use later.
void newNumberSeriesForm() {
  mform('New number series', [
    const F.header('Number Series'),
    F('doc', 'Document Type', type: 'select', req: true, options: [for (final e in S.dt.entries) Opt(e.key, titleCase(e.value.label))]),
    const F('prefix', 'Prefix', req: true, hint: 'e.g. SO-2027-'),
    const F('next', 'Starting Number', type: 'number', req: true, def: '1'),
    F('active', 'Use it now', type: 'select', req: true, def: 'Yes', options: opts(['Yes', 'No']),
        help: 'Yes: the next documents use this series. The current one is kept and can be made active again. No: save it to use later.'),
  ], (v, _) {
    final key = v['doc'] as String;
    final d = S.dt[key]!;
    final prefix = (v['prefix'] as String).trim();
    final next = ((v['next'] ?? 1) as num).toInt();
    if (next < 1) {
      toast('Starting Number must be 1 or more');
      return false;
    }
    if (prefix == d.prefix || S.seriesList.any((x) => x.key == key && x.prefix == prefix)) {
      toast('${titleCase(d.label)} already has a series with the prefix $prefix');
      return false;
    }
    if (v['active'] == 'Yes') {
      S.seriesList.add(SeriesEntry(key, d.prefix, d.seq)); // the series that was in use is kept
      d
        ..prefix = prefix
        ..seq = next - 1;
    } else {
      S.seriesList.add(SeriesEntry(key, prefix, next - 1));
    }
    after(Res('Number series $prefix${next.toString().padLeft(4, '0')} created for ${d.label}${v['active'] == 'Yes' ? ' · now in use' : ''}'));
    return false;
  }, btn: 'Save series', icon: 'check');
}

/// Edit a saved (not active) number series.
void editSeriesEntry(SeriesEntry e) {
  mform('Edit number series · ${titleCase(S.dt[e.key]!.label)}', [
    const F.header('Number Series'),
    F('prefix', 'Prefix', req: true, def: e.prefix),
    F('next', 'Next Number', type: 'number', req: true, def: '${e.seq + 1}'),
  ], (v, _) {
    final prefix = (v['prefix'] as String).trim();
    final next = ((v['next'] ?? 1) as num).toInt();
    if (next < 1) {
      toast('Next Number must be 1 or more');
      return false;
    }
    if (prefix != e.prefix && (prefix == S.dt[e.key]!.prefix || S.seriesList.any((x) => x != e && x.key == e.key && x.prefix == prefix))) {
      toast('${titleCase(S.dt[e.key]!.label)} already has a series with the prefix $prefix');
      return false;
    }
    e
      ..prefix = prefix
      ..seq = next - 1;
    after(Res('Number series updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

/// Makes a saved series the one in use; the series that was in use is kept in its place.
void activateSeries(SeriesEntry e) {
  final d = S.dt[e.key]!;
  final old = SeriesEntry(e.key, d.prefix, d.seq);
  d
    ..prefix = e.prefix
    ..seq = e.seq;
  final i = S.seriesList.indexOf(e);
  S.seriesList[i] = old;
  after(Res('${titleCase(d.label)} now uses ${e.prefix}${(e.seq + 1).toString().padLeft(4, '0')} next'));
}

/// Number series: change the text a document number starts with, and the number the next document gets.
void editNumberSeries(String key, DocType d) {
  mform('Edit number series · ${d.label}', [
    const F.header('Number Series'),
    F('prefix', 'Prefix', req: true, def: d.prefix, hint: 'e.g. SO-2026-'),
    F('next', 'Next Number', type: 'number', req: true, def: '${d.seq + 1}', help: 'The next document gets this number (4 digits). With the same prefix it cannot go below ${d.seq + 1}, or numbers would repeat.'),
  ], (v, _) {
    final prefix = (v['prefix'] as String).trim();
    final next = ((v['next'] ?? 1) as num).toInt();
    if (next < 1) {
      toast('Next Number must be 1 or more');
      return false;
    }
    if (prefix == d.prefix && next < d.seq + 1) {
      toast('Next Number cannot be below ${d.seq + 1} for the same prefix: numbers already used would repeat');
      return false;
    }
    d
      ..prefix = prefix
      ..seq = next - 1;
    after(Res('Number series for ${d.label} updated · next is $prefix${next.toString().padLeft(4, '0')}'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

void editBatch(Batch b) {
  mform('Edit batch · ${b.id}', [
    const F.header('Batch'),
    F('batch', 'Batch No.', type: 'readonly', def: b.id),
    F('item', 'Item', type: 'readonly', def: S.item(b.item).name),
    F('wh', 'Warehouse', type: 'readonly', def: '${S.wh(b.wh).code} — ${S.wh(b.wh).city}'),
    F('qty', 'Quantity', type: 'number', req: true, def: '${b.qty}'),
    F('exp', 'Expiry Date', type: 'date', req: true, def: b.exp),
    F('mfg', 'Manufacture Date', type: 'date', def: b.mfg),
    F('sup', 'Supplier', type: 'select', req: true, def: b.sup, options: S.suppliers.map((s) => Opt(s.id, s.name)).toList()),
    F('status', 'Status', type: 'select', def: b.status, options: opts(_with(['Released', 'Expiring Soon', 'Quarantine', 'Expired'], b.status))),
  ], (v, _) {
    b
      ..qty = ((v['qty'] ?? 0) as num).toInt()
      ..exp = v['exp'] as String
      ..mfg = v['mfg'] as String
      ..sup = v['sup'] as String
      ..status = v['status'] as String;
    after(Res('Batch ${b.id} updated'));
    return false;
  }, btn: 'Save changes', icon: 'check');
}

/// Statuses in which a lead / opportunity can still be changed.
/// A lead can be changed until it is converted, qualified or lost.
bool canEditLead(Lead l) => !['Converted', 'Qualified', 'Lost'].contains(l.status);
/// An opportunity can be changed until its quotation is created (the quotation then carries the items and value) or it is won / lost.
bool canEditOpp(Opportunity o) => !['Won', 'Lost'].contains(o.stage) && o.quote == null;
