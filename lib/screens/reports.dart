import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/report_template.dart';
import '../core/export_helper.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../ui/export_options.dart';
import '../ui/overlays.dart';
import '../ui/select.dart';
import '../ui/table.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart' show sortedDocs;

Widget _money(double v, {Color? color, bool bold = false}) => Text(fmtINR(v), style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color));

// Custom generic row data class for sample data
class RepRow {
  final Map<String, String> data;
  final double? numVal;
  RepRow(this.data, [this.numVal]);
  String get(String key) => data[key] ?? '—';
}

class ReportTableCard extends StatefulWidget {
  final String id;
  final String title;
  final String exportFilename;
  final List rows;
  final List<Col> cols;
  final List<Filt> filters;
  final String Function(dynamic r)? search;
  final int pageSize;
  /// Key figures for the rows currently shown (after search and filters).
  final List<(String, String)> Function(List rows)? summary;

  const ReportTableCard({
    super.key,
    required this.id,
    required this.title,
    required this.exportFilename,
    required this.rows,
    required this.cols,
    this.filters = const [],
    this.search,
    this.pageSize = 8,
    this.summary,
  });

  static final Map<String, _ReportMem> _mem = {};
  @override
  State<ReportTableCard> createState() => _ReportTableCardState();
}

class _ReportMem {
  int page = 1;
  int? sortCol;
  bool asc = true;
  String q = '';
  final Map<int, String> f = {};
}

class _ReportTableCardState extends State<ReportTableCard> {
  /// Columns left out in Setup › Company Settings › Report Templates are hidden here and in the downloads.
  List<Col> get _cols {
    final shown = widget.cols.where((c) => reportTemplate.shows(widget.title, c.label)).toList();
    return shown.isEmpty ? widget.cols : shown;
  }

  late _ReportMem m;
  final _search = TextEditingController();
  final _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    m = ReportTableCard._mem.putIfAbsent(widget.id, () => _ReportMem());
    _search.text = m.q;
  }

  @override
  void dispose() {
    _search.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  List get _filtered {
    var rows = widget.rows.where((r) {
      if (m.q.isNotEmpty) {
        final hay = (widget.search != null ? widget.search!(r) : _cols.map((c) => c.text?.call(r) ?? '').join(' ')).toLowerCase();
        if (!hay.contains(m.q.toLowerCase())) return false;
      }
      for (final e in m.f.entries) {
        if (e.key >= widget.filters.length) continue;
        if (e.value.isNotEmpty && widget.filters[e.key].value(r) != e.value) return false;
      }
      return true;
    }).toList();
    if (m.sortCol != null && _cols[m.sortCol!].sort != null) {
      final s = _cols[m.sortCol!].sort!;
      rows.sort((a, b) {
        final c = s(a).compareTo(s(b));
        return m.asc ? c : -c;
      });
    }
    return rows;
  }

  /// Exactly what the report shows on screen: all columns, every filtered row (not just the current page).
  ({List<String> headers, List<List<String>> data, Map<String, String> filters}) _snapshot(List rows) {
    final cols = _cols.where((c) => c.label.trim().isNotEmpty).toList();
    final filters = <String, String>{};
    if (m.q.isNotEmpty) filters['Search'] = m.q;
    for (var i = 0; i < widget.filters.length; i++) {
      final v = m.f[i];
      if (v != null && v.isNotEmpty) filters[widget.filters[i].label] = v;
    }
    return (headers: cols.map((c) => c.label).toList(), data: rows.map((r) => cols.map((c) => colText(c, r)).toList()).toList(), filters: filters);
  }

  /// Export Excel / Export PDF: first choose the columns, then the file is made. The button pressed is the main one.
  void _export(List rows, {required bool pdf}) {
    final s = _snapshot(rows);
    final title = reportTemplate.titleOf(widget.title);
    final summary = widget.summary?.call(rows);
    Future<void> excel(List<String> h, List<List<String>> d) async {
      final f = await exportExcel(widget.exportFilename, title, h, d, activeFilters: s.filters, summary: summary);
      toast('Downloaded $f · ${rows.length} records');
    }

    Future<void> pdfFile(List<String> h, List<List<String>> d) async {
      final f = await exportPdf(widget.exportFilename, title, h, d, activeFilters: s.filters, summary: summary);
      toast('Downloaded $f · ${rows.length} records (also opened in a new tab)');
    }

    final xl = ('Export Excel', 'download', excel), pf = ('Export PDF', 'file', pdfFile);
    openColumnExport(
      title: 'Export · $title',
      rememberAs: 'report:${widget.exportFilename}',
      headers: s.headers,
      rows: s.data,
      outputs: pdf ? [xl, pf] : [pf, xl],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final rows = _filtered;
    final ps = widget.pageSize;
    final total = rows.length;
    final pages = total == 0 ? 1 : (total / ps).ceil();
    if (m.page > pages) m.page = pages;
    final slice = rows.skip((m.page - 1) * ps).take(ps).toList();

    final toolbar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: mobile ? double.infinity : 210,
            child: TextField(
              controller: _search,
              style: const TextStyle(fontSize: 12.8),
              decoration: const InputDecoration(
                hintText: 'Search report data…',
                prefixIcon: Icon(Icons.search, size: 16, color: C.faint),
                prefixIconConstraints: BoxConstraints(minWidth: 34),
                fillColor: C.bg,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              onChanged: (v) => setState(() {
                m.q = v;
                m.page = 1;
              }),
            ),
          ),
          for (var i = 0; i < widget.filters.length; i++) _filterBox(i),
          if (m.q.isNotEmpty || m.f.values.any((v) => v.isNotEmpty))
            Btn.ghost('Reset', small: true, onTap: () => setState(() {
              m.q = '';
              m.f.clear();
              _search.clear();
              m.page = 1;
            })),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Btn.secondary('Export Excel', icon: 'download', small: true, onTap: () => _export(rows, pdf: false)),
          Btn.secondary('Export PDF', icon: 'file', small: true, onTap: () => _export(rows, pdf: true)),
        ]),
      ]),
    );

    final pager = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
        Text('Showing ${total == 0 ? 0 : (m.page - 1) * ps + 1}–${(m.page * ps).clamp(0, total)} of $total records', style: const TextStyle(fontSize: 12, color: C.faint)),
        Wrap(runSpacing: 4, children: [
          _pg('‹ Prev', false, () => setState(() => m.page = m.page > 1 ? m.page - 1 : 1)),
          for (var p = 1; p <= (pages < 5 ? pages : 5); p++) _pg('$p', p == m.page, () => setState(() => m.page = p)),
          _pg('Next ›', false, () => setState(() => m.page = m.page < pages ? m.page + 1 : pages)),
        ]),
      ]),
    );

    final figs = widget.summary?.call(rows) ?? const <(String, String)>[];
    final totals = _totals(rows);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (figs.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth >= 900 ? figs.length.clamp(1, 4) : (c.maxWidth >= 280 ? 2 : 1);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final f in figs)
                SizedBox(
                  width: w,
                  child: CardBox(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.$1.toUpperCase(), style: const TextStyle(fontSize: 10.5, letterSpacing: .6, fontWeight: FontWeight.w700, color: C.faint)),
                      const SizedBox(height: 5),
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(f.$2, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.text))),
                    ]),
                  ),
                ),
            ]);
          }),
        ),
      CardBox(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          toolbar,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            color: C.bg,
            child: Text('As on ${todayStr()} · Warehouse ${S.currentWh.code} · ${rows.length} record${rows.length == 1 ? '' : 's'}${m.q.isNotEmpty || m.f.values.any((v) => v.isNotEmpty) ? ' · filtered' : ''}',
                style: const TextStyle(fontSize: 11.5, color: C.faint)),
          ),
          if (slice.isEmpty) const Empty('No records match these search or filter criteria.') else mobile ? _cards(slice) : _table(slice, totals, rows.length),
          if (mobile && totals.any((t) => t != null) && slice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 4),
              child: Wrap(spacing: 14, runSpacing: 4, children: [
                for (var i = 0; i < _cols.length; i++)
                  if (totals[i] != null) Text('${_cols[i].label}: ${totals[i]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          pager,
        ]),
      ),
    ]);
  }

  Widget _pg(String t, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: on ? C.blue600 : C.card, borderRadius: BorderRadius.circular(7), border: Border.all(color: on ? C.blue600 : C.border)),
            child: Text(t, style: TextStyle(fontSize: 12, color: on ? Colors.white : C.soft)),
          ),
        ),
      );

  Widget _filterBox(int i) {
    final f = widget.filters[i];
    final v = m.f[i] ?? '';
    return ProtoSelect(
      kind: SelKind.filter,
      value: f.options.contains(v) ? v : '',
      options: [SelOpt('', '${f.label}: All'), for (final o in f.options) SelOpt(o, o)],
      onChanged: (val) => setState(() {
        m.f[i] = val;
        m.page = 1;
      }),
    );
  }

  int? _hover;

  /// Total of each money / quantity column over all filtered rows (null = no total).
  List<String?> _totals(List rows) {
    final key = RegExp(r'amount|value|sales|net|returns?$|qty|quantity|deficit|^quantity in|^quantity out|received|accepted|rejected|orders$|ordered|pending qty', caseSensitive: false);
    final skip = RegExp(r'date|number|no\.|level|status|%|on-time|delayed', caseSensitive: false);
    final out = <String?>[];
    for (final c in _cols) {
      if (rows.isEmpty || !c.num || !key.hasMatch(c.label) || skip.hasMatch(c.label)) {
        out.add(null);
        continue;
      }
      double sum = 0;
      String? unit;
      var money = false, ok = true;
      for (final r in rows) {
        final t = colText(c, r).trim();
        final mt = RegExp(r'^(-?)(₹?)([\d,]+(?:\.\d+)?)\s*(.*)$').firstMatch(t);
        if (mt == null) {
          ok = false;
          break;
        }
        money = money || mt.group(2)!.isNotEmpty;
        final u = mt.group(4)!.trim();
        if (unit != null && u != unit) {
          ok = false; // mixed units (e.g. Nos and Box) cannot be added up
          break;
        }
        unit = u;
        sum += (mt.group(1) == '-' ? -1 : 1) * double.parse(mt.group(3)!.replaceAll(',', ''));
      }
      out.add(!ok ? null : money ? fmtINR(sum) : '${fmtNum(sum)}${(unit ?? '').isEmpty || unit!.toLowerCase().startsWith('order') ? '' : ' $unit'}');
    }
    return out;
  }

  Widget _table(List slice, List<String?> totals, int count) {
    const thPad = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    const tdPad = EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    const thStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9AA3BA), letterSpacing: 0.5);

    Widget th(int colIdx, Widget child, {bool numeric = false}) {
      final sortable = _cols[colIdx].sort != null;
      // no sort arrow in the heading (clicking a heading still sorts)
      final cell = Padding(
        padding: thPad,
        child: Align(
          alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
          child: DefaultTextStyle(style: thStyle, child: child),
        ),
      );
      if (!sortable) return cell;
      return InkWell(
        onTap: () => setState(() {
          if (m.sortCol == colIdx) {
            m.asc = !m.asc;
          } else {
            m.sortCol = colIdx;
            m.asc = true;
          }
        }),
        child: cell,
      );
    }

    Widget td(int row, dynamic r, Widget child, {bool numeric = false}) {
      final cell = Padding(
        padding: tdPad,
        child: Align(
          alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
          child: DefaultTextStyle.merge(style: tsBody, child: child),
        ),
      );
      return MouseRegion(
        onEnter: (_) => setState(() => _hover = row),
        onExit: (_) => setState(() => _hover = _hover == row ? null : _hover),
        child: cell,
      );
    }

    final nCols = _cols.length;
    final rows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: C.navy900),
        children: [
          for (var i = 0; i < nCols; i++) th(i, Text(_cols[i].label.toUpperCase(), softWrap: false), numeric: _cols[i].num),
        ],
      ),
      for (var k = 0; k < slice.length; k++)
        TableRow(
          decoration: BoxDecoration(
            color: _hover == k ? C.bg : C.card,
            border: k < slice.length - 1 ? const Border(bottom: BorderSide(color: C.border)) : null,
          ),
          children: [
            for (final col in _cols) td(k, slice[k], col.cell(slice[k]), numeric: col.num),
          ],
        ),
      if (totals.any((t) => t != null))
        TableRow(
          decoration: const BoxDecoration(color: C.bg, border: Border(top: BorderSide(color: C.text, width: 1.2))),
          children: [
            for (var i = 0; i < nCols; i++)
              Padding(
                padding: tdPad,
                child: Align(
                  alignment: _cols[i].num ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(totals[i] ?? (i == 0 ? 'Total · $count records' : ''), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: C.text)),
                ),
              ),
          ],
        ),
    ];

    final widths = <int, TableColumnWidth>{
      for (var i = 0; i < nCols; i++) i: const ContentProportionalWidth(),
    };

    return LayoutBuilder(builder: (ctx, c) {
      return Scrollbar(
        controller: _hScroll,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: IntrinsicWidth(
              child: Table(
                columnWidths: widths,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: rows,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _cards(List slice) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: slice.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        final r = slice[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final c in _cols)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 2, child: Text(c.label, style: const TextStyle(fontSize: 11.5, color: C.faint, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 10),
                  // long values wrap on narrow screens instead of running off the edge
                  Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: c.cell(r))),
                ]),
              ),
          ]),
        );
      },
    );
  }
}

