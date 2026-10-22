import 'package:flutter/material.dart';
import '../ui/select.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/overlays.dart';
import '../ui/table.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'remove.dart';
import 'edit_forms.dart';

const kStateCode = {'Andhra Pradesh': '37', 'Telangana': '36', 'Tamil Nadu': '33', 'Karnataka': '29', 'Maharashtra': '27', 'Kerala': '32', 'Odisha': '21'};
bool gstinOk(String g, String state) => RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$').hasMatch(g) && g.substring(0, 2) == kStateCode[state];

// ================================================================ CUSTOMERS
void newCustomerForm() {
  mform('New customer', [

    const F.header('Customer'),
    F('code', 'Customer Code', type: 'readonly', def: S.nextCustomerId()),
    const F('name', 'Customer Name', req: true, hint: 'e.g. Krishna Stores'),
    const F('phone', 'Mobile No.', def: '+91 ', hint: 'Mobile or Email required'),
    const F('email', 'Email', type: 'email', hint: 'Mobile or Email required'),
    const F.header('GST & Address'),
    F('gst_reg', 'GST Registration Type', type: 'select', req: true, options: opts(['Registered', 'Unregistered'])),
    const F('gstin', 'GSTIN', when: 'gst_reg', whenIs: 'Registered', hint: '37ABCDE1234F1Z5', help: 'First two digits must match the state'),
    F('state', 'State', type: 'select', req: true, def: 'Andhra Pradesh', options: opts(kStates)),
    const F('addr1', 'Billing Address', req: true, full: true),
    const F('ship_addr', 'Shipping Address', req: true, full: true, hint: 'Same as billing address if goods go there'),
    const F.header('Terms'),
    F('terms', 'Payment Terms', type: 'select', def: 'Net 30 days', req: true, options: opts(S.termNames)),
    const F('city', 'City', def: 'Visakhapatnam'),
    F('group', 'Customer Group', type: 'select', options: S.customerGroups.map((g) => Opt(g.name, g.name)).toList()),
    const F('contact', 'Contact Person'),
    const F('limit', 'Credit Limit (₹)', type: 'number', def: '200000'),
    F('sp', 'Sales Person', type: 'select', options: opts(S.salesPersons.where((s) => s.status != 'Inactive').map((s) => s.name).toList())),
    F('status', 'Status', type: 'select', options: opts(['Active', 'On Hold', 'Inactive'])),
  ], (v, _) {
    final g = (v['gstin'] as String? ?? '').toUpperCase();
    if (g.isNotEmpty && !gstinOk(g, v['state'] as String)) {
      toast('GSTIN format is wrong or does not match ${v['state']}');
      return false;
    }
    final id = S.nextCustomerId();
    final c = Customer(id, (v['name'] as String).trim(), (v['city'] as String).trim(), v['state'] as String, g.isEmpty ? 'Unregistered' : g, v['group'] as String, termDays(v['terms'] as String), ((v['limit'] ?? 200000) as num).toDouble(),
        (v['contact'] as String).trim().isEmpty ? '—' : (v['contact'] as String).trim(), v['phone'] as String, v['status'] as String)
      ..email = (v['email'] as String).trim()
      ..billTo = (v['addr1'] as String).trim()
      ..shipTo = (v['ship_addr'] as String).trim()
      ..gstType = v['gst_reg'] as String;
    S.customers.add(c);
    // the sales person decides the territory, and the territory decides the dispatch warehouse
    final sp = S.salesPersons.where((s) => s.name == v['sp']).firstOrNull;
    if (sp != null) S.terrOf[id] = sp.terr;
    S.syncCustomerAddresses(c);
    after(Res('Customer $id created'));
    return false;
  }, btn: 'Save customer', size: ModalSize.wide);
}

Widget customersView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Customers', sub: 'Who we sell to · group decides price list, terms decide due dates'),
      DataTableCard(
        id: 'cust',
        rows: S.customers,
        bulk: true,
        exportName: 'customers',
        createLabel: 'New customer',
        onCreate: newCustomerForm,
        onRow: (r) => openCustomerPanel((r as Customer).id),
        search: (r) => '${(r as Customer).id} ${r.name} ${r.city} ${r.gstin}',
        filters: [
          Filt('Group', S.customerGroups.map((g) => g.name).toList(), (r) => (r as Customer).group),
          Filt('Status', const ['Active', 'On Hold', 'Inactive', 'Credit Hold'], (r) => (r as Customer).status),
        ],
        cols: [
          Col('Customer', (r) => CellAv((r as Customer).name, '${r.id} · ${r.city}'), sort: (r) => (r as Customer).name, text: (r) => (r as Customer).name),
          Col.t('GSTIN', (r) => (r as Customer).gstin),
          Col('Group', (r) => Tag((r as Customer).group), text: (r) => (r as Customer).group),
          Col.t('Terms', (r) => 'Net ${(r as Customer).terms}'),
          Col('Credit Limit', (r) => Text(fmtINR((r as Customer).limit)), num: true, sort: (r) => (r as Customer).limit),
          Col('Outstanding', (r) {
            final c = r as Customer;
            final out = S.outstanding(c.id);
            final u = c.limit == 0 ? 0.0 : out / c.limit * 100;
            return SizedBox(
              width: 130,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                Text(fmtINR(out), style: tsB),
                const SizedBox(height: 4),
                Bar(u, color: u > 80 ? C.red : C.blue600),
              ]),
            );
          }, num: true, sort: (r) => S.outstanding((r as Customer).id)),
          Col('Status', (r) => StatusBadge((r as Customer).status), status: true, text: (r) => (r as Customer).status),
        ],
      ),
    ]);

