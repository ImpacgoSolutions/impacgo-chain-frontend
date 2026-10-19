import 'package:flutter/material.dart';
import 'select.dart';
import 'tokens.dart';
import 'widgets.dart';
import '../core/export_helper.dart';

/// Text of a cell for export: the column's own text, or what its widget shows.
String colText(Col c, dynamic r) => c.text != null ? c.text!(r) : widgetText(c.cell(r));

String widgetText(Widget w) {
  String join(List<Widget> ws, String sep) => ws.map(widgetText).where((s) => s.trim().isNotEmpty).join(sep);
  if (w is Text) return w.data ?? w.textSpan?.toPlainText() ?? '';
  if (w is RichText) return w.text.toPlainText();
  if (w is StatusBadge) return w.text;
  if (w is Tag) return w.text;
  if (w is CellTwo) return w.sub.trim().isEmpty ? w.title : '${w.title} (${w.sub})';
  if (w is CellAv) return w.sub.trim().isEmpty ? w.name : '${w.name} (${w.sub})';
  if (w is BarPct) return '${w.pct.round()}%';
  if (w is Flex) return join(w.children, w.direction == Axis.horizontal ? ' ' : ' / ');
  if (w is MultiChildRenderObjectWidget) return join(w.children, ' ');
  if (w is SingleChildRenderObjectWidget) return w.child == null ? '' : widgetText(w.child!);
  if (w is ProxyWidget) return widgetText(w.child);
  if (w is Container) return w.child == null ? '' : widgetText(w.child!);
  if (w is Tooltip) return w.child == null ? '' : widgetText(w.child!);
  return '';
}

/// Column definition for [DataTableCard].
class Col {
  final String label;
  final bool num;
  final Widget Function(dynamic r) cell;
  final Comparable Function(dynamic r)? sort;
  final String Function(dynamic r)? text; // used for CSV export
  final bool status; // shown top-right on mobile cards
  Col(this.label, this.cell, {this.num = false, this.sort, this.text, this.status = false});

  /// Plain text column.
  factory Col.t(String label, String Function(dynamic r) f, {bool num = false, bool bold = false}) =>
      Col(label, (r) => Text(f(r), style: bold ? tsB : tsBody), num: num, sort: (r) => f(r), text: f);
}

class Filt {
  final String label;
  final List<String> options;
  final String Function(dynamic r) value;
  Filt(this.label, this.options, this.value);
}

class _Mem {
  int page = 1;
  int? sortCol;
  bool asc = true;
  String q = '';
  final Map<int, String> f = {};
  final Set<Object> sel = Set.identity();
}

/// Hooks the app wires up once (import wizard, bulk approve / delete, toast).
class TableHooks {
  static void Function(BuildContext ctx, String id, List<Col> cols, List rows)? import;
  /// Import is shown only on tables where it creates real records.
  static bool Function(String id)? canImport;
  static void Function(BuildContext ctx, List rows)? approve;
  static void Function(BuildContext ctx, List rows)? delete;
  static void Function(String msg)? toast;
}

/// A toolbar button that works on the ticked rows (e.g. "Raise QC" on goods receipts).
class TableAction {
  final String label, icon;
  final void Function(List rows) onTap;
  /// Shown as a blue (main) button.
  final bool primary;
  const TableAction(this.label, this.icon, this.onTap, {this.primary = false});
}

class DataTableCard extends StatefulWidget {
  final String id;
  final List rows;
  final List<Col> cols;
  final List<Filt> filters;
  final String Function(dynamic r)? search;
  final void Function(dynamic r)? onRow;
  final String? createLabel;
  final VoidCallback? onCreate;
  final bool bulk;
  final Widget Function(dynamic r)? rowActions;
  final int pageSize;
  final Map<int, String>? initialFilters;
  final String? exportName;
  final List<TableAction> actions;
  /// Ticked rows can be deleted (off for screens like Quality Check where rows are other documents).
  final bool allowDelete;
  const DataTableCard({
    super.key,
    required this.id,
    required this.rows,
    required this.cols,
    this.filters = const [],
    this.search,
    this.onRow,
    this.createLabel,
    this.onCreate,
    this.bulk = false,
    this.rowActions,
    this.pageSize = 8,
    this.initialFilters,
    this.exportName,
    this.actions = const [],
    this.allowDelete = true,
  });
  static final Map<String, _Mem> _mem = {};
  static void clearSelection(String id) => _mem[id]?.sel.clear();
  static void clearAll() {
    for (final m in _mem.values) {
      m.sel.clear();
    }
  }
  @override
  State<DataTableCard> createState() => _DataTableCardState();
}

