import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/overlays.dart';
import '../ui/table.dart';
import '../ui/widgets.dart';
import 'common.dart' show after;
import 'remove.dart' show removeRecord, deleteIcon;

/// Company Settings lists: branches, currencies, payment terms, tax codes and T&C templates.
/// Every list is saved in the store, and the dropdowns on the other forms read from it.

const _status = ['Active', 'Inactive'];

// ---------------------------------------------------------------- branches
void branchForm([Branch? b]) {
  final edit = b != null;
  mform(edit ? 'Edit branch · ${b.name}' : 'New branch', [
    const F.header('General'),
    F('name', 'Branch Name', req: true, hint: 'e.g. Visakhapatnam Port Branch', def: b?.name ?? ''),
    F('co', 'Company', req: true, def: b?.company ?? 'IMPACGO Logistics Pvt Ltd'),
    F('city', 'City', req: true, def: b?.city ?? 'Visakhapatnam'),
    F('status', 'Status', type: 'select', req: true, def: b?.status ?? 'Active', options: opts(_status)),
    F('tax_reg', 'Branch Tax Reg. No.', def: b?.taxReg ?? ''),
    F('mgr', 'Manager', hint: 'e.g. Harish Varma', def: b?.manager ?? ''),
    F('addr', 'Address', full: true, def: b?.address ?? ''),
    F('state', 'State', def: b?.state ?? 'Andhra Pradesh'),
    F('postal', 'Postal Code', def: b?.postal ?? '530001'),
    F('phone', 'Phone', def: b?.phone ?? ''),
    F('email', 'Email', type: 'email', def: b?.email ?? ''),
  ], (v, _) {
    final name = (v['name'] as String).trim();
    if (S.branches.any((x) => x != b && x.name.toLowerCase() == name.toLowerCase())) {
      toast('A branch named "$name" already exists');
      return false;
    }
    final r = b ?? Branch(name);
    final old = r.name;
    r
      ..name = name
      ..company = (v['co'] as String).trim()
      ..city = (v['city'] as String).trim()
      ..status = v['status'] as String
      ..taxReg = (v['tax_reg'] ?? '').toString().trim()
      ..manager = (v['mgr'] ?? '').toString().trim()
      ..address = (v['addr'] ?? '').toString().trim()
      ..state = (v['state'] ?? '').toString().trim()
      ..postal = (v['postal'] ?? '').toString().trim()
      ..phone = (v['phone'] ?? '').toString().trim()
      ..email = (v['email'] ?? '').toString().trim();
    if (!edit) {
      S.branches.add(r);
    } else if (old != name) {
      // warehouses keep their branch by name
      for (var i = 0; i < S.warehouses.length; i++) {
        final w = S.warehouses[i];
        if (w.branch == old) {
          S.warehouses[i] = Warehouse(w.id, w.code, w.name, w.city, w.state, w.gstin, w.manager, w.type, w.area, w.docks, w.status, w.wms, branch: name, site: w.site);
        }
      }
    }
    after(Res(edit ? 'Branch $name updated' : 'Branch $name created'));
    return false;
  }, btn: edit ? 'Save changes' : 'Save', icon: 'check');
}

void deleteBranch(Branch b) => removeRecord(
    'branch', b.name, [for (final w in S.warehouses.where((w) => w.branch == b.name)) 'Warehouse ${w.code} · ${w.name}'], () => S.branches.remove(b),
    deactivate: () => b.status = 'Inactive');

// ---------------------------------------------------------------- currencies
void currencyForm([Currency? c]) {
  final edit = c != null;
  mform(edit ? 'Edit currency · ${c.code}' : 'New currency', [
    const F.header('General'),
    F('code', 'Currency Code', req: true, hint: 'e.g. USD', def: c?.code ?? ''),
    F('name', 'Currency Name', req: true, hint: 'e.g. US Dollar', def: c?.name ?? ''),
    F('sym', 'Symbol', req: true, hint: '\$', def: c?.symbol ?? ''),
    F('rate', 'Exchange Rate to Base (₹)', type: 'number', req: true, def: c == null ? '83.5' : c.rate.toString()),
    F('decimals', 'Decimal Places', type: 'number', def: (c?.decimals ?? 2).toString()),
    F('status', 'Status', type: 'select', req: true, def: c?.status ?? 'Active', options: opts(_status)),
  ], (v, _) {
    final code = (v['code'] as String).trim().toUpperCase();
    if (S.currencies.any((x) => x != c && x.code == code)) {
      toast('Currency $code already exists');
      return false;
    }
    final rate = (v['rate'] as num).toDouble();
    if (rate <= 0) {
      toast('Exchange rate must be more than 0');
      return false;
    }
    if (c != null && c.code == 'INR' && v['status'] == 'Inactive') {
      toast('INR is the base currency and stays active');
      return false;
    }
    final r = c ?? Currency(code, '', '', rate);
    r
      ..code = code
      ..name = (v['name'] as String).trim()
      ..symbol = (v['sym'] as String).trim()
      ..rate = rate
      ..decimals = ((v['decimals'] ?? 2) as num).toInt().clamp(0, 4)
      ..status = v['status'] as String;
    if (!edit) S.currencies.add(r);
    after(Res(edit ? 'Currency $code updated' : 'Currency $code added'));
    return false;
  }, btn: edit ? 'Save changes' : 'Save', icon: 'check');
}