// ================================================================ CUSTOMER GROUPS
void newCGroupForm() {
  mform('New customer group', [
    const F.header('General'),
    const F('name', 'Group Name', req: true, hint: 'e.g. Institutional'),
    const F('parent', 'Parent Group', hint: 'e.g. Wholesale'),
    const F('desc', 'Description', full: true),
    F('price', 'Default Price List', type: 'select', options: S.priceLists.map((p) => Opt(p.id, '${p.name}${p.disc > 0 ? ' (−${p.disc}%)' : ''}')).toList()),
    F('terms', 'Default Payment Terms', type: 'select', def: 'Net 30 days', options: opts(S.termNames)),
    const F('credit', 'Default Credit Limit (₹)', type: 'number', def: '300000'),
    F('status', 'Status', type: 'select', req: true, options: opts(['Active', 'Inactive'])),
  ], (v, _) {
    final n = (v['name'] as String).trim();
    S.customerGroups.add(CustomerGroup('CG-${n.substring(0, n.length < 3 ? n.length : 3).toUpperCase()}', n, v['price'] as String, termDays(v['terms'] as String), ((v['credit'] ?? 300000) as num).toDouble(), (v['desc'] as String).isEmpty ? '—' : v['desc'] as String)
      ..parent = (v['parent'] as String).trim()
      ..status = v['status'] as String);
    after(Res('Group $n created'));
    return false;
  }, btn: 'Save group');
}

Widget customerGroupsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Customer Groups', sub: 'Groups set the price list, default payment terms and credit limit for new customers'),
      DataTableCard(
        id: 'cg',
        rows: S.customerGroups,
        exportName: 'customer-groups',
        createLabel: 'New group',
        onCreate: newCGroupForm,
        onRow: (r) {
          final g = r as CustomerGroup;
          final pl = S.priceLists.firstWhere((p) => p.id == g.price);
          recPanel(g.name, '${g.id} · Customer group', [
            Kv.t('Price list', '${pl.name}${pl.disc > 0 ? ' (−${pl.disc}%)' : ''}'), Kv.t('Default terms', 'Net ${g.terms} days'), Kv.t('Default credit limit', fmtINR(g.credit)),
            Kv.t('Customers', '${S.customers.where((c) => c.group == g.name).length}'), Kv.t('Description', g.desc),
          ], extra: [
            TabDef('Customers', () => Column(children: [for (final c in S.customers.where((c) => c.group == g.name)) ActivityRow('users', c.name, c.city, onTap: () => openCustomerPanel(c.id))])),
          ], footer: (_) => [Btn.secondary('Edit', icon: 'edit', onTap: () { closeAll(); editCustomerGroup(g); }), deleteBtn(() => deleteCustomerGroup(g))]);
        },
        cols: [
          Col('Group', (r) => CellTwo((r as CustomerGroup).name, r.id), text: (r) => (r as CustomerGroup).name),
          Col('Price List', (r) => Tag(S.priceLists.firstWhere((p) => p.id == (r as CustomerGroup).price).name)),
          Col.t('Terms', (r) => 'Net ${(r as CustomerGroup).terms}'),
          Col('Default Credit', (r) => Text(fmtINR((r as CustomerGroup).credit)), num: true),
          Col.t('Customers', (r) => '${S.customers.where((c) => c.group == (r as CustomerGroup).name).length}', num: true),
          Col.t('Description', (r) => (r as CustomerGroup).desc),
        ],
      ),
    ]);

// ================================================================ SUPPLIERS
void newSupplierForm() {
  mform('New supplier', [

    const F.header('Supplier'),
    F('code', 'Supplier Code', type: 'readonly', def: S.nextSupplierId()),
    const F('name', 'Supplier Name', req: true, hint: 'e.g. SafeGuard Industrial Supplies'),
    const F('phone', 'Mobile No.', def: '+91 ', hint: 'Mobile or Email required'),
    const F('email', 'Email', type: 'email', hint: 'Mobile or Email required'),
    const F.header('GST & Address'),
    F('gst_reg', 'GST Registration Type', type: 'select', req: true, options: opts(['Registered', 'Unregistered'])),
    const F('gstin', 'GSTIN', when: 'gst_reg', whenIs: 'Registered', hint: '33ABCDE1234F1Z5', help: 'First two digits must match the state'),
    F('state', 'State', type: 'select', req: true, def: 'Andhra Pradesh', options: opts(kStates)),
    const F('addr1', 'Address', req: true, full: true),
    const F.header('Terms'),
    F('terms', 'Payment Terms', type: 'select', def: 'Net 30 days', req: true, options: opts(S.termNames)),
    const F('city', 'City', def: 'Visakhapatnam'),
    const F('contact', 'Contact Person'),
    const F('lead', 'Lead Time (days)', type: 'number', def: '5'),
    F('status', 'Status', type: 'select', options: opts(['Approved', 'On Probation', 'On Hold', 'Inactive'])),
  ], (v, _) {
    final g = (v['gstin'] as String? ?? '').toUpperCase();
    if (g.isNotEmpty && !gstinOk(g, v['state'] as String)) {
      toast('GSTIN format is wrong or does not match ${v['state']}');
      return false;
    }
    final id = S.nextSupplierId();
    S.suppliers.add(Supplier(id, (v['name'] as String).trim(), (v['city'] as String).trim(), v['state'] as String, g.isEmpty ? 'Unregistered' : g, termDays(v['terms'] as String), ((v['lead'] ?? 5) as num).toInt(), 0, 0, 0,
        (v['contact'] as String).trim().isEmpty ? '—' : (v['contact'] as String).trim(), v['status'] as String)
      ..phone = v['phone'] as String
      ..email = (v['email'] as String).trim()
      ..address = (v['addr1'] as String).trim()
      ..gstType = v['gst_reg'] as String);
    after(Res('Supplier $id created'));
    return false;
  }, btn: 'Save supplier', size: ModalSize.wide);
}