/// "Industrial Safety Helmet × 30 Nos, Barcode Label Roll × 40 Roll"
String _itemsOf(Doc d) => d.lines.isEmpty ? '—' : d.lines.map((l) => '${S.item(l.item).name} × ${l.qty} ${S.item(l.item).uom}').join(', ');

// ---------------------------------------------------------------- helpers for the register reports (all read the real documents)
String _wc(String id) => S.warehouses.where((w) => w.id == id).firstOrNull?.code ?? (id.isEmpty ? '—' : id);
String _cname(String? id) => id == null ? '—' : (S.customers.where((c) => c.id == id).firstOrNull?.name ?? id);
String _sname(String? id) => id == null ? '—' : (S.suppliers.where((s) => s.id == id).firstOrNull?.name ?? id);
int _units(Doc d) => d.lines.fold(0, (a, l) => a + l.qty);
String _qty(int n) => '$n Qty';
double _value(Doc d) => d.amount > 0 ? d.amount : S.calc(d).total;
String _driverOf(String? dnId) {
  final c = dnId == null ? null : S.doc(dnId)?.carrier;
  if (c == null || !c.contains('·')) return '—';
  return c.split('·').last.trim();
}
String _vehicleOf(String? dnId) => (dnId == null ? null : S.doc(dnId)?.vehicle) ?? '—';
String _vd(Doc d) => d.vehicle == null ? '—' : '${d.vehicle}${_driverOf(d.id) == '—' ? '' : ' / ${_driverOf(d.id)}'}';
/// The date the delivery note was marked Delivered (from its history).
String _deliveredOn(Doc d) {
  final e = d.log.where((x) => x.what.startsWith('Status → Delivered')).lastOrNull;
  return e == null ? '—' : e.when.split(' ').first;
}

class _SupTotal {
  final String name, status;
  int pos = 0, qty = 0, received = 0;
  double amount = 0, returned = 0;
  _SupTotal(this.name, this.status);
}

/// One line per supplier that has purchase orders: orders, quantity, value, goods received and value returned.
List<_SupTotal> _supplierTotals() {
  const skip = ['Draft', 'Cancelled', 'Rejected'];
  final out = <_SupTotal>[];
  for (final s in S.suppliers) {
    final pos = S.docsOf('PO').where((d) => d.party == s.id && !skip.contains(d.status)).toList();
    if (pos.isEmpty) continue;
    final t = _SupTotal(s.name, s.status)..pos = pos.length;
    for (final d in pos) {
      t.qty += _units(d);
      t.received += d.lines.fold(0, (a, l) => a + l.recv);
      t.amount += _value(d);
    }
    for (final r in S.docsOf('PRT').where((d) => d.party == s.id && d.status != 'Cancelled')) {
      t.returned += _value(r);
    }
    out.add(t);
  }
  return out;
}