void deleteCurrency(Currency c) {
  if (c.code == 'INR') {
    toast('INR is the base currency and cannot be deleted');
    return;
  }
  removeRecord('currency', c.code, const [], () => S.currencies.remove(c));
}

// ---------------------------------------------------------------- payment terms
void payTermForm([PayTerm? t]) {
  final edit = t != null;
  mform(edit ? 'Edit payment term · ${t.name}' : 'New payment term', [
    const F.header('General'),
    F('name', 'Payment Term Name', req: true, hint: 'e.g. Net 30 days', def: t?.name ?? ''),
    F('days', 'Due Days', type: 'number', req: true, def: (t?.days ?? 30).toString()),
    F('adv', 'Advance %', type: 'number', def: (t?.advance ?? 0).toString()),
    F('disc_days', 'Early Payment Discount Days', type: 'number', def: (t?.discDays ?? 0).toString()),
    F('disc_pct', 'Early Payment Discount %', type: 'number', def: (t?.discPct ?? 0).toString()),
    F('desc', 'Description', full: true, def: t?.desc ?? ''),
    F('status', 'Status', type: 'select', req: true, def: t?.status ?? 'Active', options: opts(_status)),
  ], (v, _) {
    final name = (v['name'] as String).trim();
    if (S.payTerms.any((x) => x != t && x.name.toLowerCase() == name.toLowerCase())) {
      toast('Payment term "$name" already exists');
      return false;
    }
    final days = (v['days'] as num).toInt();
    final adv = ((v['adv'] ?? 0) as num).toInt();
    if (days < 0 || adv < 0 || adv > 100) {
      toast('Due days cannot be negative, and advance must be between 0 and 100%');
      return false;
    }
    final r = t ?? PayTerm(name, days);
    r
      ..name = name
      ..days = days
      ..advance = adv
      ..discDays = ((v['disc_days'] ?? 0) as num).toInt()
      ..discPct = ((v['disc_pct'] ?? 0) as num).toDouble()
      ..desc = (v['desc'] ?? '').toString().trim()
      ..status = v['status'] as String;
    if (!edit) S.payTerms.add(r);
    after(Res(edit ? 'Payment term $name updated' : 'Payment term $name saved'));
    return false;
  }, btn: edit ? 'Save changes' : 'Save', icon: 'check');
}

void deletePayTerm(PayTerm t) => removeRecord('payment term', t.name, [
      for (final c in S.customers.where((c) => c.terms == t.days && t.days > 0)) 'Customer ${c.id} · ${c.name} (Net ${c.terms} days)',
      for (final s in S.suppliers.where((s) => s.terms == t.days && t.days > 0)) 'Supplier ${s.id} · ${s.name} (Net ${s.terms} days)',
    ].take(6).toList(), () => S.payTerms.remove(t), deactivate: () => t.status = 'Inactive');