Widget suppliersView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Suppliers', sub: 'Who we buy from · lead time and performance drive ordering'),
      DataTableCard(
        id: 'sup',
        rows: S.suppliers,
        exportName: 'suppliers',
        createLabel: 'New supplier',
        onCreate: newSupplierForm,
        onRow: (r) => openSupplierPanel((r as Supplier).id),
        search: (r) => '${(r as Supplier).id} ${r.name} ${r.city} ${r.gstin}',
        filters: [Filt('Status', const ['Approved', 'On Probation', 'On Hold', 'Inactive'], (r) => (r as Supplier).status)],
        cols: [
          Col('Supplier', (r) => CellAv((r as Supplier).name, '${r.id} · ${r.city}'), sort: (r) => (r as Supplier).name, text: (r) => (r as Supplier).name),
          Col.t('GSTIN', (r) => (r as Supplier).gstin),
          Col.t('Terms', (r) => 'Net ${(r as Supplier).terms}'),
          Col.t('Lead Time', (r) => '${(r as Supplier).lead} days', num: true),
          Col.t('On-Time %', (r) => '${(r as Supplier).otd}%', num: true),
          Col.t('Quality %', (r) => '${(r as Supplier).quality}%', num: true),
          Col('Status', (r) => StatusBadge((r as Supplier).status), status: true, text: (r) => (r as Supplier).status),
        ],
      ),
    ]);

// ================================================================ SUPPLIER GROUPS
void newSGroupForm() {
  mform('New supplier group', [
    const F.header('General'),
    const F('name', 'Group Name', req: true, hint: 'e.g. Spare Parts'),
    const F('parent', 'Parent Group', hint: 'e.g. Raw Materials'),
    const F('desc', 'Description', full: true),
    F('terms', 'Default Payment Terms', type: 'select', def: 'Net 30 days', options: opts(S.termNames)),
    F('members', 'Member Suppliers', type: 'checks', options: S.suppliers.map((s) => Opt(s.id, s.name)).toList()),
    F('status', 'Status', type: 'select', req: true, options: opts(['Active', 'Inactive'])),
  ], (v, _) {
    final n = v['name'] as String;
    S.supplierGroups.add(SupplierGroup('SG-${n.substring(0, n.length < 3 ? n.length : 3).toUpperCase()}', n, 30, (v['members'] as List).cast<String>(), (v['desc'] as String).isEmpty ? '—' : v['desc'] as String));
    after(Res('Group $n created'));
    return false;
  }, btn: 'Save group');
}

Widget supplierGroupsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Supplier Groups', sub: 'Group suppliers by what they supply · sets default terms'),
      DataTableCard(
        id: 'sg',
        rows: S.supplierGroups,
        exportName: 'supplier-groups',
        createLabel: 'New group',
        onCreate: newSGroupForm,
        onRow: (r) {
          final g = r as SupplierGroup;
          recPanel(g.name, '${g.id} · Supplier group', [Kv.t('Default terms', 'Net ${g.terms} days'), Kv.t('Suppliers', '${g.members.length}'), Kv.t('Description', g.desc)], extra: [
            TabDef('Suppliers', () => Column(children: [
                  for (final m in g.members) ActivityRow('store', S.sup(m).name, S.sup(m).city, tone: Tone.amber, onTap: () => openSupplierPanel(m)),
                ])),
          ]);
        },
        cols: [
          Col('Group', (r) => CellTwo((r as SupplierGroup).name, r.id), text: (r) => (r as SupplierGroup).name),
          Col.t('Terms', (r) => 'Net ${(r as SupplierGroup).terms}'),
          Col('Suppliers', (r) => Wrap(spacing: 4, runSpacing: 4, children: [for (final m in (r as SupplierGroup).members) Tag(S.sup(m).name)]), text: (r) => (r as SupplierGroup).members.join(' ')),
          Col.t('Description', (r) => (r as SupplierGroup).desc),
        ],
      ),
    ]);

// ================================================================ ITEMS
void newItemForm() {
  mform('New item', [

    const F.header('Item'),
    F('code', 'Item Code', type: 'readonly', def: S.nextItemId()),
    const F('name', 'Item Name', req: true, hint: 'e.g. Industrial Safety Helmet'),
    F('type', 'Item Type', type: 'select', req: true, options: opts(['Goods', 'Service'])),
    F('cat', 'Category', type: 'select', req: true, options: opts(S.categories)),
    F('uom', 'UOM', type: 'select', req: true, options: S.uoms.map((u) => Opt(u.code, '${u.code} · ${u.name}')).toList()),
    const F('hsn', 'HSN Code', def: '6506', req: true),
    F('gst', 'Tax Code', type: 'select', def: 'GST 18%', req: true, options: opts(S.taxNames)),
    F('track', 'Tracking', type: 'select', req: true, options: opts(['None', 'Batch', 'Serial'])),
    const F.header('Price'),
    const F('cost', 'Purchase Price (₹)', type: 'number', req: true, hint: 'e.g. 300'),
    const F('price', 'Selling Price (₹)', type: 'number', req: true, hint: 'e.g. 450'),
    const F('shelf_life', 'Shelf Life (days)', type: 'number', when: 'track', whenIs: 'Batch', hint: 'Used to calculate expiry at GRN'),
    F('sup', 'Preferred Supplier', type: 'select', req: true, options: [const Opt('', 'Select supplier'), ...S.suppliers.where((s) => s.status != 'Inactive').map((s) => Opt(s.id, s.name))]),
    const F('reorder', 'Reorder Level', type: 'number', def: '50'),
    const F('moq', 'Min Order Qty', type: 'number', def: '10'),
    const F('lead', 'Lead Time (days)', type: 'number', def: '5'),
    F('status', 'Status', type: 'select', options: opts(['Active', 'Inactive', 'Discontinued'])),
  ], (v, _) {
    if ((v['sup'] as String).isEmpty) {
      toast('Select the Preferred Supplier');
      return false;
    }
    final costVal = ((v['cost'] ?? 0) as num).toDouble();
    final priceVal = ((v['price'] ?? 0) as num).toDouble();
    if (priceVal < costVal) {
      toast('Sale price is below cost — check values');
      return false;
    }
    final id = S.nextItemId();
    final gstNum = S.taxRateOf(v['gst'].toString()).round();
    S.items.add(Item(id, (v['name'] as String).trim(), v['cat'] as String, (v['hsn'] as String).isEmpty ? '6403' : v['hsn'] as String, gstNum, v['uom'] as String, costVal, priceVal,
        ((v['reorder'] ?? 50) as num).toInt(), ((v['moq'] ?? 10) as num).toInt(), 5, ((v['lead'] ?? 5) as num).toInt(), v['sup'] as String, v['track'] as String, [0, 0, 0])
      ..type = v['type'] as String
      ..status = v['status'] as String
      ..shelfLife = ((v['shelf_life'] ?? 0) as num).toInt());
    for (final w in S.warehouses) {
      S.stock[w.id]![id] = StockCell(0);
    }
    after(Res('Item $id created'));
    return false;
  }, btn: 'Save item', size: ModalSize.wide);
}