/// One line per item bought on purchase orders: quantity, value and value returned.
List<RepRow> _itemPurchases() {
  const skip = ['Draft', 'Cancelled', 'Rejected'];
  final qty = <String, int>{}, amt = <String, double>{}, ret = <String, double>{};
  for (final d in S.docsOf('PO').where((d) => !skip.contains(d.status))) {
    for (final l in d.lines) {
      qty[l.item] = (qty[l.item] ?? 0) + l.qty;
      amt[l.item] = (amt[l.item] ?? 0) + l.qty * l.rate;
    }
  }
  for (final d in S.docsOf('PRT').where((d) => d.status != 'Cancelled')) {
    for (final l in d.lines) {
      ret[l.item] = (ret[l.item] ?? 0) + l.qty * l.rate;
    }
  }
  return [
    for (final id in qty.keys)
      RepRow({
        'item': S.item(id).name,
        'sup': _sname(S.item(id).sup),
        'cat': S.item(id).cat,
        'qty': _qty(qty[id]!),
        'amt': fmtINR(amt[id]!),
        'ret': fmtINR(ret[id] ?? 0),
      }),
  ];
}

/// One line per customer with orders: orders, sales value, delivered value, returns and what is still owed on invoices.
List<RepRow> _customerSales() {
  const skip = ['Draft', 'Cancelled', 'Rejected'];
  final out = <RepRow>[];
  for (final c in S.customers) {
    final so = S.docsOf('SO').where((d) => d.party == c.id && !skip.contains(d.status)).toList();
    if (so.isEmpty) continue;
    final sales = so.fold(0.0, (a, d) => a + _value(d));
    final delivered = so.where((d) => d.status == 'Delivered' || d.status == 'Closed').fold(0.0, (a, d) => a + _value(d));
    final returns = S.docsOf('SR').where((d) => d.party == c.id && d.status != 'Cancelled').fold(0.0, (a, d) => a + _value(d));
    final owed = S.docsOf('INV').where((d) => d.party == c.id && d.status != 'Cancelled').fold(0.0, (a, d) => a + (d.amount - d.paid));
    out.add(RepRow({'cust': c.name, 'orders': '${so.length} Orders', 'amt': fmtINR(sales), 'del': fmtINR(delivered), 'ret': fmtINR(returns), 'bal': fmtINR(owed), 'status': c.status}));
  }
  return out;
}

/// Every invoice and every payment received, newest first.
List<RepRow> _customerTransactions() {
  final list = <({String date, RepRow row})>[
    for (final d in S.docsOf('INV').where((d) => d.status != 'Cancelled'))
      (date: d.date, row: RepRow({'date': d.date, 'cust': _cname(d.party), 'type': 'Sales Invoice', 'ref': d.id, 'amt': fmtINR(d.amount), 'status': d.status})),
    for (final d in S.docsOf('CP'))
      (date: d.date, row: RepRow({'date': d.date, 'cust': _cname(d.party), 'type': 'Payment Received', 'ref': d.id, 'amt': fmtINR(d.amount), 'status': d.status})),
  ];
  list.sort((a, b) => b.date.compareTo(a.date));
  return [for (final e in list) e.row];
}

/// First number in a cell such as "₹1,23,456", "420 Nos" or "3 order(s)".
double _num(String s) {
  final m = RegExp(r'-?[\d,]+(\.\d+)?').firstMatch(s.replaceAll('₹', ''));
  return m == null ? 0 : double.parse(m.group(0)!.replaceAll(',', ''));
}

double _sum(List rows, String k) => rows.fold(0.0, (a, r) => a + _num((r as RepRow).get(k)));
int _cnt(List rows, String k, String v) => rows.where((r) => (r as RepRow).get(k) == v).length;
int _distinct(List rows, String k) => {for (final r in rows) (r as RepRow).get(k)}.length;

/// Filter choices taken from the report's own rows (live data).
List<String> _opts(List<RepRow> rows, String k) => ({for (final r in rows) r.get(k)}.toList()..sort());