class _DataTableCardState extends State<DataTableCard> {
  late _Mem m;
  final _search = TextEditingController();
  final _hScroll = ScrollController();
  int? _hover;

  @override
  void initState() {
    super.initState();
    final fresh = !DataTableCard._mem.containsKey(widget.id);
    m = DataTableCard._mem.putIfAbsent(widget.id, () => _Mem());
    if (fresh && widget.initialFilters != null) m.f.addAll(widget.initialFilters!);
    _search.text = m.q;
  }

  @override
  void didUpdateWidget(covariant DataTableCard old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      // Same tree position, different table (e.g. switching tabs): load that table's own state.
      final fresh = !DataTableCard._mem.containsKey(widget.id);
      m = DataTableCard._mem.putIfAbsent(widget.id, () => _Mem());
      if (fresh && widget.initialFilters != null) m.f.addAll(widget.initialFilters!);
      _search.text = m.q;
    }
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
        final hay = (widget.search != null ? widget.search!(r) : widget.cols.map((c) => c.text?.call(r) ?? '').join(' ')).toLowerCase();
        if (!hay.contains(m.q.toLowerCase())) return false;
      }
      for (final e in m.f.entries) {
        if (e.key >= widget.filters.length) continue;
        if (e.value.isNotEmpty && widget.filters[e.key].value(r) != e.value) return false;
      }
      return true;
    }).toList();
    if (m.sortCol != null && widget.cols[m.sortCol!].sort != null) {
      final s = widget.cols[m.sortCol!].sort!;
      rows.sort((a, b) {
        final c = s(a).compareTo(s(b));
        return m.asc ? c : -c;
      });
    }
    return rows;
  }

  void _export(List rows) {
    final cols = widget.cols.where((c) => c.label.trim().isNotEmpty).toList();
    exportCsv(widget.exportName ?? widget.id, cols.map((c) => c.label).toList(), rows.map((r) => cols.map((c) => colText(c, r)).toList()).toList()).then(
      (f) => TableHooks.toast?.call('Downloaded $f · ${rows.length} rows'),
      onError: (Object e) => TableHooks.toast?.call('Export failed: $e'),
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
    final selRows = widget.rows.where((r) => m.sel.contains(r)).toList();

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
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: const Icon(Icons.search, size: 16, color: C.faint),
                prefixIconConstraints: const BoxConstraints(minWidth: 34),
                fillColor: C.bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              onChanged: (v) => setState(() {
                m.q = v;
                m.page = 1;
              }),
            ),
          ),
          for (var i = 0; i < widget.filters.length; i++) _filterBox(i),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          // ticked rows: only Delete is offered, in the toolbar (no separate selection bar)
          if (widget.bulk && widget.allowDelete && selRows.isNotEmpty)
            Btn.danger('Delete (${selRows.length})', icon: 'trash', small: true, onTap: () => TableHooks.delete?.call(context, selRows)),
          if (TableHooks.canImport?.call(widget.id) ?? false)
            Btn.ghost('Import', icon: 'upload', small: true, onTap: () => TableHooks.import?.call(context, widget.id, widget.cols, widget.rows)),
          Btn.secondary('Export CSV', icon: 'download', small: true, onTap: () => _export(rows)),
          for (final a in widget.actions)
            (a.primary ? Btn.new : Btn.secondary)(selRows.isEmpty ? a.label : '${a.label} (${selRows.length})', icon: a.icon, small: true, onTap: () {
              a.onTap(selRows);
              setState(() => m.sel.clear());
            }),
          if (widget.createLabel != null) Btn(widget.createLabel!, icon: 'plus', small: true, onTap: widget.onCreate),
        ]),
      ]),
    );


    final pager = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
        Text('Showing ${total == 0 ? 0 : (m.page - 1) * ps + 1}–${(m.page * ps).clamp(0, total)} of $total records', style: const TextStyle(fontSize: 12, color: C.faint)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _pg('‹ Prev', false, () => setState(() => m.page = m.page > 1 ? m.page - 1 : 1)),
          for (var p = 1; p <= (pages < 5 ? pages : 5); p++) _pg('$p', p == m.page, () => setState(() => m.page = p)),
          _pg('Next ›', false, () => setState(() => m.page = m.page < pages ? m.page + 1 : pages)),
        ]),
      ]),
    );

    return CardBox(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        toolbar,
        if (slice.isEmpty) const Empty('Nothing matches these filters. Clear the search or add a new record.') else mobile ? _cards(slice) : _table(slice),
        pager,
      ]),
    );
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
      options: [SelOpt('', '${f.label}: All'), ...f.options.map((o) => SelOpt(o, o))],
      onChanged: (x) => setState(() {
        m.f[i] = x;
        m.page = 1;
      }),
    );
  }

  Widget _check(dynamic r) => ProtoCheck(
        value: m.sel.contains(r),
        onChanged: (on) => setState(() => on ? m.sel.add(r as Object) : m.sel.remove(r)),
      );

  /// HTML-table layout: `th` 10×15 padding, `td` 11×15 padding, rows sized by content,
  /// 1px row borders, extra width shared in proportion to each column's content width
  /// (the browser's auto table layout). Scrolls sideways when the content is wider.
  Widget _table(List slice) {
    final allOn = slice.isNotEmpty && slice.every((r) => m.sel.contains(r));
    final nCols = widget.cols.length + (widget.bulk ? 1 : 0) + (widget.rowActions != null ? 1 : 0);
    // compact enough that the Status column fits on a laptop screen
    const thPad = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    const tdPad = EdgeInsets.symmetric(horizontal: 12, vertical: 11);
    const thStyle = TextStyle(fontFamily: 'Lato', color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: .46, height: 1.45);

    Widget th(int? colIdx, Widget child, {bool numeric = false}) {
      final sortable = colIdx != null && widget.cols[colIdx].sort != null;
      final sorted = colIdx != null && m.sortCol == colIdx;
      final cell = Padding(
        padding: thPad,
        child: Align(
          alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
          child: DefaultTextStyle(style: thStyle, child: sorted ? Row(mainAxisSize: MainAxisSize.min, children: [child, Text(m.asc ? ' \u25B2' : ' \u25BC')]) : child),
        ),
      );
      if (!sortable) return cell;
      return _HoverTap(
        hoverColor: const Color(0xFF22304B),
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

    Widget td(int row, dynamic r, Widget child, {bool numeric = false, bool tappable = true}) {
      final cell = Padding(
        padding: tdPad,
        child: Align(alignment: numeric ? Alignment.centerRight : Alignment.centerLeft, child: DefaultTextStyle.merge(style: tsBody, child: child)),
      );
      return MouseRegion(
        cursor: tappable && widget.onRow != null ? SystemMouseCursors.click : MouseCursor.defer,
        // the row highlight is cosmetic: skipped when the processor draws (each change would redraw the whole screen)
        onEnter: kLightUi ? null : (_) => setState(() => _hover = row),
        onExit: kLightUi ? null : (_) => setState(() => _hover = _hover == row ? null : _hover),
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: tappable && widget.onRow != null ? () => widget.onRow!(r) : null, child: cell),
      );
    }

    final rows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: C.navy900),
        children: [
          if (widget.bulk)
            Padding(
              padding: thPad,
              child: ProtoCheck(
                value: allOn,
                onDark: true,
                onChanged: (on) => setState(() {
                  for (final r in slice) {
                    on ? m.sel.add(r as Object) : m.sel.remove(r);
                  }
                }),
              ),
            ),
          for (var i = 0; i < widget.cols.length; i++) th(i, Text(widget.cols[i].label.toUpperCase(), softWrap: false), numeric: widget.cols[i].num),
          if (widget.rowActions != null) th(null, const Text('ACTIONS', softWrap: false)),
        ],
      ),
      for (var k = 0; k < slice.length; k++)
        TableRow(
          decoration: BoxDecoration(
            color: _hover == k ? C.bg : C.card,
            border: k < slice.length - 1 ? const Border(bottom: BorderSide(color: C.border)) : null,
          ),
          children: [
            if (widget.bulk) td(k, slice[k], _check(slice[k]), tappable: false),
            for (final col in widget.cols) td(k, slice[k], col.cell(slice[k]), numeric: col.num),
            if (widget.rowActions != null) td(k, slice[k], widget.rowActions!(slice[k]), tappable: false),
          ],
        ),
    ];

    final widths = <int, TableColumnWidth>{
      for (var i = 0; i < nCols; i++) i: const ContentProportionalWidth(),
    };
    if (widget.bulk) widths[0] = const IntrinsicColumnWidth();

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
    final statusIdx = widget.cols.indexWhere((c) => c.status || c.label == 'Status' || c.label == 'Stage');
    return Column(children: [
      for (final r in slice)
        InkWell(
          onTap: widget.onRow == null ? null : () => widget.onRow!(r),
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.bulk) ...[_check(r), const SizedBox(width: 10)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: DefaultTextStyle.merge(style: tsB, child: widget.cols.first.cell(r))),
                    if (statusIdx > 0) ...[const SizedBox(width: 8), widget.cols[statusIdx].cell(r)],
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 16, runSpacing: 6, children: [
                    for (var i = 1; i < widget.cols.length; i++)
                      if (i != statusIdx)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(widget.cols[i].label.toUpperCase(), style: const TextStyle(fontSize: 10, color: C.faint, letterSpacing: .3)),
                            DefaultTextStyle.merge(style: tsBody, child: widget.cols[i].cell(r)),
                          ]),
                        ),
                  ]),
                  if (widget.rowActions != null) Padding(padding: const EdgeInsets.only(top: 8), child: widget.rowActions!(r)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}