Widget itemsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Items', sub: 'Released products with tax, pricing and replenishment settings'),
      DataTableCard(
        id: 'itm',
        rows: S.items,
        bulk: true,
        pageSize: 10,
        exportName: 'items',
        createLabel: 'New item',
        onCreate: newItemForm,
        onRow: (r) => openItemPanel((r as Item).id),
        search: (r) => '${(r as Item).id} ${r.name} ${r.hsn} ${r.cat}',
        filters: [
          Filt('Category', S.categories, (r) => (r as Item).cat),
          Filt('Tracking', const ['None', 'Batch', 'Serial'], (r) => (r as Item).track),
        ],
        cols: [
          Col('Item', (r) => CellTwo((r as Item).name, '${r.id} · ${r.cat}'), sort: (r) => (r as Item).name, text: (r) => (r as Item).name),
          Col.t('HSN', (r) => (r as Item).hsn),
          Col.t('GST', (r) => '${(r as Item).gst}%', num: true),
          Col('Cost', (r) => Text(fmtINR((r as Item).cost)), num: true, sort: (r) => (r as Item).cost),
          Col('Price', (r) => Text(fmtINR((r as Item).price), style: tsB), num: true, sort: (r) => (r as Item).price),
          Col.t('Reorder Level / Min. Order Qty', (r) => '${(r as Item).reorder} / ${r.moq}', num: true),
          Col('Tracking', (r) => Tag((r as Item).track)),
          Col('Total Stock', (r) {
            final p = r as Item;
            return Text('${fmtNum(S.warehouses.fold<int>(0, (a, w) => a + S.stk(w.id, p.id).onhand))} ${p.uom}');
          }, num: true),
        ],
      ),
    ]);

// ================================================================ ITEM SETUP
void newIGroupForm() {
  mform('New item category', [

    const F.header('Category'),
    const F('name', 'Category Name', req: true, hint: 'e.g. Safety Equipment'),
  ], (v, _) {
    final n = (v['name'] as String).trim();
    if (S.categories.contains(n)) {
      toast('Category already exists');
      return false;
    }
    S.categories.add(n);
    after(Res('Item category $n created'));
    return false;
  }, btn: 'Save group');
}

void newUomForm() {
  mform('New unit of measure', [

    const F.header('Unit of Measure'),
    const F('code', 'UOM Code', req: true, hint: 'e.g. Box'),
    const F('name', 'UOM Name', req: true, hint: 'e.g. Box of 10'),
    F('type', 'UOM Type', type: 'select', options: opts(['Count', 'Pack', 'Weight', 'Volume', 'Length'])),
    const F('base', 'Base UOM', def: 'Nos'),
    const F('factor', 'Conversion to Base', type: 'number', def: '1'),
  ], (v, _) {
    S.uoms.add(Uom(v['code'] as String, v['name'] as String, v['type'] as String, v['base'] as String, ((v['factor'] ?? 1) as num).toDouble()));
    after(Res('Unit ${v['code']} added'));
    return false;
  }, btn: 'Save unit');
}

void newTdgForm() {
  mform('New tracking dimension group', [
    const F('name', 'Group Name', req: true, hint: 'e.g. Batch + Serial'),
    F('batch', 'Batch Control', type: 'select', req: true, options: opts(['Yes', 'No'])),
    F('serial', 'Serial Control', type: 'select', req: true, options: opts(['No', 'Yes'])),
    F('expiry', 'Expiry Date Mandatory', type: 'select', options: opts(['Yes', 'No'])),
    const F('batch_series', 'Batch No. Series', hint: 'e.g. B{YY}{MM}-#####'),
    const F('desc', 'Description', full: true),
  ], (v, _) {
    final n = v['name'] as String;
    S.trackGroups.add(TrackGroup('TDG-${n.toUpperCase().replaceAll(RegExp('[^A-Z]'), '')}', n, v['batch'] as String, v['serial'] as String, v['expiry'] as String, (v['desc'] as String).isEmpty ? '—' : v['desc'] as String));
    after(Res('Tracking group $n created'));
    return false;
  }, btn: 'Save group');
}

