import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../ui/overlays.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'logistics.dart' show drivers, Driver;

/// Deleting master records (customer, supplier, item, warehouse, bin, vehicle, driver…).
///
/// A record can be deleted only while nothing uses it. When it is used by orders,
/// stock or other records, deleting it would break that history, so the page
/// explains where it is used and offers "Mark inactive" instead (where the record
/// has a status): it then disappears from new forms but its history stays.
void removeRecord(String kind, String name, List<String> usedIn, VoidCallback remove, {VoidCallback? deactivate}) {
  if (usedIn.isNotEmpty) {
    openModal(
      'Cannot delete $kind',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        NoteBox(Tone.amber, 'lock', '$name is in use.',
            deactivate != null ? 'Deleting it would break these records. Mark it inactive instead: it will no longer be offered on new forms, and its history stays.' : 'Deleting it would break these records. Remove or complete them first.'),
        const SizedBox(height: 12),
        for (final u in usedIn) ActivityRow('file', u, '', tone: Tone.gray),
      ]),
      size: ModalSize.narrow,
      actions: (c) => [
        Btn.secondary('Close', onTap: () => Navigator.of(c).pop()),
        if (deactivate != null)
          Btn('Mark inactive', icon: 'lock', onTap: () {
            deactivate();
            closeAll();
            S.refresh();
            toast('$name marked inactive');
          }),
      ],
    );
    return;
  }
  confirmDelete('$kind "$name"', () {
    remove();
    closeAll();
    S.refresh();
    toast('$name deleted');
  });
}

/// "N sales orders" style summary of the documents that point at a record.
List<String> _docUse(bool Function(Doc d) test) {
  final byType = <String, int>{};
  for (final d in S.docs.where(test)) {
    byType[d.type] = (byType[d.type] ?? 0) + 1;
  }
  return [for (final e in byType.entries) '${e.value} ${S.dt[e.key]?.label ?? e.key}${e.value == 1 ? '' : 's'}'];
}

bool _hasStock(String item) => S.warehouses.any((w) => S.stk(w.id, item).onhand > 0);

// ---------------------------------------------------------------- per record type
void deleteCustomer(Customer c) => removeRecord(
      'customer',
      c.name,
      [
        ..._docUse((d) => d.party == c.id),
        if (S.opps.any((o) => o.party == c.id)) '${S.opps.where((o) => o.party == c.id).length} opportunity / opportunities',
      ],
      () {
        S.customers.remove(c);
        S.contacts.removeWhere((x) => x.cust == c.id);
      },
      deactivate: c.status == 'Inactive' ? null : () => c.status = 'Inactive',
    );

void deleteSupplier(Supplier s) => removeRecord(
      'supplier',
      s.name,
      [
        ..._docUse((d) => d.party == s.id),
        if (S.items.any((p) => p.sup == s.id)) 'Preferred supplier of ${S.items.where((p) => p.sup == s.id).length} item(s)',
      ],
      () => S.suppliers.remove(s),
      deactivate: s.status == 'Inactive' ? null : () => s.status = 'Inactive',
    );

void deleteItem(Item p) => removeRecord(
      'item',
      p.name,
      [
        ..._docUse((d) => d.lines.any((l) => l.item == p.id)),
        if (_hasStock(p.id)) 'Stock on hand in the warehouse',
        if (S.ledger.any((e) => e.item == p.id)) 'Stock ledger entries',
        if (S.batches.any((b) => b.item == p.id)) 'Batches',
        if (S.opps.any((o) => o.lines.any((l) => l.item == p.id))) 'Opportunities',
      ],
      () => S.items.remove(p),
    );

void deleteWarehouse(Warehouse w) => removeRecord(
      'warehouse',
      '${w.code} — ${w.name}',
      [
        if (S.currentWh.id == w.id) 'It is the warehouse you are working in now (switch warehouse first)',
        if (S.warehouses.length == 1) 'It is the only warehouse',
        ..._docUse((d) => d.wh == w.id || d.to == w.id),
        if (S.items.any((p) => S.stk(w.id, p.id).onhand > 0)) 'Stock on hand',
        if (S.bins.any((b) => b.wh == w.id)) '${S.bins.where((b) => b.wh == w.id).length} bin(s)',
      ],
      () => S.warehouses.remove(w),
    );

void deleteBin(Bin b) => removeRecord(
      'bin',
      b.code,
      [if (b.use > 0) 'Holds stock (${b.use}% used)'],
      () => S.bins.remove(b),
    );

void deleteVehicle(Vehicle v) => removeRecord(
      'vehicle',
      v.name.split(' (').first,
      _docUse((d) => d.vehicle == v.name && !['Delivered', 'Completed', 'Closed'].contains(d.status)),
      () => S.fleet.remove(v),
    );