// ================================================================ 1. SALES REPORTS
Widget salesOrderReportView() {
  final rows = [
    for (final d in sortedDocs(S.docsOf('SO')))
      RepRow({'no': d.id, 'date': d.date, 'cust': S.partyName(d), 'wh': S.wh(d.wh).code, 'items': _itemsOf(d), 'amt': fmtINR(d.amount), 'status': d.status}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Sales Order Register', sub: 'Detailed status of customer sales orders, financial values, and warehouse fulfillment'),
    ReportTableCard(
      id: 'rep-so',
      summary: (rows) => [('Orders', '${rows.length}'), ('Order value', fmtINR(_sum(rows, 'amt'))), ('Pending approval', '${_cnt(rows, 'status', 'Pending Approval')}'), ('Customers', '${_distinct(rows, 'cust')}')],
      title: 'Sales Order Register',
      exportFilename: 'Sales_Order_Register',
      rows: rows,
      filters: [
        Filt('Customer', _opts(rows, 'cust'), (r) => (r as RepRow).get('cust')),
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Order Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('Order Date', (r) => (r as RepRow).get('date')),
        Col.t('Customer', (r) => (r as RepRow).get('cust')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col('Items', (r) => SizedBox(width: 250, child: Text((r as RepRow).get('items'), style: const TextStyle(fontSize: 12.5))), text: (r) => (r as RepRow).get('items')),
        Col('Amount', (r) => Text((r as RepRow).get('amt'), style: tsB), text: (r) => (r as RepRow).get('amt'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget deliveryReportView() {
  final rows = [
    for (final d in S.docsOf('DN'))
      RepRow({'no': d.id, 'so': d.ref ?? '—', 'cust': _cname(d.party), 'date': d.date, 'wh': _wc(d.wh), 'qty': _qty(_units(d)), 'vd': _vd(d), 'status': d.status}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Delivery Report', sub: 'Outbound goods delivery notes, dispatched quantities, vehicle/driver log, and delivery status'),
    ReportTableCard(
      id: 'rep-dn',
      title: 'Delivery Report',
      exportFilename: 'Delivery_Report',
      rows: rows,
      filters: [
        Filt('Customer', _opts(rows, 'cust'), (r) => (r as RepRow).get('cust')),
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Delivery Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('Sales Order', (r) => (r as RepRow).get('so')),
        Col.t('Customer', (r) => (r as RepRow).get('cust')),
        Col.t('Delivery Date', (r) => (r as RepRow).get('date')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('Delivered Quantity', (r) => (r as RepRow).get('qty'), num: true),
        Col.t('Vehicle / Driver', (r) => (r as RepRow).get('vd')),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget salesReturnReportView() {
  final rows = [
    for (final d in S.docsOf('SR'))
      RepRow({'no': d.id, 'cust': _cname(d.party), 'del': d.ref ?? '—', 'date': d.date, 'item': _itemsOf(d), 'qty': _qty(_units(d)), 'reason': d.reason ?? '—', 'status': d.status}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Sales Return Register', sub: 'RMA customer returns, original delivery references, item return reasons, and disposition status'),
    ReportTableCard(
      id: 'rep-sr',
      title: 'Sales Return Register',
      exportFilename: 'Sales_Return_Register',
      rows: rows,
      filters: [
        Filt('Customer', _opts(rows, 'cust'), (r) => (r as RepRow).get('cust')),
        Filt('Reason', _opts(rows, 'reason'), (r) => (r as RepRow).get('reason')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Return Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('Customer', (r) => (r as RepRow).get('cust')),
        Col.t('Original Invoice', (r) => (r as RepRow).get('del')),
        Col.t('Return Date', (r) => (r as RepRow).get('date')),
        Col.t('Item', (r) => (r as RepRow).get('item')),
        Col.t('Quantity', (r) => (r as RepRow).get('qty'), num: true),
        Col.t('Reason', (r) => (r as RepRow).get('reason')),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget salesByCustomerReportView() {
  final rows = <RepRow>[];
  for (final c in S.customers) {
    final so = S.docsOf('SO').where((d) => d.party == c.id).toList();
    if (so.isEmpty) continue;
    final del = S.docsOf('DN').where((d) => d.party == c.id && ['Dispatched', 'Delivered'].contains(d.status)).fold<double>(0, (a, d) => a + d.amount);
    final ret = S.docsOf('SR').where((d) => d.party == c.id).fold<double>(0, (a, d) => a + d.amount);
    rows.add(RepRow({'cust': c.name, 'orders': '${so.length} order(s)', 'amt': fmtINR(so.fold<double>(0, (a, d) => a + d.amount)), 'del': fmtINR(del), 'ret': fmtINR(ret), 'status': c.status}));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Sales by Customer', sub: 'Customer sales performance summary, order volume, total sales amount, delivered values, and returns'),
    ReportTableCard(
      id: 'rep-sbc',
      summary: (rows) => [('Customers', '${rows.length}'), ('Orders', fmtNum(_sum(rows, 'orders'))), ('Sales amount', fmtINR(_sum(rows, 'amt'))), ('Returned', fmtINR(_sum(rows, 'ret')))],
      title: 'Sales by Customer',
      exportFilename: 'Sales_by_Customer',
      rows: rows,
      filters: [
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Customer', (r) => Text((r as RepRow).get('cust'), style: tsB), text: (r) => (r as RepRow).get('cust')),
        Col.t('Orders', (r) => (r as RepRow).get('orders'), num: true),
        Col('Sales Amount', (r) => Text((r as RepRow).get('amt'), style: tsB), text: (r) => (r as RepRow).get('amt'), num: true),
        Col.t('Delivered Amount', (r) => (r as RepRow).get('del'), num: true),
        Col.t('Returned Amount', (r) => (r as RepRow).get('ret'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget salesByItemReportView() {
  final rows = <RepRow>[];
  for (final it in S.items) {
    var qty = 0, retQty = 0;
    var amt = 0.0, ret = 0.0;
    for (final d in S.docsOf('SO')) {
      for (final l in d.lines.where((l) => l.item == it.id)) {
        qty += l.qty;
        amt += l.qty * l.rate;
      }
    }
    for (final d in S.docsOf('SR')) {
      for (final l in d.lines.where((l) => l.item == it.id)) {
        retQty += l.qty;
        ret += l.qty * l.rate;
      }
    }
    if (qty == 0) continue;
    rows.add(RepRow({'item': it.name, 'cat': it.cat, 'qty': '$qty ${it.uom}', 'amt': fmtINR(amt), 'ret': retQty == 0 ? '₹0' : fmtINR(ret), 'net': fmtINR(amt - ret), 'status': 'Active'}));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Sales by Item', sub: 'Product-wise sales quantity, total sales value, customer returns, and net sales revenue'),
    ReportTableCard(
      id: 'rep-sbi',
      summary: (rows) => [('Items sold', '${rows.length}'), ('Sales amount', fmtINR(_sum(rows, 'amt'))), ('Returns', fmtINR(_sum(rows, 'ret'))), ('Net sales', fmtINR(_sum(rows, 'net')))],
      title: 'Sales by Item',
      exportFilename: 'Sales_by_Item',
      rows: rows,
      filters: [
        Filt('Category', _opts(rows, 'cat'), (r) => (r as RepRow).get('cat')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Item', (r) => Text((r as RepRow).get('item'), style: tsB), text: (r) => (r as RepRow).get('item')),
        Col.t('Category', (r) => (r as RepRow).get('cat')),
        Col.t('Quantity Sold', (r) => (r as RepRow).get('qty'), num: true),
        Col('Sales Amount', (r) => Text((r as RepRow).get('amt'), style: tsB), text: (r) => (r as RepRow).get('amt'), num: true),
        Col.t('Returns', (r) => (r as RepRow).get('ret'), num: true),
        Col('Net Sales', (r) => Text((r as RepRow).get('net'), style: const TextStyle(fontWeight: FontWeight.w700, color: C.blue600)), text: (r) => (r as RepRow).get('net'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

// ================================================================ 2. PURCHASE REPORTS
Widget purchaseOrderReportView() {
  final rows = [
    for (final d in sortedDocs(S.docsOf('PO')))
      RepRow({'no': d.id, 'date': d.date, 'sup': S.partyName(d), 'wh': S.wh(d.wh).code,
          'items': _itemsOf(d),
          'qty': '${d.lines.fold<int>(0, (a, l) => a + l.qty)}', 'amt': fmtINR(d.amount), 'exp': d.delivery ?? d.need ?? '—', 'status': d.status}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Purchase Order Register', sub: 'Procurement orders, supplier details, warehouse target, ordered quantities, purchase values, and expected delivery'),
    ReportTableCard(
      id: 'rep-po',
      summary: (rows) => [('Purchase orders', '${rows.length}'), ('PO value', fmtINR(_sum(rows, 'amt'))), ('Waiting for goods', '${_cnt(rows, 'status', 'Sent to Supplier') + _cnt(rows, 'status', 'Partially Received')}'), ('Suppliers', '${_distinct(rows, 'sup')}')],
      title: 'Purchase Order Register',
      exportFilename: 'Purchase_Order_Register',
      rows: rows,
      filters: [
        Filt('Supplier', _opts(rows, 'sup'), (r) => (r as RepRow).get('sup')),
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('PO Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('PO Date', (r) => (r as RepRow).get('date')),
        Col.t('Supplier', (r) => (r as RepRow).get('sup')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col('Items', (r) => SizedBox(width: 250, child: Text((r as RepRow).get('items'), style: const TextStyle(fontSize: 12.5))), text: (r) => (r as RepRow).get('items')),
        Col.t('Quantity', (r) => (r as RepRow).get('qty'), num: true),
        Col('Purchase Amount', (r) => Text((r as RepRow).get('amt'), style: tsB), text: (r) => (r as RepRow).get('amt'), num: true),
        Col.t('Expected Delivery', (r) => (r as RepRow).get('exp')),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget pendingPoReportView() {
  final rows = [
    for (final d in S.docsOf('PO').where((d) => ['Sent to Supplier', 'Partially Received', 'Pending Approval'].contains(d.status)))
      () {
        final ordered = d.lines.fold<int>(0, (a, l) => a + l.qty);
        final recv = d.lines.fold<int>(0, (a, l) => a + l.recv);
        return RepRow({
          'no': d.id, 'date': d.date, 'sup': S.partyName(d), 'wh': S.wh(d.wh).code,
          'items': d.lines.where((l) => l.qty > l.recv).map((l) => '${S.item(l.item).name} × ${l.qty - l.recv} ${S.item(l.item).uom}').join(', '), 'ord': '$ordered', 'recv': '$recv', 'pend': '${ordered - recv}',
          'exp': d.delivery ?? d.need ?? '—', 'amt': fmtINR(d.amount), 'status': d.status,
        });
      }(),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Pending Purchase Orders', sub: 'Purchase orders where goods have not fully arrived — ordered, received and still pending quantity'),
    ReportTableCard(
      id: 'rep-pending-po',
      summary: (rows) => [('Pending POs', '${rows.length}'), ('Ordered qty', fmtNum(_sum(rows, 'ord'))), ('Still to receive', fmtNum(_sum(rows, 'pend'))), ('Pending value', fmtINR(_sum(rows, 'amt')))],
      title: 'Pending Purchase Orders',
      exportFilename: 'Pending_Purchase_Orders',
      rows: rows,
      filters: [
        Filt('Warehouse', S.warehouses.map((w) => w.code).toList(), (r) => (r as RepRow).get('wh')),
        Filt('Status', const ['Pending Approval', 'Sent to Supplier', 'Partially Received'], (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('PO Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('PO Date', (r) => (r as RepRow).get('date')),
        Col.t('Supplier', (r) => (r as RepRow).get('sup')),
        Col('Items Pending', (r) => SizedBox(width: 250, child: Text((r as RepRow).get('items'), style: const TextStyle(fontSize: 12.5))), text: (r) => (r as RepRow).get('items')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('Ordered Qty', (r) => (r as RepRow).get('ord'), num: true),
        Col.t('Received Qty', (r) => (r as RepRow).get('recv'), num: true),
        Col('Pending Qty', (r) => Text((r as RepRow).get('pend'), style: tsB), text: (r) => (r as RepRow).get('pend'), num: true),
        Col.t('Expected Delivery', (r) => (r as RepRow).get('exp')),
        Col.t('PO Amount', (r) => (r as RepRow).get('amt'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget grnReportView() {
  final rows = [
    for (final d in sortedDocs(S.docsOf('GRN')))
      () {
        final recd = d.lines.fold<int>(0, (a, l) => a + l.qty);
        final qc = !qcDone(d);
        final acc = qc ? 0 : d.lines.fold<int>(0, (a, l) => a + (l.acc > 0 ? l.acc : l.qty));
        return RepRow({'no': d.id, 'date': d.date, 'po': d.ref ?? '—', 'sup': S.partyName(d), 'items': _itemsOf(d), 'wh': S.wh(d.wh).code,
            'recd': '$recd', 'acc': qc ? 'QC pending' : '$acc', 'rej': qc ? '—' : '${recd - acc}', 'status': d.status});
      }(),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Goods Receipt Register', sub: 'Goods Receipt Notes, received quantity vs quality control accepted/rejected breakdown'),
    ReportTableCard(
      id: 'rep-grn',
      summary: (rows) => [('Goods receipts', '${rows.length}'), ('Received qty', fmtNum(_sum(rows, 'recd'))), ('Accepted qty', fmtNum(_sum(rows, 'acc'))), ('Rejected qty', fmtNum(_sum(rows, 'rej')))],
      title: 'Goods Receipt Register (GRN)',
      exportFilename: 'Goods_Receipt_Register',
      rows: rows,
      filters: [
        Filt('Supplier', _opts(rows, 'sup'), (r) => (r as RepRow).get('sup')),
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('GRN Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('GRN Date', (r) => (r as RepRow).get('date')),
        Col.t('PO Number', (r) => (r as RepRow).get('po')),
        Col.t('Supplier', (r) => (r as RepRow).get('sup')),
        Col('Items', (r) => SizedBox(width: 250, child: Text((r as RepRow).get('items'), style: const TextStyle(fontSize: 12.5))), text: (r) => (r as RepRow).get('items')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('Received Quantity', (r) => (r as RepRow).get('recd'), num: true),
        Col.t('Accepted Quantity', (r) => (r as RepRow).get('acc'), num: true),
        Col('Rejected Quantity', (r) => Text((r as RepRow).get('rej'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)), text: (r) => (r as RepRow).get('rej'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget purchaseReturnReportView() {
  final rows = [
    for (final d in S.docsOf('PRT'))
      RepRow({'no': d.id, 'sup': _sname(d.party), 'grn': d.ref ?? '—', 'date': d.date, 'item': _itemsOf(d), 'qty': _qty(_units(d)), 'reason': d.reason ?? '—', 'status': d.status}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Purchase Return Report', sub: 'Return to Vendor (RTV) transactions, original GRN link, return reason, and credit status'),
    ReportTableCard(
      id: 'rep-prt',
      title: 'Purchase Return Report',
      exportFilename: 'Purchase_Return_Report',
      rows: rows,
      filters: [
        Filt('Supplier', _opts(rows, 'sup'), (r) => (r as RepRow).get('sup')),
        Filt('Reason', _opts(rows, 'reason'), (r) => (r as RepRow).get('reason')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Return Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('Supplier', (r) => (r as RepRow).get('sup')),
        Col.t('Original GRN', (r) => (r as RepRow).get('grn')),
        Col.t('Return Date', (r) => (r as RepRow).get('date')),
        Col.t('Item', (r) => (r as RepRow).get('item')),
        Col.t('Quantity', (r) => (r as RepRow).get('qty'), num: true),
        Col.t('Reason', (r) => (r as RepRow).get('reason')),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget purchaseBySupplierReportView() {
  final rows = [
    for (final s in _supplierTotals())
      RepRow({'sup': s.name, 'pos': '${s.pos} POs', 'pqty': _qty(s.qty), 'amt': fmtINR(s.amount), 'grn': _qty(s.received), 'ret': fmtINR(s.returned)}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Purchase by Supplier', sub: 'Procurement expenditure per vendor, total PO count, purchased quantities, GRN received quantities, and returns'),
    ReportTableCard(
      id: 'rep-pbs',
      title: 'Purchase by Supplier',
      exportFilename: 'Purchase_by_Supplier',
      rows: rows,
      filters: [
        Filt('Supplier', _opts(rows, 'sup'), (r) => (r as RepRow).get('sup')),
      ],
      cols: [
        Col('Supplier', (r) => Text((r as RepRow).get('sup'), style: tsB), text: (r) => (r as RepRow).get('sup')),
        Col.t('PO Count', (r) => (r as RepRow).get('pos'), num: true),
        Col.t('Purchase Quantity', (r) => (r as RepRow).get('pqty'), num: true),
        Col('Purchase Amount', (r) => Text((r as RepRow).get('amt'), style: tsB), text: (r) => (r as RepRow).get('amt'), num: true),
        Col.t('GRN Quantity', (r) => (r as RepRow).get('grn'), num: true),
        Col.t('Returns', (r) => (r as RepRow).get('ret'), num: true),
      ],
    ),
  ]);
}

Widget purchaseByItemReportView() {
  final rows = _itemPurchases();
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Purchase by Item', sub: 'Item purchasing volumes, primary vendor sources, total purchase cost, and return deductions'),
    ReportTableCard(
      id: 'rep-pbi',
      title: 'Purchase by Item',
      exportFilename: 'Purchase_by_Item',
      rows: rows,
      filters: [
        Filt('Category', _opts(rows, 'cat'), (r) => (r as RepRow).get('cat')),
        Filt('Supplier', _opts(rows, 'sup'), (r) => (r as RepRow).get('sup')),
      ],
      cols: [
        Col('Item', (r) => Text((r as RepRow).get('item'), style: tsB), text: (r) => (r as RepRow).get('item')),
        Col.t('Category', (r) => (r as RepRow).get('cat')),
        Col.t('Supplier', (r) => (r as RepRow).get('sup')),
        Col.t('Quantity Purchased', (r) => (r as RepRow).get('qty'), num: true),
        Col('Purchase Amount', (r) => Text((r as RepRow).get('amt'), style: tsB), text: (r) => (r as RepRow).get('amt'), num: true),
        Col.t('Returns', (r) => (r as RepRow).get('ret'), num: true),
      ],
    ),
  ]);
}

// ================================================================ 3. INVENTORY REPORTS
Widget stockOverviewReportView() {
  final rows = [
    for (final it in S.items)
      for (final w in S.warehouses)
        RepRow({'code': it.id, 'name': it.name, 'cat': it.cat, 'wh': w.code, 'onhand': '${S.stk(w.id, it.id).onhand} ${it.uom}', 'res': '${S.stk(w.id, it.id).reserved} ${it.uom}',
            'avail': '${S.avail(w.id, it.id)} ${it.uom}', 'reorder': '${it.reorder} ${it.uom}', 'status': S.avail(w.id, it.id) < it.reorder ? 'Low Stock' : 'Sufficient'}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Stock Summary', sub: 'Real-time on-hand inventory levels, allocations, available balances, safety reorder thresholds, and stock status'),
    ReportTableCard(
      id: 'rep-stock-overview',
      summary: (rows) => [('Item lines', '${rows.length}'), ('Items', '${_distinct(rows, 'code')}'), ('Low stock', '${_cnt(rows, 'status', 'Low Stock')}'), ('Stock value', fmtINR([for (final r in rows) _num((r as RepRow).get('onhand')) * S.item(r.get('code')).cost].fold(0.0, (a, b) => a + b)))],
      title: 'Stock Summary',
      exportFilename: 'Stock_Summary',
      rows: rows,
      filters: [
        Filt('Category', _opts(rows, 'cat'), (r) => (r as RepRow).get('cat')),
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Stock Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Item Code', (r) => Text((r as RepRow).get('code'), style: tsB), text: (r) => (r as RepRow).get('code')),
        Col.t('Item Name', (r) => (r as RepRow).get('name')),
        Col.t('Category', (r) => (r as RepRow).get('cat')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('On Hand', (r) => (r as RepRow).get('onhand'), num: true),
        Col.t('Reserved', (r) => (r as RepRow).get('res'), num: true),
        Col('Available', (r) => Text((r as RepRow).get('avail'), style: tsB), text: (r) => (r as RepRow).get('avail'), num: true),
        Col.t('Reorder Level', (r) => (r as RepRow).get('reorder'), num: true),
        Col('Stock Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget stockMovementReportView() {
  final rows = [
    for (final e in S.ledger)
      RepRow({'date': e.date, 'item': S.item(e.item).name, 'wh': S.wh(e.wh).code, 'type': e.type, 'ref': e.ref,
          'in': e.qty > 0 ? '${e.qty}' : '0', 'out': e.qty < 0 ? '${-e.qty}' : '0', 'bal': '${e.bal}', 'user': e.who}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Stock Ledger', sub: 'Audit movement ledger logging quantity ins, quantity outs, transaction types, and running balances'),
    ReportTableCard(
      id: 'rep-stock-movement',
      summary: (rows) => [('Movements', '${rows.length}'), ('Quantity in', fmtNum(_sum(rows, 'in'))), ('Quantity out', fmtNum(_sum(rows, 'out'))), ('Items moved', '${_distinct(rows, 'item')}')],
      title: 'Stock Ledger',
      exportFilename: 'Stock_Ledger',
      rows: rows,
      filters: [
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Transaction Type', _opts(rows, 'type'), (r) => (r as RepRow).get('type')),
      ],
      cols: [
        Col.t('Date', (r) => (r as RepRow).get('date')),
        Col('Item', (r) => Text((r as RepRow).get('item'), style: tsB), text: (r) => (r as RepRow).get('item')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('Transaction Type', (r) => (r as RepRow).get('type')),
        Col.t('Reference Number', (r) => (r as RepRow).get('ref')),
        Col.t('Quantity In', (r) => (r as RepRow).get('in'), num: true),
        Col.t('Quantity Out', (r) => (r as RepRow).get('out'), num: true),
        Col('Balance', (r) => Text((r as RepRow).get('bal'), style: tsB), text: (r) => (r as RepRow).get('bal'), num: true),
        Col.t('User', (r) => (r as RepRow).get('user')),
      ],
    ),
  ]);
}

Widget lowStockReportView() {
  final rows = [
    for (final it in S.items)
      for (final w in S.warehouses)
        if (S.avail(w.id, it.id) < it.reorder)
          RepRow({'item': it.name, 'cat': it.cat, 'wh': w.code, 'avail': '${S.avail(w.id, it.id)} ${it.uom}', 'reorder': '${it.reorder} ${it.uom}',
              'def': '${it.reorder - S.avail(w.id, it.id)} ${it.uom}', 'status': S.avail(w.id, it.id) <= it.reorder ~/ 2 ? 'Critical' : 'Low'}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Reorder Level Report', sub: 'Inventory items below reorder thresholds needing immediate purchase replenishment'),
    ReportTableCard(
      id: 'rep-low-stock',
      summary: (rows) => [('Below reorder', '${rows.length}'), ('Critical', '${_cnt(rows, 'status', 'Critical')}'), ('Low', '${_cnt(rows, 'status', 'Low')}'), ('Warehouses', '${_distinct(rows, 'wh')}')],
      title: 'Reorder Level Report',
      exportFilename: 'Reorder_Level_Report',
      rows: rows,
      filters: [
        Filt('Category', _opts(rows, 'cat'), (r) => (r as RepRow).get('cat')),
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Item', (r) => Text((r as RepRow).get('item'), style: tsB), text: (r) => (r as RepRow).get('item')),
        Col.t('Category', (r) => (r as RepRow).get('cat')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('Available Quantity', (r) => (r as RepRow).get('avail'), num: true),
        Col.t('Reorder Level', (r) => (r as RepRow).get('reorder'), num: true),
        Col('Deficit Quantity', (r) => Text((r as RepRow).get('def'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)), text: (r) => (r as RepRow).get('def'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget stockTransferReportView() {
  final rows = [
    for (final d in S.docsOf('TR'))
      RepRow({'no': d.id, 'date': d.date, 'from': _wc(d.wh), 'to': _wc(d.to ?? ''), 'item': _itemsOf(d), 'qty': _qty(_units(d)), 'status': d.status}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Stock Transfer Report', sub: 'Inter-warehouse stock transfer orders, source/destination locations, and transit status'),
    ReportTableCard(
      id: 'rep-stock-transfer',
      title: 'Stock Transfer Report',
      exportFilename: 'Stock_Transfer_Report',
      rows: rows,
      filters: [
        Filt('From Warehouse', _opts(rows, 'from'), (r) => (r as RepRow).get('from')),
        Filt('To Warehouse', _opts(rows, 'to'), (r) => (r as RepRow).get('to')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Transfer Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('Date', (r) => (r as RepRow).get('date')),
        Col.t('From Warehouse', (r) => (r as RepRow).get('from')),
        Col.t('To Warehouse', (r) => (r as RepRow).get('to')),
        Col.t('Item', (r) => (r as RepRow).get('item')),
        Col.t('Quantity', (r) => (r as RepRow).get('qty'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget stockAdjustmentReportView() {
  final rows = [
    for (final d in S.docsOf('ADJ'))
      RepRow({
        'no': d.id,
        'date': d.date,
        'wh': _wc(d.wh),
        'item': d.lines.isEmpty ? '—' : d.lines.map((l) => S.item(l.item).name).join(', '),
        'type': d.ref != null ? 'Count difference' : 'Manual adjustment',
        'qty': '${_units(d) >= 0 ? '+' : ''}${_units(d)} Qty',
        'reason': d.reason ?? '—',
        'user': d.approvedBy ?? d.by ?? '—',
      }),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Stock Adjustment Report', sub: 'Stock count differences, scrap adjustments, write-offs and approvers'),
    ReportTableCard(
      id: 'rep-stock-adj',
      title: 'Stock Adjustment Report',
      exportFilename: 'Stock_Adjustment_Report',
      rows: rows,
      filters: [
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Adjustment Type', _opts(rows, 'type'), (r) => (r as RepRow).get('type')),
      ],
      cols: [
        Col('Adjustment Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('Date', (r) => (r as RepRow).get('date')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('Item', (r) => (r as RepRow).get('item')),
        Col.t('Adjustment Type', (r) => (r as RepRow).get('type')),
        Col.t('Quantity', (r) => (r as RepRow).get('qty'), num: true),
        Col.t('Reason', (r) => (r as RepRow).get('reason')),
        Col.t('User', (r) => (r as RepRow).get('user')),
      ],
    ),
  ]);
}

Widget batchReportView() {
  final rows = [
    for (final b in [...S.batches]..sort((a, b) => a.exp.compareTo(b.exp)))
      RepRow({'batch': b.id, 'item': S.item(b.item).name, 'wh': S.wh(b.wh).code, 'qty': '${b.qty} ${S.item(b.item).uom}', 'mfg': b.mfg, 'exp': b.exp,
          'status': b.exp.compareTo(todayStr()) <= 0 ? 'Expired' : b.exp.compareTo(addDays(todayStr(), 60)) <= 0 ? 'Expiring Soon' : 'Active'}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Batch Expiry Report', sub: 'Lot and batch inventory numbers, manufacturing dates, expiration schedule, and shelf life alerts'),
    ReportTableCard(
      id: 'rep-batch',
      summary: (rows) => [('Batches', '${rows.length}'), ('Expired', '${_cnt(rows, 'status', 'Expired')}'), ('Expiring in 60 days', '${_cnt(rows, 'status', 'Expiring Soon')}'), ('Active', '${_cnt(rows, 'status', 'Active')}')],
      title: 'Batch Expiry Report',
      exportFilename: 'Batch_Expiry_Report',
      rows: rows,
      filters: [
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Batch Number', (r) => Text((r as RepRow).get('batch'), style: tsB), text: (r) => (r as RepRow).get('batch')),
        Col.t('Item', (r) => (r as RepRow).get('item')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('Quantity', (r) => (r as RepRow).get('qty'), num: true),
        Col.t('Manufacturing Date', (r) => (r as RepRow).get('mfg')),
        Col.t('Expiry Date', (r) => (r as RepRow).get('exp')),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget serialNumberReportView() {
  final rows = [
    for (final s in S.serials) RepRow({'sn': s.id, 'item': S.item(s.item).name, 'wh': _wc(s.wh), 'status': s.status, 'ref': s.ref.isEmpty ? '—' : s.ref}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Serial Number Report', sub: 'Serialized unit tracking, warehouse location, status, and linked reference transactions'),
    ReportTableCard(
      id: 'rep-serial',
      title: 'Serial Number Report',
      exportFilename: 'Serial_Number_Report',
      rows: rows,
      filters: [
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Serial Number', (r) => Text((r as RepRow).get('sn'), style: tsB), text: (r) => (r as RepRow).get('sn')),
        Col.t('Item', (r) => (r as RepRow).get('item')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('Reference Transaction', (r) => (r as RepRow).get('ref')),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

// ================================================================ 4. SUPPLIER REPORTS
Widget supplierPurchaseReportView() {
  final rows = [
    for (final s in _supplierTotals())
      RepRow({'sup': s.name, 'pos': '${s.pos} POs', 'amt': fmtINR(s.amount), 'grn': _qty(s.received), 'ret': fmtINR(s.returned), 'status': s.status}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Supplier Purchase Report', sub: 'Supplier purchase orders summary, procurement values, received GRN volume, returns, and account status'),
    ReportTableCard(
      id: 'rep-sup-pur',
      title: 'Supplier Purchase Report',
      exportFilename: 'Supplier_Purchase_Report',
      rows: rows,
      filters: [
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Supplier', (r) => Text((r as RepRow).get('sup'), style: tsB), text: (r) => (r as RepRow).get('sup')),
        Col.t('Purchase Orders', (r) => (r as RepRow).get('pos'), num: true),
        Col('Purchase Amount', (r) => Text((r as RepRow).get('amt'), style: tsB), text: (r) => (r as RepRow).get('amt'), num: true),
        Col.t('GRN Quantity', (r) => (r as RepRow).get('grn'), num: true),
        Col.t('Returns', (r) => (r as RepRow).get('ret'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget supplierPerformanceReportView() {
  final rows = <RepRow>[];
  for (final sp in S.suppliers) {
    final pos = S.docsOf('PO').where((d) => d.party == sp.id).toList();
    final late = pos.where((d) => ['Sent to Supplier', 'Partially Received'].contains(d.status) && (d.delivery ?? d.need ?? todayStr()).compareTo(todayStr()) < 0).length;
    var rej = 0;
    for (final g in S.docsOf('GRN').where((d) => d.party == sp.id && qcDone(d))) {
      for (final l in g.lines) {
        if (l.acc > 0) rej += l.qty - l.acc;
      }
    }
    rows.add(RepRow({'sup': sp.name, 'orders': '${pos.length} order(s)', 'otd': '${sp.otd}%', 'delay': '$late order(s)', 'rej': '$rej',
        'status': sp.otd >= 95 ? 'Excellent' : sp.otd >= 85 ? 'Good' : 'Under Watch'}));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Supplier Performance', sub: 'Vendor performance scorecard measuring on-time deliveries, shipment delays and quality rejections'),
    ReportTableCard(
      id: 'rep-sup-perf',
      summary: (rows) => [('Suppliers', '${rows.length}'), ('Avg. on-time', '${rows.isEmpty ? 0 : (_sum(rows, 'otd') / rows.length).round()}%'), ('Late open POs', fmtNum(_sum(rows, 'delay'))), ('Rejected qty', fmtNum(_sum(rows, 'rej')))],
      title: 'Supplier Performance',
      exportFilename: 'Supplier_Performance_Report',
      rows: rows,
      filters: [
        Filt('Performance Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Supplier', (r) => Text((r as RepRow).get('sup'), style: tsB), text: (r) => (r as RepRow).get('sup')),
        Col.t('Orders', (r) => (r as RepRow).get('orders'), num: true),
        Col.t('On-Time Deliveries', (r) => (r as RepRow).get('otd'), num: true),
        Col.t('Delayed Deliveries', (r) => (r as RepRow).get('delay'), num: true),
        Col('Rejected Quantity', (r) => Text((r as RepRow).get('rej'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)), text: (r) => (r as RepRow).get('rej'), num: true),
        Col('Performance Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

// ================================================================ 5. CUSTOMER REPORTS
Widget customerSalesReportView() {
  final rows = _customerSales();
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Customer Sales Report', sub: 'Comprehensive customer order counts, sales revenue, fulfillment values, returns, and outstanding receivables'),
    ReportTableCard(
      id: 'rep-cust-sales',
      title: 'Customer Sales Report',
      exportFilename: 'Customer_Sales_Report',
      rows: rows,
      filters: [
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Customer', (r) => Text((r as RepRow).get('cust'), style: tsB), text: (r) => (r as RepRow).get('cust')),
        Col.t('Sales Orders', (r) => (r as RepRow).get('orders'), num: true),
        Col('Sales Amount', (r) => Text((r as RepRow).get('amt'), style: tsB), text: (r) => (r as RepRow).get('amt'), num: true),
        Col.t('Delivered Amount', (r) => (r as RepRow).get('del'), num: true),
        Col.t('Returns', (r) => (r as RepRow).get('ret'), num: true),
        Col('Outstanding Balance', (r) => Text((r as RepRow).get('bal'), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red)), text: (r) => (r as RepRow).get('bal'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget customerTransactionReportView() {
  final rows = _customerTransactions();
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Customer Account Statement', sub: 'Customer financial transaction history statement, invoice postings, payment receipts, and settlement status'),
    ReportTableCard(
      id: 'rep-cust-trans',
      title: 'Customer Account Statement',
      exportFilename: 'Customer_Account_Statement',
      rows: rows,
      filters: [
        Filt('Customer', _opts(rows, 'cust'), (r) => (r as RepRow).get('cust')),
        Filt('Transaction Type', _opts(rows, 'type'), (r) => (r as RepRow).get('type')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col.t('Date', (r) => (r as RepRow).get('date')),
        Col('Customer', (r) => Text((r as RepRow).get('cust'), style: tsB), text: (r) => (r as RepRow).get('cust')),
        Col.t('Transaction Type', (r) => (r as RepRow).get('type')),
        Col.t('Reference Number', (r) => (r as RepRow).get('ref')),
        Col('Amount', (r) => Text((r as RepRow).get('amt'), style: tsB), text: (r) => (r as RepRow).get('amt'), num: true),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

// ================================================================ 6. LOGISTICS REPORTS
Widget shipmentReportView() {
  final rows = [
    for (final d in S.docsOf('SHP'))
      RepRow({
        'no': d.id,
        'dn': d.ref ?? '—',
        'cust': _cname(d.party),
        'date': d.date,
        'dest': d.party == null ? '—' : S.cust(d.party!).city,
        'veh': _vehicleOf(d.ref),
        'driver': _driverOf(d.ref),
        'track': d.awb ?? '—',
        'status': d.status,
      }),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Shipment Report', sub: 'Freight shipment logistics dispatch tracking, destination addresses, assigned vehicle/driver, and tracking numbers'),
    ReportTableCard(
      id: 'rep-shipment',
      title: 'Shipment Report',
      exportFilename: 'Shipment_Report',
      rows: rows,
      filters: [
        Filt('Customer', _opts(rows, 'cust'), (r) => (r as RepRow).get('cust')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Shipment Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('Delivery Number', (r) => (r as RepRow).get('dn')),
        Col.t('Customer', (r) => (r as RepRow).get('cust')),
        Col.t('Dispatch Date', (r) => (r as RepRow).get('date')),
        Col.t('Destination', (r) => (r as RepRow).get('dest')),
        Col.t('Vehicle', (r) => (r as RepRow).get('veh')),
        Col.t('Driver', (r) => (r as RepRow).get('driver')),
        Col.t('Tracking Number', (r) => (r as RepRow).get('track')),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget dispatchReportView() {
  final rows = [
    for (final d in S.docsOf('DN').where((d) => d.status == 'Dispatched' || d.status == 'Delivered'))
      RepRow({'no': d.id, 'cust': _cname(d.party), 'so': d.ref ?? '—', 'ddate': d.date, 'veh': d.vehicle ?? '—', 'driver': _driverOf(d.id), 'deldate': _deliveredOn(d), 'status': d.status}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Dispatch Register', sub: 'Warehouse dock dispatches, sales order link, vehicle/driver details, and delivery completion log'),
    ReportTableCard(
      id: 'rep-dispatch',
      title: 'Dispatch Register',
      exportFilename: 'Dispatch_Register',
      rows: rows,
      filters: [
        Filt('Customer', _opts(rows, 'cust'), (r) => (r as RepRow).get('cust')),
        Filt('Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Delivery Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('Customer', (r) => (r as RepRow).get('cust')),
        Col.t('Sales Order', (r) => (r as RepRow).get('so')),
        Col.t('Dispatch Date', (r) => (r as RepRow).get('ddate')),
        Col.t('Vehicle', (r) => (r as RepRow).get('veh')),
        Col.t('Driver', (r) => (r as RepRow).get('driver')),
        Col.t('Delivered Date', (r) => (r as RepRow).get('deldate')),
        Col('Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

Widget pendingDeliveryReportView() {
  final rows = [
    for (final d in S.docsOf('DN').where((d) => ['Ready to Dispatch', 'Dispatched'].contains(d.status)))
      RepRow({'no': d.id, 'cust': S.partyName(d), 'items': _itemsOf(d), 'so': d.ref ?? '—', 'date': d.date, 'exp': d.delivery ?? d.date, 'wh': S.wh(d.wh).code,
          'vd': d.vehicle ?? 'Unassigned', 'status': d.status == 'Ready to Dispatch' ? 'Pending Dispatch' : 'In Transit'}),
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Pending Deliveries', sub: 'Orders awaiting carrier pickup, dock packaging, or transport vehicle allocation'),
    ReportTableCard(
      id: 'rep-pending-delivery',
      summary: (rows) => [('Pending deliveries', '${rows.length}'), ('Ready to dispatch', '${_cnt(rows, 'status', 'Pending Dispatch')}'), ('In transit', '${_cnt(rows, 'status', 'In Transit')}'), ('Customers', '${_distinct(rows, 'cust')}')],
      title: 'Pending Deliveries',
      exportFilename: 'Pending_Deliveries',
      rows: rows,
      filters: [
        Filt('Warehouse', _opts(rows, 'wh'), (r) => (r as RepRow).get('wh')),
        Filt('Pending Status', _opts(rows, 'status'), (r) => (r as RepRow).get('status')),
      ],
      cols: [
        Col('Delivery Number', (r) => Text((r as RepRow).get('no'), style: tsB), text: (r) => (r as RepRow).get('no')),
        Col.t('Customer', (r) => (r as RepRow).get('cust')),
        Col('Items', (r) => SizedBox(width: 250, child: Text((r as RepRow).get('items'), style: const TextStyle(fontSize: 12.5))), text: (r) => (r as RepRow).get('items')),
        Col.t('Sales Order', (r) => (r as RepRow).get('so')),
        Col.t('Delivery Date', (r) => (r as RepRow).get('date')),
        Col.t('Expected Delivery', (r) => (r as RepRow).get('exp')),
        Col.t('Warehouse', (r) => (r as RepRow).get('wh')),
        Col.t('Vehicle / Driver', (r) => (r as RepRow).get('vd')),
        Col('Pending Status', (r) => StatusBadge((r as RepRow).get('status')), text: (r) => (r as RepRow).get('status'), status: true),
      ],
    ),
  ]);
}

// ================================================================ AGEING (money still to receive / to pay)
/// One line per party: what is still unpaid, split by how many days past the due date it is.
List<RepRow> _ageingRows(List<Doc> docs, String Function(Doc) name) {
  final byParty = <String, List<Doc>>{};
  for (final d in docs) {
    if (d.amount - d.paid > 0.5) (byParty[name(d)] ??= []).add(d);
  }
  final out = <RepRow>[];
  for (final e in byParty.entries) {
    final b = <double>[0, 0, 0, 0, 0]; // not due, 1-30, 31-60, 61-90, over 90
    for (final d in e.value) {
      final late = d.due == null ? 0 : daysBetween(d.due!, todayStr());
      final i = late <= 0 ? 0 : late <= 30 ? 1 : late <= 60 ? 2 : late <= 90 ? 3 : 4;
      b[i] += d.amount - d.paid;
    }
    final total = b.fold(0.0, (a, x) => a + x);
    out.add(RepRow({
      'party': e.key,
      'docs': '${e.value.length}',
      'total': fmtINR(total),
      'b0': fmtINR(b[0]),
      'b1': fmtINR(b[1]),
      'b2': fmtINR(b[2]),
      'b3': fmtINR(b[3]),
      'b4': fmtINR(b[4]),
      'risk': b[3] + b[4] > 0 ? 'Over 60 days' : b[1] + b[2] > 0 ? 'Overdue' : 'Not due',
    }));
  }
  out.sort((a, b) => _num(b.get('total')).compareTo(_num(a.get('total'))));
  return out;
}

Widget _ageingReport(String title, String sub, String partyLabel, String docLabel, String id, List<RepRow> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title, sub: sub),
      ReportTableCard(
        id: id,
        summary: (rows) => [(partyLabel == 'Customer' ? 'Customers owing' : 'Suppliers to pay', '${rows.length}'), ('Total unpaid', fmtINR(_sum(rows, 'total'))), ('Overdue 1–60 days', fmtINR(_sum(rows, 'b1') + _sum(rows, 'b2'))), ('Over 60 days', fmtINR(_sum(rows, 'b3') + _sum(rows, 'b4')))],
        title: title,
        exportFilename: title.replaceAll(' ', '_'),
        rows: rows,
        filters: [Filt('Age', _opts(rows, 'risk'), (r) => (r as RepRow).get('risk'))],
        cols: [
          Col(partyLabel, (r) => Text((r as RepRow).get('party'), style: tsB), text: (r) => (r as RepRow).get('party')),
          Col.t(docLabel, (r) => (r as RepRow).get('docs'), num: true),
          Col('Total Unpaid', (r) => Text((r as RepRow).get('total'), style: tsB), text: (r) => (r as RepRow).get('total'), num: true),
          Col.t('Not Due', (r) => (r as RepRow).get('b0'), num: true),
          Col.t('1–30 Days', (r) => (r as RepRow).get('b1'), num: true),
          Col.t('31–60 Days', (r) => (r as RepRow).get('b2'), num: true),
          Col.t('61–90 Days', (r) => (r as RepRow).get('b3'), num: true),
          Col('Over 90 Days', (r) => Text((r as RepRow).get('b4'), style: TextStyle(fontWeight: FontWeight.w700, color: _num(r.get('b4')) > 0 ? Colors.red : null)), text: (r) => (r as RepRow).get('b4'), num: true),
        ],
      ),
    ]);

/// Receivables ageing: unpaid sales invoices by customer, by days past the due date.
Widget receivablesAgeingReportView() => _ageingReport('Receivables Ageing', 'What customers still owe on sales invoices, split by how many days past the due date', 'Customer', 'Invoices', 'rep-ar-ageing',
    _ageingRows(S.docsOf('INV').where((d) => d.status != 'Cancelled').toList(), (d) => _cname(d.party)));

/// Payables ageing: approved, unpaid purchase invoices by supplier, by days past the due date.
Widget payablesAgeingReportView() => _ageingReport('Payables Ageing', 'What is still to be paid on approved purchase invoices, split by how many days past the due date', 'Supplier', 'Invoices', 'rep-ap-ageing',
    _ageingRows(S.docsOf('PI').where((d) => d.status == 'Approved').toList(), (d) => _sname(d.party)));