// ---------------------------------------------------------------- tax codes
void taxCodeForm([TaxCode? t]) {
  final edit = t != null;
  // standard types, any custom ones already in use, and "Other" to type a new one
  const other = 'Other (enter your own)';
  final types = <String>['GST', 'Exempt', 'Zero Rated'];
  for (final x in S.taxCodes) {
    if (x.type.trim().isNotEmpty && !types.contains(x.type)) types.add(x.type);
  }
  mform(edit ? 'Edit tax code · ${t.name}' : 'New tax code', [
    const F.header('Tax Code'),
    F('name', 'Tax Code', req: true, hint: 'e.g. GST 18%', def: t?.name ?? ''),
    F('rate', 'Tax Rate %', type: 'number', req: true, def: (t?.rate ?? 18).toString().replaceAll(RegExp(r'\.0$'), '')),
    F('type', 'Tax Type', type: 'select', req: true, def: t?.type ?? 'GST', options: opts([...types, other])),
    const F('custom_type', 'Custom Tax Type', when: 'type', whenIs: other, hint: 'e.g. Cess, IGST, VAT, TCS'),
    F('status', 'Status', type: 'select', req: true, def: t?.status ?? 'Active', options: opts(_status)),
  ], (v, _) {
    final name = (v['name'] as String).trim();
    if (S.taxCodes.any((x) => x != t && x.name.toLowerCase() == name.toLowerCase())) {
      toast('Tax code "$name" already exists');
      return false;
    }
    var type = v['type'] as String;
    if (type == other) {
      type = (v['custom_type'] as String? ?? '').trim();
      if (type.isEmpty) {
        toast('Enter the Custom Tax Type');
        return false;
      }
      // reuse the existing spelling if this type is already in the list
      type = types.firstWhere((x) => x.toLowerCase() == type.toLowerCase(), orElse: () => type);
    }
    final rate = (v['rate'] as num).toDouble();
    if (rate < 0 || rate > 100) {
      toast('Tax rate must be between 0 and 100');
      return false;
    }
    final r = t ?? TaxCode(name, rate);
    r
      ..name = name
      ..rate = rate
      ..type = type
      ..status = v['status'] as String;
    if (!edit) S.taxCodes.add(r);
    after(Res(edit ? 'Tax code $name updated' : 'Tax code $name saved'));
    return false;
  }, btn: edit ? 'Save changes' : 'Save', icon: 'check');
}

void deleteTaxCode(TaxCode t) => removeRecord('tax code', t.name,
    [for (final p in S.items.where((p) => p.gst == t.rate.round() && S.taxNameFor(p.gst) == t.name)) 'Item ${p.id} · ${p.name}'].take(6).toList(), () => S.taxCodes.remove(t),
    deactivate: () => t.status = 'Inactive');

// ---------------------------------------------------------------- T&C templates
void tcTemplateForm([TcTemplate? t]) {
  final edit = t != null;
  mform(edit ? 'Edit T&C template · ${t.name}' : 'New T&C template', [
    const F.header('General'),
    F('name', 'Template Name', req: true, hint: 'Standard Sales Terms', def: t?.name ?? ''),
    F('applies', 'Applies To', type: 'select', req: true, def: t?.applies ?? 'Sales', options: opts(['Sales', 'Purchase', 'Both'])),
    F('text', 'Terms Text', type: 'textarea', req: true, full: true, hint: '1. Goods once sold will not be taken back...', def: t?.text ?? ''),
    F('status', 'Status', type: 'select', req: true, def: t?.status ?? 'Active', options: opts(_status)),
  ], (v, _) {
    final name = (v['name'] as String).trim();
    if (S.tcTemplates.any((x) => x != t && x.name.toLowerCase() == name.toLowerCase())) {
      toast('Template "$name" already exists');
      return false;
    }
    final r = t ?? TcTemplate(name, 'Sales', '');
    r
      ..name = name
      ..applies = v['applies'] as String
      ..text = (v['text'] as String).trim()
      ..status = v['status'] as String;
    if (!edit) S.tcTemplates.add(r);
    after(Res(edit ? 'T&C template $name updated' : 'T&C template $name saved'));
    return false;
  }, btn: edit ? 'Save changes' : 'Save', icon: 'check');
}

void deleteTcTemplate(TcTemplate t) => removeRecord('T&C template', t.name, const [], () => S.tcTemplates.remove(t));

// ---------------------------------------------------------------- the screen
Widget _actions(VoidCallback edit, VoidCallback del) => Row(mainAxisSize: MainAxisSize.min, children: [
      IconBtn('edit', edit, size: 30, tip: 'Edit'),
      const SizedBox(width: 4),
      deleteIcon(del),
    ]);