void newSdgForm() {
  mform('New storage dimension group', [
    const F('name', 'Name', req: true),
    F('site', 'Site Control', type: 'select', options: opts(['Yes'])),
    F('wh', 'Warehouse Control', type: 'select', options: opts(['Yes'])),
    F('loc', 'Bin Control', type: 'select', options: opts(['Yes', 'No'])),
    const F('desc', 'Description', full: true),
  ], (v, _) {
    S.storageGroups.add(StorageGroup(S.freshId('SDG-', S.storageGroups.map((x) => x.id)), v['name'] as String, v['site'] as String, v['wh'] as String, v['loc'] as String, (v['desc'] as String).isEmpty ? '—' : v['desc'] as String));
    after(Res('Storage group ${v['name']} created'));
    return false;
  }, btn: 'Save group');
}

Widget itemSetupView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Units of Measure', sub: 'Units used on items, orders and stock'),
      DataTableCard(
              id: 'uom',
              rowActions: (r) => Row(mainAxisSize: MainAxisSize.min, children: [
                IconBtn('edit', () => editUom(r as Uom), size: 30, tip: 'Edit'),
                const SizedBox(width: 4),
                deleteIcon(() => deleteUom(r as Uom)),
              ]),
              rows: S.uoms,
              exportName: 'uoms',
              createLabel: 'New unit',
              onCreate: newUomForm,
              cols: [
                Col('Code', (r) => Text((r as Uom).code, style: tsB), text: (r) => (r as Uom).code),
                Col.t('Name', (r) => (r as Uom).name),
                Col('Type', (r) => Tag((r as Uom).type)),
                Col.t('Conversion', (r) => '1 ${(r as Uom).code} = ${r.factor % 1 == 0 ? r.factor.toInt() : r.factor} ${r.base}'),
                Col.t('Items', (r) => '${S.items.where((p) => p.uom == (r as Uom).code).length}', num: true),
              ],
            ),
    ]);

// ================================================================ PRICING
void newAgreementForm() {
  mform('New trade agreement', [
    const F.header('General'),
    F('party', 'Customer / Supplier', type: 'select', req: true, full: true, options: [
      ...S.customers.where((c) => c.status != 'Inactive').map((c) => Opt('C:${c.id}', 'Customer · ${c.name}')),
      ...S.suppliers.where((s) => s.status != 'Inactive').map((s) => Opt('S:${s.id}', 'Supplier · ${s.name}')),
    ]),
    F('item', 'Item', type: 'select', req: true, full: true, options: S.items.map((p) => Opt(p.id, '${p.name} (${p.id})')).toList()),
    F('uom', 'UOM', type: 'select', options: S.uoms.map((u) => Opt(u.code, u.code)).toList()),
    F('plist', 'Price List', type: 'select', options: opts(['—', ...S.priceLists.map((p) => p.name)])),
    const F.header('Terms'),
    const F('price', 'Agreed Unit Price (₹)', type: 'number', req: true),
    F('currency', 'Currency', type: 'select', req: true, options: opts(S.currencyCodes)),
    F('from', 'Valid From', type: 'date', def: todayStr(), req: true),
    F('to', 'Valid To', type: 'date', def: addDays(todayStr(), 180), req: true),
    const F('disc', 'Discount %', type: 'number', def: '0'),
    const F('min', 'Minimum Order Quantity', type: 'number', def: '10', req: true),
    const F('max', 'Maximum Order Quantity', type: 'number'),
    F('terms', 'Payment Terms', type: 'select', options: opts(['—', ...S.termNames])),
    const F.header('Other'),
    const F('remarks', 'Remarks', type: 'textarea', full: true),
    const F.header('Status'),
    F('status', 'Status', type: 'select', req: true, def: 'Active', options: opts(['Draft', 'Active', 'Expired'])),
  ], (v, _) {
    if ((v['to'] as String).compareTo(v['from'] as String) <= 0) {
      toast('Valid-to must be after valid-from');
      return false;
    }
    final p = v['party'] as String;
    final kind = p.startsWith('C') ? 'Sales' : 'Purchase';
    final id = 'TA-0${101 + S.tradeAgreements.length}';
    S.tradeAgreements.add(TradeAgreement(id, kind, p.substring(2), v['item'] as String, (v['price'] as num).toDouble(), v['from'] as String, v['to'] as String, (v['min'] as num).toInt(), v['status'] as String));
    after(Res('$id saved · used first when pricing ${kind.toLowerCase()} documents'));
    return false;
  }, btn: 'Save agreement', note: 'Trade agreements override price lists when the party, item and minimum quantity match.');
}

void openAgreement(TradeAgreement t) {
  final party = t.kind == 'Sales' ? S.cust(t.party).name : S.sup(t.party).name;
  final it = S.item(t.item);
  final list = t.kind == 'Sales' ? it.price : it.cost;
  recPanel(t.id, '${t.kind} trade agreement', [
    Kv.t('Type', t.kind), Kv.t(t.kind == 'Sales' ? 'Customer' : 'Supplier', party), Kv.t('Item', it.name), Kv.t('Agreed price', fmtINR(t.price)), Kv.t('List price', fmtINR(list)),
    Kv.t('Saving', '${((1 - t.price / list) * 100).round()}%'), Kv.t('Minimum qty', '${t.minQty}'), Kv.t('Valid', '${t.from} → ${t.to}'), Kv('Status', StatusBadge(t.status)),
  ], footer: (_) => [
    Btn.secondary(t.status == 'Active' ? 'Deactivate' : 'Activate', icon: t.status == 'Active' ? 'pause' : 'play', onTap: () {
      t.status = t.status == 'Active' ? 'Expired' : 'Active';
      after(Res('${t.id} · ${t.status}'));
    }),
  ]);
}

Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft)));

