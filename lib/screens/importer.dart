import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/overlays.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart' show after;
import 'edit_forms.dart' show termDays, leadSources, rememberLeadSource;
import 'masters.dart' show gstinOk;

/// Import of Customers, Suppliers, Items and Leads from pasted CSV.
/// Each row is checked like the create form checks it; valid rows become real records,
/// rows with a problem are skipped and the reason is shown.
class ImportSpec {
  final String title;
  final List<String> columns;
  final List<String> required;
  /// Returns the problem with a row, or null when the row is fine.
  final String? Function(Map<String, String> r) check;
  /// Creates the record from a checked row and returns its id.
  final String Function(Map<String, String> r) create;
  const ImportSpec(this.title, this.columns, this.required, this.check, this.create);
}

String _g(Map<String, String> r, String k) => (r[k] ?? '').trim();

double? _num(String s) => s.isEmpty ? null : double.tryParse(s.replaceAll(',', ''));

final Map<String, ImportSpec> importSpecs = {
  'cust': ImportSpec('Customers', const ['Name', 'City', 'State', 'GSTIN', 'Group', 'Payment Terms', 'Credit Limit', 'Contact', 'Phone', 'Email', 'Address'], const ['Name', 'City', 'State'], (r) {
    if (!kStates.contains(_g(r, 'State'))) return 'State "${_g(r, 'State')}" is not a state or union territory of India';
    final gs = _g(r, 'GSTIN').toUpperCase();
    if (gs.isNotEmpty && !gstinOk(gs, _g(r, 'State'))) return 'GSTIN is wrong or does not match ${_g(r, 'State')}';
    if (S.customers.any((c) => c.name.toLowerCase() == _g(r, 'Name').toLowerCase())) return 'A customer named "${_g(r, 'Name')}" already exists';
    if (_g(r, 'Group').isNotEmpty && !S.customerGroups.any((g) => g.name == _g(r, 'Group'))) return 'Customer group "${_g(r, 'Group')}" does not exist';
    if (_g(r, 'Payment Terms').isNotEmpty && !S.termNames.contains(_g(r, 'Payment Terms'))) return 'Payment term "${_g(r, 'Payment Terms')}" is not in Branches & Lists';
    if (_g(r, 'Credit Limit').isNotEmpty && (_num(_g(r, 'Credit Limit')) ?? -1) < 0) return 'Credit limit must be a number';
    return null;
  }, (r) {
    final id = S.nextCustomerId();
    final gs = _g(r, 'GSTIN').toUpperCase();
    final group = _g(r, 'Group').isEmpty ? (S.customerGroups.firstOrNull?.name ?? 'Retail') : _g(r, 'Group');
    final c = Customer(id, _g(r, 'Name'), _g(r, 'City'), _g(r, 'State'), gs.isEmpty ? 'Unregistered' : gs, group, termDays(_g(r, 'Payment Terms').isEmpty ? 'Net 30 days' : _g(r, 'Payment Terms')),
        _num(_g(r, 'Credit Limit')) ?? 200000, _g(r, 'Contact').isEmpty ? '—' : _g(r, 'Contact'), _g(r, 'Phone'), 'Active')
      ..email = _g(r, 'Email')
      ..billTo = _g(r, 'Address')
      ..shipTo = _g(r, 'Address')
      ..gstType = gs.isEmpty ? 'Unregistered' : 'Registered';
    S.customers.add(c);
    S.syncCustomerAddresses(c);
    return id;
  }),
  'sup': ImportSpec('Suppliers', const ['Name', 'City', 'State', 'GSTIN', 'Payment Terms', 'Lead Time Days', 'Contact', 'Phone', 'Email', 'Address'], const ['Name', 'City', 'State'], (r) {
    if (!kStates.contains(_g(r, 'State'))) return 'State "${_g(r, 'State')}" is not a state or union territory of India';
    final gs = _g(r, 'GSTIN').toUpperCase();
    if (gs.isNotEmpty && !gstinOk(gs, _g(r, 'State'))) return 'GSTIN is wrong or does not match ${_g(r, 'State')}';
    if (S.suppliers.any((s) => s.name.toLowerCase() == _g(r, 'Name').toLowerCase())) return 'A supplier named "${_g(r, 'Name')}" already exists';
    if (_g(r, 'Payment Terms').isNotEmpty && !S.termNames.contains(_g(r, 'Payment Terms'))) return 'Payment term "${_g(r, 'Payment Terms')}" is not in Branches & Lists';
    if (_g(r, 'Lead Time Days').isNotEmpty && (int.tryParse(_g(r, 'Lead Time Days')) ?? -1) < 0) return 'Lead time must be a whole number of days';
    return null;
  }, (r) {
    final id = S.nextSupplierId();
    final gs = _g(r, 'GSTIN').toUpperCase();
    S.suppliers.add(Supplier(id, _g(r, 'Name'), _g(r, 'City'), _g(r, 'State'), gs.isEmpty ? 'Unregistered' : gs, termDays(_g(r, 'Payment Terms').isEmpty ? 'Net 30 days' : _g(r, 'Payment Terms')),
        int.tryParse(_g(r, 'Lead Time Days')) ?? 5, 0, 0, 0, _g(r, 'Contact').isEmpty ? '—' : _g(r, 'Contact'), 'Active')
      ..phone = _g(r, 'Phone')
      ..email = _g(r, 'Email')
      ..address = _g(r, 'Address')
      ..gstType = gs.isEmpty ? 'Unregistered' : 'Registered');
    return id;
  }),
  'itm': ImportSpec('Items', const ['Name', 'Category', 'HSN', 'UoM', 'Tax Code', 'Cost', 'Price', 'Reorder Level'], const ['Name', 'Category', 'Cost', 'Price'], (r) {
    if (!S.categories.contains(_g(r, 'Category'))) return 'Category "${_g(r, 'Category')}" does not exist (add it under Item Categories first)';
    if (_g(r, 'UoM').isNotEmpty && !S.uoms.any((u) => u.code == _g(r, 'UoM'))) return 'Unit "${_g(r, 'UoM')}" does not exist';
    if (_g(r, 'Tax Code').isNotEmpty && !S.taxNames.contains(_g(r, 'Tax Code'))) return 'Tax code "${_g(r, 'Tax Code')}" is not in Branches & Lists';
    final cost = _num(_g(r, 'Cost')), price = _num(_g(r, 'Price'));
    if (cost == null || cost < 0) return 'Cost must be a number';
    if (price == null || price < 0) return 'Price must be a number';
    if (price < cost) return 'Sale price is below cost';
    if (_g(r, 'Reorder Level').isNotEmpty && int.tryParse(_g(r, 'Reorder Level')) == null) return 'Reorder level must be a whole number';
    if (S.items.any((p) => p.name.toLowerCase() == _g(r, 'Name').toLowerCase())) return 'An item named "${_g(r, 'Name')}" already exists';
    return null;
  }, (r) {
    final id = S.nextItemId();
    final tax = _g(r, 'Tax Code').isEmpty ? 'GST 18%' : _g(r, 'Tax Code');
    S.items.add(Item(id, _g(r, 'Name'), _g(r, 'Category'), _g(r, 'HSN').isEmpty ? '6403' : _g(r, 'HSN'), S.taxRateOf(tax).round(), _g(r, 'UoM').isEmpty ? (S.uoms.firstOrNull?.code ?? 'Nos') : _g(r, 'UoM'),
        _num(_g(r, 'Cost'))!, _num(_g(r, 'Price'))!, int.tryParse(_g(r, 'Reorder Level')) ?? 50, 10, 5, 5, S.suppliers.firstOrNull?.id ?? '', 'None', [0, 0, 0]));
    for (final w in S.warehouses) {
      S.stock[w.id]![id] = StockCell(0);
    }
    return id;
  }),
  'lead': ImportSpec('Leads', const ['Company', 'Contact', 'Phone', 'Email', 'Source', 'Sales Person', 'City', 'State', 'Product Interest', 'Estimated Value'], const ['Company', 'Contact', 'City'], (r) {
    if (_g(r, 'Phone').isEmpty && _g(r, 'Email').isEmpty) return 'Enter a mobile number or an email';
    if (_g(r, 'State').isNotEmpty && !kStates.contains(_g(r, 'State'))) return 'State "${_g(r, 'State')}" is not a state or union territory of India';
    if (_g(r, 'Sales Person').isNotEmpty && !S.salesPersons.any((s) => s.name == _g(r, 'Sales Person'))) return 'Sales person "${_g(r, 'Sales Person')}" does not exist';
    final it = _g(r, 'Product Interest');
    if (it.isNotEmpty && !S.items.any((p) => p.id == it || p.name.toLowerCase() == it.toLowerCase())) return 'Product "$it" is not an item (use the item code or name)';
    if (_g(r, 'Estimated Value').isNotEmpty && (_num(_g(r, 'Estimated Value')) ?? -1) < 0) return 'Estimated value must be a number';
    return null;
  }, (r) {
    final id = S.nextLeadId();
    final it = _g(r, 'Product Interest');
    final item = S.items.where((p) => p.id == it || p.name.toLowerCase() == it.toLowerCase()).firstOrNull ?? S.items.first;
    final src = _g(r, 'Source').isEmpty ? leadSources.first : _g(r, 'Source');
    S.leads.insert(
        0,
        Lead(id, _g(r, 'Company'), _g(r, 'Contact'), _g(r, 'City'), _g(r, 'State').isEmpty ? 'Andhra Pradesh' : _g(r, 'State'), src,
            _g(r, 'Sales Person').isEmpty ? (S.salesPersons.firstOrNull?.name ?? '') : _g(r, 'Sales Person'), _num(_g(r, 'Estimated Value')) ?? 100000, todayStr(), 'New', item.id)
          ..phone = _g(r, 'Phone')
          ..email = _g(r, 'Email'));
    rememberLeadSource(src);
    return id;
  }),
};