/// Column width that behaves like a browser's auto table layout: every column gets its
/// max-content width, and any spare width is shared in proportion to those widths.
class ContentProportionalWidth extends TableColumnWidth {
  const ContentProportionalWidth();
  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    var w = 0.0;
    for (final c in cells) {
      final x = c.getMaxIntrinsicWidth(double.infinity);
      if (x > w) w = x;
    }
    return w;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) => minIntrinsicWidth(cells, containerWidth);

  @override
  double? flex(Iterable<RenderBox> cells) {
    final w = minIntrinsicWidth(cells, double.infinity);
    return w <= 0 ? 1 : w;
  }
}

/// Header cell hover (th.sortable:hover) + tap.
class _HoverTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color hoverColor;
  const _HoverTap({required this.child, required this.onTap, required this.hoverColor});
  @override
  State<_HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<_HoverTap> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: kLightUi ? null : (_) => setState(() => _h = true),
        onExit: kLightUi ? null : (_) => setState(() => _h = false),
        child: GestureDetector(onTap: widget.onTap, child: ColoredBox(color: _h ? widget.hoverColor : Colors.transparent, child: widget.child)),
      );
}

/// Compact 13px row checkbox (accent-color blue).
class ProtoCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool onDark;
  const ProtoCheck({super.key, required this.value, required this.onChanged, this.onDark = false});
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: Container(
            // margin grows by 1px each side as the box shrinks, keeping the header at 41px like the HTML
            margin: const EdgeInsets.fromLTRB(5, 4, 4, 4),
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: value ? C.blue600 : Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: value ? C.blue600 : (onDark ? Colors.white : const Color(0xFF767676)), width: 1),
            ),
            child: value ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
          ),
        ),
      );
}