void openPriceLookup() {
  if (S.customers.isEmpty || S.items.isEmpty) {
    toast('First add a customer and an item');
    return;
  }
  var c = S.customers.first.id, i = S.items.first.id;
  var q = 100;
  openModal('Price lookup', StatefulBuilder(builder: (ctx, set) {
    final r = S.salesPrice(c, i, q);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _lbl('Customer'),
      ProtoSelect(value: c, options: S.customers.map((x) => SelOpt(x.id, x.name)).toList(), onChanged: (v) => set(() => c = v)),
      const SizedBox(height: 12),
      _lbl('Item'),
      ProtoSelect(value: i, options: S.items.map((x) => SelOpt(x.id, x.name)).toList(), onChanged: (v) => set(() => i = v)),
      const SizedBox(height: 12),
      _lbl('Quantity'),
      TextFormField(initialValue: '$q', keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13), onChanged: (v) => set(() => q = int.tryParse(v) ?? 0)),
      const SizedBox(height: 14),
      NoteBox(Tone.green, 'tag', '${fmtINR(r.rate)} per unit', '· source: ${r.src}'),
    ]);
  }), size: ModalSize.narrow, actions: (ctx) => [Btn.secondary('Close', onTap: () => Navigator.of(ctx).pop())]);
}

Widget pricingView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Price Lists', sub: 'Price lists by customer group and trade agreements for specific parties', actions: [Btn.secondary('Price lookup', icon: 'search', onTap: openPriceLookup)]),
      Tabs([
        TabDef('Price lists', () => DataTableCard(
              id: 'pl',
              rows: S.priceLists,
              exportName: 'price-lists',
              createLabel: 'New price list',
              onCreate: newPriceListForm,
              onRow: (r) {
                final p = r as PriceList;
                recPanel(p.name, '${p.id} · Price list', [Kv.t('Customer group', p.group), Kv.t('Discount on base', '${p.disc}%'), Kv.t('Validity', p.valid), Kv('Status', StatusBadge(p.status))], extra: [
                  TabDef('Prices', () => Column(children: [for (final it in S.items) ActivityRow('tag', it.name, 'Base ${fmtINR(it.price)}', trailing: Text(fmtINR((it.price * (100 - p.disc) / 100).roundToDouble()), style: tsB))])),
                ], footer: (_) => [Btn.secondary('Edit', icon: 'edit', onTap: () { closeAll(); editPriceList(p); }),deleteBtn(() => deletePriceList(p)),]);
              },
              cols: [
                Col('Code', (r) => Text((r as PriceList).id, style: tsB)),
                Col.t('Price List', (r) => (r as PriceList).name),
                Col('Customer Group', (r) => Tag((r as PriceList).group)),
                Col.t('Discount on Base', (r) => '${(r as PriceList).disc}%', num: true),
                Col.t('Validity', (r) => (r as PriceList).valid),
                Col('Status', (r) => StatusBadge((r as PriceList).status), status: true),
              ],
            )),
        TabDef('Trade agreements', () => DataTableCard(
              id: 'ta',
              rowActions: (r) => deleteIcon(() => deleteAgreement(r as TradeAgreement)),
              rows: S.tradeAgreements,
              exportName: 'trade-agreements',
              createLabel: 'New agreement',
              onCreate: newAgreementForm,
              onRow: (r) => openAgreement(r as TradeAgreement),
              filters: [Filt('Type', const ['Sales', 'Purchase'], (r) => (r as TradeAgreement).kind)],
              cols: [
                Col('Agreement', (r) => Text((r as TradeAgreement).id, style: tsB), text: (r) => (r as TradeAgreement).id),
                Col('Type', (r) => StatusBadge((r as TradeAgreement).kind, tone: r.kind == 'Sales' ? Tone.blue : Tone.purple)),
                Col.t('Party', (r) => (r as TradeAgreement).kind == 'Sales' ? S.cust(r.party).name : S.sup(r.party).name),
                Col.t('Item', (r) => S.item((r as TradeAgreement).item).name),
                Col.t('Min Qty', (r) => '${(r as TradeAgreement).minQty}', num: true),
                Col('Price', (r) => Text(fmtINR((r as TradeAgreement).price), style: tsB), num: true),
                Col.t('Valid', (r) => '${(r as TradeAgreement).from} → ${r.to}'),
                Col('Status', (r) => StatusBadge((r as TradeAgreement).status), status: true),
              ],
            )),
      ], storeKey: 'pricing'),
    ]);

void newPriceListForm() {
  mform('New price list', [

    const F.header('Price List'),
    const F('name', 'Price List Name', req: true, hint: 'e.g. Wholesale 2026'),
    F('group', 'Customer Group', type: 'select', req: true, options: S.customerGroups.map((g) => Opt(g.name, g.name)).toList()),
    const F('disc', 'Discount on Base Price %', type: 'number', req: true, def: '0', help: 'Customers in this group get this discount on the item price'),
    const F('valid', 'Validity', req: true, def: 'FY 2026-27', hint: 'e.g. FY 2026-27'),
    F('status', 'Status', type: 'select', req: true, options: opts(['Active', 'Inactive', 'Draft'])),
  ], (v, _) {
    final id = S.freshId('PL-0', S.priceLists.map((x) => x.id));
    S.priceLists.add(PriceList(id, (v['name'] as String).trim(), v['group'] as String, ((v['disc'] ?? 0) as num).toInt(), (v['valid'] as String).trim(), v['status'] as String));
    after(Res('Price list $id created'));
    return false;
  });
}