List<List<String>> _parseCsv(String txt) => txt.trim().split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).map((l) {
      final out = <String>[];
      var cur = StringBuffer();
      var q = false;
      for (var i = 0; i < l.length; i++) {
        final ch = l[i];
        if (ch == '"') {
          if (q && i + 1 < l.length && l[i + 1] == '"') {
            cur.write('"');
            i++;
          } else {
            q = !q;
          }
        } else if (ch == ',' && !q) {
          out.add(cur.toString());
          cur = StringBuffer();
        } else {
          cur.write(ch);
        }
      }
      out.add(cur.toString());
      return out;
    }).toList();

/// Opens the import window for the table [id] (only tables that have an [ImportSpec]).
void openImport(String id) {
  final spec = importSpecs[id]!;
  final paste = TextEditingController();
  List<Map<String, String>>? rows;
  String? headerProblem;

  openModal('Import ${spec.title.toLowerCase()}', StatefulBuilder(builder: (ctx, set) {
    if (rows == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border, width: 1.5)),
          child: Column(children: [
            const Icon(Icons.upload_outlined, color: C.soft),
            const SizedBox(height: 6),
            Text('Paste ${spec.title.toLowerCase()} as CSV (first row = column names)', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Columns: ${spec.columns.join(', ')}\nMandatory: ${spec.required.join(', ')}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: C.faint)),
            const SizedBox(height: 10),
            TextField(controller: paste, maxLines: 6, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), decoration: InputDecoration(hintText: '${spec.columns.join(',')}\n…')),
            if (headerProblem != null) ...[
              const SizedBox(height: 8),
              Text(headerProblem!, style: const TextStyle(fontSize: 12, color: C.red, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 8, children: [
          Btn.ghost('Add column names', icon: 'download', small: true, onTap: () {
            paste.text = '${spec.columns.join(',')}\n';
            toast('Column names added — type the rows below them');
          }),
          Btn('Check rows', icon: 'check', small: true, onTap: () {
            if (paste.text.trim().isEmpty) {
              toast('Paste the CSV text first');
              return;
            }
            final all = _parseCsv(paste.text);
            final head = all.first.map((h) => h.trim()).toList();
            final missing = [for (final c in spec.required) if (!head.any((h) => h.toLowerCase() == c.toLowerCase())) c];
            if (missing.isNotEmpty) {
              set(() => headerProblem = 'The first row must have the column${missing.length > 1 ? 's' : ''}: ${missing.join(', ')}');
              return;
            }
            // match columns by name, whatever the order
            final names = {for (final c in spec.columns) c.toLowerCase(): c};
            set(() {
              headerProblem = null;
              rows = [
                for (final line in all.skip(1))
                  {
                    for (var i = 0; i < head.length && i < line.length; i++)
                      if (names.containsKey(head[i].toLowerCase())) names[head[i].toLowerCase()]!: line[i].trim(),
                  }
              ];
            });
          }),
        ]),
      ]);
    }

    // check every row the way the create form does, and also catch the same name twice in the file
    final seen = <String>{};
    final problems = <String?>[];
    for (final r in rows!) {
      final blank = spec.required.firstWhere((c) => _g(r, c).isEmpty, orElse: () => '');
      String? p = blank.isNotEmpty ? '$blank is missing' : spec.check(r);
      final key = _g(r, spec.required.first).toLowerCase();
      if (p == null && !seen.add(key)) p = 'Appears twice in this file';
      problems.add(p);
    }
    final ok = [for (var i = 0; i < rows!.length; i++) if (problems[i] == null) rows![i]];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RGrid(max: 3, minTile: 150, children: [
        StatCard(Stat('Rows read', '${rows!.length}', 'File', 'file', Tone.blue)),
        StatCard(Stat('Ready to import', '${ok.length}', 'Valid', 'check', Tone.green)),
        StatCard(Stat('Skipped', '${rows!.length - ok.length}', 'Problem', 'alert', Tone.red, up: false)),
      ]),
      const SizedBox(height: 12),
      for (var i = 0; i < rows!.length && i < 8; i++)
        ActivityRow(problems[i] == null ? 'check' : 'alert', _g(rows![i], spec.required.first), problems[i] ?? 'Ready to import',
            tone: problems[i] == null ? Tone.green : Tone.red, trailing: StatusBadge(problems[i] == null ? 'OK' : 'Skipped')),
      if (rows!.length > 8) Padding(padding: const EdgeInsets.only(top: 6), child: Text('…and ${rows!.length - 8} more row(s)', style: const TextStyle(fontSize: 12, color: C.faint))),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.end, spacing: 10, children: [
        Btn.secondary('Back', onTap: () => set(() => rows = null)),
        Btn('Import ${ok.length} ${spec.title.toLowerCase()}', icon: 'check', onTap: ok.isEmpty
            ? null
            : () {
                final ids = [for (final r in ok) spec.create(r)];
                S.addAutoLog('Data import', '${ids.length} ${spec.title.toLowerCase()} imported · ${ids.first}${ids.length > 1 ? ' to ${ids.last}' : ''} · ${rows!.length - ok.length} skipped', ids.join(', '), 'Import · ${S.user?.name ?? 'User'}');
                after(Res('${ids.length} ${spec.title.toLowerCase()} imported${rows!.length > ok.length ? ' · ${rows!.length - ok.length} skipped' : ''}'));
              }),
      ]),
    ]);
  }), size: ModalSize.wide);
}