void deleteDriver(Driver d) => removeRecord(
      'driver',
      d.name,
      [for (final v in S.fleet.where((v) => v.driver == d.name)) 'Assigned to vehicle ${v.name.split(' (').first}'],
      () => drivers.remove(d),
      deactivate: d.status == 'Inactive' ? null : () => d.status = 'Inactive',
    );

void deleteSalesPerson(SalesPerson s) => removeRecord(
      'sales person',
      s.name,
      [
        if (S.leads.any((l) => l.owner == s.name)) 'Owner of ${S.leads.where((l) => l.owner == s.name).length} lead(s)',
        if (S.opps.any((o) => o.owner == s.name)) 'Owner of ${S.opps.where((o) => o.owner == s.name).length} opportunity / opportunities',
      ],
      () => S.salesPersons.remove(s),
      deactivate: s.status == 'Inactive' ? null : () => s.status = 'Inactive',
    );

void deletePriceList(PriceList p) => removeRecord(
      'price list',
      p.name,
      [if (S.customers.any((c) => c.group == p.group) && S.priceLists.where((x) => x.group == p.group).length == 1) 'Used by ${S.customers.where((c) => c.group == p.group).length} customer(s) in ${p.group}'],
      () => S.priceLists.remove(p),
      deactivate: p.status == 'Inactive' ? null : () => p.status = 'Inactive',
    );

void deleteContact(Contact c) => removeRecord('contact', c.name, const [], () => S.contacts.remove(c));

void deleteLead(Lead l) => removeRecord(
      'lead',
      l.company,
      [if (l.opp != null) 'Converted to opportunity ${l.opp}'],
      () => S.leads.remove(l),
    );

void deleteOpp(Opportunity o) => removeRecord(
      'opportunity',
      o.title,
      [if (o.quote != null) 'Quotation ${o.quote}'],
      () => S.opps.remove(o),
    );

void deleteBatch(Batch b) => removeRecord(
      'batch',
      b.id,
      [
        if (b.qty > 0) '${b.qty} units still in stock',
        ..._docUse((d) => d.lines.any((l) => l.batch == b.id)),
      ],
      () => S.batches.remove(b),
    );

void deleteCategory(String cat) => removeRecord(
      'item category',
      cat,
      [if (S.items.any((p) => p.cat == cat)) '${S.items.where((p) => p.cat == cat).length} item(s)'],
      () => S.categories.remove(cat),
    );

void deleteUom(Uom u) => removeRecord(
      'unit',
      u.code,
      [if (S.items.any((p) => p.uom == u.code)) '${S.items.where((p) => p.uom == u.code).length} item(s)'],
      () => S.uoms.remove(u),
    );

void deleteCustomerGroup(CustomerGroup g) => removeRecord(
      'customer group',
      g.name,
      [if (S.customers.any((c) => c.group == g.name)) '${S.customers.where((c) => c.group == g.name).length} customer(s) are in this group'],
      () => S.customerGroups.remove(g),
    );

void deleteTerritory(Territory t) => removeRecord(
      'territory',
      t.name,
      [
        if (S.customers.any((c) => S.terrOf[c.id] == t.id)) '${S.customers.where((c) => S.terrOf[c.id] == t.id).length} customer(s) are in this territory',
        if (S.salesPersons.any((s) => s.terr == t.id)) '${S.salesPersons.where((s) => s.terr == t.id).length} sales person(s) work in this territory',
      ],
      () => S.territories.remove(t),
    );

void deleteSerial(Serial s) => removeRecord(
      'serial number',
      s.id,
      [
        if (s.status != 'Available' && s.status != 'Scrapped') 'It is ${s.status}',
        ..._docUse((d) => d.lines.any((l) => l.batch.split(RegExp(r'[,;\s]+')).contains(s.id))),
      ],
      () => S.serials.remove(s),
    );

void deleteAgreement(TradeAgreement a) => removeRecord('trade agreement', a.id, const [], () => S.tradeAgreements.remove(a));

/// The red Delete button used on record pages.
Widget deleteBtn(VoidCallback onTap) => Btn.danger('Delete', icon: 'trash', onTap: onTap);

/// Small trash icon for table rows.
Widget deleteIcon(VoidCallback onTap) => IconBtn('trash', onTap, size: 30, tip: 'Delete');

/// Choose a warehouse, then delete it (only when nothing uses it).
void deleteWarehousePick() {
  mform('Delete warehouse', [
    F('wh', 'Warehouse', type: 'select', req: true, full: true, options: [for (final w in S.warehouses) Opt(w.id, '${w.code} — ${w.name}')]),
  ], (v, ctx) {
    final w = S.warehouses.where((x) => x.id == v['wh']).firstOrNull;
    if (w == null) return false;
    Navigator.of(ctx).pop();
    deleteWarehouse(w);
    return false;
  }, btn: 'Continue', icon: 'trash');
}