// ================================================================ SITES, WAREHOUSES & BINS
void newSiteForm() {
  mform('New site', [
    const F.header('General'),
    const F('name', 'Site Name', req: true, hint: 'e.g. Andhra Logistics Hub'),
    const F('country', 'Country', def: 'India', req: true),
    const F('addr', 'Address', full: true),
    const F('city', 'City', def: 'Visakhapatnam'),
    const F('tz', 'Time Zone', def: 'IST (UTC+5:30)'),
    const F('mgr', 'Site Manager', hint: 'e.g. Srinivas Rao'),
    F('status', 'Status', type: 'select', req: true, options: opts(['Active', 'Inactive'])),
  ], (v, _) {
    final id = S.freshId('SITE-0', S.sites.map((x) => x.id));
    S.sites.add(Site(id, v['name'] as String, '37AAACI1234F1Z0', <String>[], '${v['city']} Site'));
    after(Res('Site $id created'));
    return false;
  });
}

void newWarehouseForm() {
  mform('New warehouse', [

    const F.header('Warehouse'),
    const F('code', 'Warehouse Code', req: true, hint: 'e.g. VZG-DC'),
    const F('name', 'Warehouse Name', req: true, hint: 'e.g. Visakhapatnam Distribution Centre'),
    F('branch', 'Branch', type: 'select', req: true, options: S.branchNames.map((b) => Opt(b, b)).toList()),
    const F('city', 'City', def: 'Visakhapatnam', req: true),
    F('state', 'State', type: 'select', req: true, def: 'Andhra Pradesh', options: opts(kStates)),
    F('site', 'Site', type: 'select', options: S.sites.map((s) => Opt(s.id, s.name)).toList()),
    F('type', 'Type', type: 'select', options: opts(['Central Fulfillment', 'Regional Hub', 'Transit Depot', 'Raw Material Store'])),
    const F('mgr', 'Manager'),
    const F('cap', 'Capacity', hint: 'e.g. 50,000 sq ft'),
    F('status', 'Status', type: 'select', options: opts(['Active', 'Inactive'])),
  ], (v, _) {
    final id = S.freshId('WH-0', S.warehouses.map((x) => x.id));
    final code = (v['code'] as String).toUpperCase();
    if (S.warehouses.any((w) => w.code == code)) {
      toast('Warehouse code $code already exists');
      return false;
    }
    final whObj = Warehouse(id, code, (v['name'] as String).trim(), (v['city'] as String).trim(), v['state'] as String, '37AAACI1234F1Z0', (v['mgr'] as String).isEmpty ? 'Manager' : v['mgr'] as String, v['type'] as String,
        (v['cap'] as String).isEmpty ? '30,000 sq ft' : v['cap'] as String, 4, v['status'] as String? ?? 'Active', 'Basic',
        branch: v['branch'] as String, site: v['site'] as String);
    S.warehouses.add(whObj);
    S.stock[id] = {};
    for (final it in S.items) {
      S.stock[id]![it.id] = StockCell(0);
    }
    after(Res('Warehouse $code created'));
    return false;
  });
}

void newBinForm() {
  mform('New bin location', [

    const F.header('Bin'),
    F('wh', 'Warehouse', type: 'select', req: true, def: S.currentWh.id, options: S.warehouses.map((w) => Opt(w.id, '${w.code} — ${w.city}')).toList()),
    const F('code', 'Bin Code', req: true, hint: 'e.g. A-01-02'),
    F('zone', 'Zone', type: 'select', options: opts(['A · Picking Area', 'B · Bulk storage', 'Receiving dock', 'Quarantine', 'Dispatch bay'])),
    F('type', 'Bin Type', type: 'select', options: opts(['Picking', 'Reserve', 'Inbound staging', 'QC hold / damaged', 'Outbound staging'])),
    const F('cap', 'Capacity', def: '8 pallets'),
    F('status', 'Status', type: 'select', options: opts(['Active', 'Inactive', 'Blocked'])),
  ], (v, _) {
    final code = (v['code'] as String).trim().isEmpty ? S.freshId('BIN-0', S.bins.map((x) => x.code)) : (v['code'] as String).toUpperCase();
    if (S.bins.any((b) => b.wh == v['wh'] && b.code == code)) {
      toast('Bin $code already exists in ${S.wh(v['wh'] as String).code}');
      return false;
    }
    S.bins.add(Bin(v['wh'] as String, code, v['zone'] as String, (v['type'] as String).isEmpty ? 'Picking' : v['type'] as String, (v['cap'] as String).isEmpty ? '8 pallets' : v['cap'] as String, 0)..status = v['status'] as String);
    after(Res('Bin $code created in ${S.wh(v['wh'] as String).code}'));
    return false;
  });
}

void openBin(Bin b) {
  final its = S.items.where((p) => S.suggestBin(p.id) == b.code).toList();
  recPanel(b.code, '${S.wh(b.wh).code} · ${b.zone}', [
    Kv.t('Warehouse', S.wh(b.wh).name), Kv.t('Zone', b.zone), Kv.t('Use', b.type), Kv.t('Capacity', b.cap), Kv.t('Utilisation', '${b.use}%'), Kv('Status', StatusBadge(b.use > 90 ? 'Low' : 'Active')),
  ], top: Padding(padding: const EdgeInsets.only(bottom: 14), child: Bar(b.use.toDouble(), color: b.use > 80 ? C.amber : C.blue600)), extra: [
    TabDef('Items stored here', () => its.isEmpty
        ? const Empty('No storage rule points to this bin')
        : Column(children: [for (final p in its) ActivityRow('box', p.name, '${p.id} · storage rule by item group', onTap: () => openItemPanel(p.id))])),
  ], footer: (_) => [Btn.secondary('Edit', icon: 'edit', onTap: () { closeAll(); editBin(b); }),deleteBtn(() => deleteBin(b)),]);
}