Widget setupListsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Branches & Lists', sub: 'Branches, currencies, payment terms, tax codes and T&C templates · every form dropdown reads from these lists'),
      Tabs([
        TabDef('Branches', () => DataTableCard(
              id: 'lists-branches',
              rows: S.branches,
              exportName: 'branches',
              createLabel: 'New branch',
              onCreate: branchForm,
              onRow: (r) => branchForm(r as Branch),
              rowActions: (r) => _actions(() => branchForm(r as Branch), () => deleteBranch(r)),
              cols: [
                Col('Branch', (r) => CellTwo((r as Branch).name, r.company), text: (r) => (r as Branch).name),
                Col.t('City', (r) => (r as Branch).city),
                Col.t('State', (r) => (r as Branch).state),
                Col.t('Manager', (r) => (r as Branch).manager.isEmpty ? '—' : r.manager),
                Col.t('Warehouses', (r) => '${S.warehouses.where((w) => w.branch == (r as Branch).name).length}'),
                Col('Status', (r) => StatusBadge((r as Branch).status), status: true, text: (r) => (r as Branch).status),
              ],
            )),
        TabDef('Currencies', () => DataTableCard(
              id: 'lists-currencies',
              rows: S.currencies,
              exportName: 'currencies',
              createLabel: 'New currency',
              onCreate: currencyForm,
              onRow: (r) => currencyForm(r as Currency),
              rowActions: (r) => _actions(() => currencyForm(r as Currency), () => deleteCurrency(r)),
              cols: [
                Col('Currency', (r) => CellTwo((r as Currency).code, r.name), text: (r) => (r as Currency).code),
                Col.t('Symbol', (r) => (r as Currency).symbol),
                Col.t('Rate to ₹', (r) => (r as Currency).rate.toString()),
                Col.t('Decimals', (r) => '${(r as Currency).decimals}'),
                Col('Status', (r) => StatusBadge((r as Currency).status), status: true, text: (r) => (r as Currency).status),
              ],
            )),
        TabDef('Payment Terms', () => DataTableCard(
              id: 'lists-terms',
              rows: S.payTerms,
              exportName: 'payment-terms',
              createLabel: 'New payment term',
              onCreate: payTermForm,
              onRow: (r) => payTermForm(r as PayTerm),
              rowActions: (r) => _actions(() => payTermForm(r as PayTerm), () => deletePayTerm(r)),
              cols: [
                Col('Payment Term', (r) => CellTwo((r as PayTerm).name, r.desc.isEmpty ? '—' : r.desc), text: (r) => (r as PayTerm).name),
                Col.t('Due Days', (r) => '${(r as PayTerm).days}'),
                Col.t('Advance', (r) => '${(r as PayTerm).advance}%'),
                Col.t('Early Discount', (r) => (r as PayTerm).discPct == 0 ? '—' : '${r.discPct}% in ${r.discDays} days'),
                Col('Status', (r) => StatusBadge((r as PayTerm).status), status: true, text: (r) => (r as PayTerm).status),
              ],
            )),
        TabDef('Tax Codes', () => DataTableCard(
              id: 'lists-taxes',
              rows: S.taxCodes,
              exportName: 'tax-codes',
              createLabel: 'New tax code',
              onCreate: taxCodeForm,
              onRow: (r) => taxCodeForm(r as TaxCode),
              rowActions: (r) => _actions(() => taxCodeForm(r as TaxCode), () => deleteTaxCode(r)),
              cols: [
                Col('Tax Code', (r) => Text((r as TaxCode).name, style: tsB), text: (r) => (r as TaxCode).name),
                Col.t('Type', (r) => (r as TaxCode).type),
                Col.t('Rate', (r) => '${(r as TaxCode).rate}%'),
                Col.t('Split', (r) => (r as TaxCode).type == 'GST' ? 'CGST ${r.rate / 2}% + SGST ${r.rate / 2}% (inter-state IGST ${r.rate}%)' : '—'),
                Col.t('Items using it', (r) => '${S.items.where((p) => S.taxNameFor(p.gst) == (r as TaxCode).name).length}'),
                Col('Status', (r) => StatusBadge((r as TaxCode).status), status: true, text: (r) => (r as TaxCode).status),
              ],
            )),
        TabDef('T&C Templates', () => DataTableCard(
              id: 'lists-tnc',
              rows: S.tcTemplates,
              exportName: 'tc-templates',
              createLabel: 'New template',
              onCreate: tcTemplateForm,
              onRow: (r) => tcTemplateForm(r as TcTemplate),
              rowActions: (r) => _actions(() => tcTemplateForm(r as TcTemplate), () => deleteTcTemplate(r)),
              cols: [
                Col('Template', (r) => Text((r as TcTemplate).name, style: tsB), text: (r) => (r as TcTemplate).name),
                Col.t('Applies To', (r) => (r as TcTemplate).applies),
                Col.t('Terms', (r) => (r as TcTemplate).text.split('\n').first),
                Col('Status', (r) => StatusBadge((r as TcTemplate).status), status: true, text: (r) => (r as TcTemplate).status),
              ],
            )),
      ], storeKey: 'setup-lists'),
    ]);