Widget warehousesView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Warehouses', sub: 'Sites (one per GST state), warehouses, zones and bins used by bin allocation and picking', actions: [
        Btn.secondary('New site', icon: 'plus', onTap: newSiteForm),
        Btn.secondary('New warehouse', icon: 'plus', onTap: newWarehouseForm),
        Btn.secondary('Edit warehouse', icon: 'edit', onTap: editWarehousePick),
        Btn.secondary('Delete warehouse', icon: 'trash', onTap: deleteWarehousePick),
      ]),
      const SectionTitle('Sites', first: true),
      RGrid(max: 2, minTile: 300, children: [
        for (final s in S.sites)
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [Text('${s.name} · ${s.id}', style: tsB), Tag('GSTIN ${s.gstin}')]),
              const SizedBox(height: 6),
              Text('${s.address} · warehouses: ${s.whs.map((w) => S.wh(w).code).join(', ')}', style: const TextStyle(fontSize: 12.5, color: C.faint)),
            ]),
          ),
      ]),
      const SectionTitle('Warehouses'),
      RGrid(max: 3, minTile: 260, children: [
        for (final w in S.warehouses)
          ModCard('home', w.name, Tone.blue, [
            '${w.code} · ${w.city}, ${w.state}',
            '${w.type} · ${w.area} · ${w.docks} docks',
            'Manager: ${w.manager}',
            'Stock value: ${fmtINR(S.stockValue(w.id))}',
            if (w.id == S.currentWh.id) 'Current working warehouse',
          ], () {
            S.currentWh = w;
            S.refresh();
            toast('Now working in ${w.name}');
          }),
      ]),
      const SectionTitle('Bins'),
      DataTableCard(
        id: 'bin',
        rows: S.bins,
        pageSize: 10,
        exportName: 'bins',
        createLabel: 'New bin',
        onCreate: newBinForm,
        initialFilters: {0: S.currentWh.code},
        onRow: (r) => openBin(r as Bin),
        search: (r) => '${(r as Bin).code} ${r.zone} ${r.type}',
        filters: [
          Filt('Warehouse', S.warehouses.map((w) => w.code).toList(), (r) => S.wh((r as Bin).wh).code),
          Filt('Zone', const ['Receiving dock', 'A · Picking Area', 'B · Bulk storage', 'Quarantine', 'Dispatch bay'], (r) => (r as Bin).zone),
        ],
        cols: [
          Col('Bin', (r) => Text((r as Bin).code, style: tsB), sort: (r) => (r as Bin).code, text: (r) => (r as Bin).code),
          Col('Warehouse', (r) => chipWh((r as Bin).wh)),
          Col.t('Zone', (r) => (r as Bin).zone),
          Col.t('Use', (r) => (r as Bin).type),
          Col.t('Capacity', (r) => (r as Bin).cap),
          Col('Utilisation', (r) => BarPct((r as Bin).use.toDouble(), color: r.use > 80 ? C.amber : C.blue600), sort: (r) => (r as Bin).use),
        ],
      ),
    ]);

Widget binsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Bins / Locations', sub: 'Warehouse storage locations, zones and capacities'),
      DataTableCard(
        id: 'bins-view',
        rows: S.bins,
        pageSize: 12,
        exportName: 'bins-locations',
        createLabel: 'New bin',
        onCreate: newBinForm,
        onRow: (r) => openBin(r as Bin),
        search: (r) => '${(r as Bin).code} ${r.zone} ${r.type}',
        filters: [
          Filt('Warehouse', S.warehouses.map((w) => w.code).toList(), (r) => S.wh((r as Bin).wh).code),
          Filt('Zone', const ['Receiving dock', 'A · Picking Area', 'B · Bulk storage', 'Quarantine', 'Dispatch bay'], (r) => (r as Bin).zone),
        ],
        cols: [
          Col('Bin Code', (r) => Text((r as Bin).code, style: tsB), text: (r) => (r as Bin).code),
          Col('Warehouse', (r) => chipWh((r as Bin).wh), text: (r) => S.wh((r as Bin).wh).code),
          Col.t('Zone', (r) => (r as Bin).zone),
          Col.t('Bin Type', (r) => (r as Bin).type),
          Col.t('Capacity', (r) => (r as Bin).cap),
          Col('Utilisation', (r) => BarPct((r as Bin).use.toDouble(), color: r.use > 80 ? C.amber : C.blue600), sort: (r) => (r as Bin).use),
          Col('Status', (r) => StatusBadge((r as Bin).use > 90 ? 'High' : 'Active'), status: true),
        ],
      ),
    ]);

Widget itemCategoriesView() {
  final cats = S.categories.map((c) {
    final count = S.items.where((i) => i.cat == c).length;
    return {'code': 'CAT-${(c.hashCode % 900 + 100).abs()}', 'name': c, 'desc': '$count item(s) configured in this category', 'status': 'Active'};
  }).toList();

  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Item Categories', sub: 'Classification and grouping for inventory items'),
    DataTableCard(
      id: 'item-cats',
      rowActions: (r) => Row(mainAxisSize: MainAxisSize.min, children: [
        IconBtn('edit', () => editCategory((r as Map)['name'] as String), size: 30, tip: 'Edit'),
        const SizedBox(width: 4),
        deleteIcon(() => deleteCategory((r as Map)['name'] as String)),
      ]),
      rows: cats,
      exportName: 'item-categories',
      createLabel: 'New category',
      onCreate: newIGroupForm,
      cols: [
        Col('Category Code', (r) => Text((r as Map)['code']!, style: tsB), text: (r) => (r as Map)['code']!),
        Col('Category Name', (r) => Text((r as Map)['name']!, style: tsB), text: (r) => (r as Map)['name']!),
        Col.t('Description', (r) => (r as Map)['desc']!),
        Col('Status', (r) => StatusBadge((r as Map)['status']!), status: true),
      ],
    ),
  ]);
}
