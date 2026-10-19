import 'package:flutter/material.dart';
import '../core/export_builders.dart' show buildPdf;
import '../core/export_helper.dart' show exportPdf, viewPdf;
import '../core/report_template.dart';
import '../ui/overlays.dart';
import '../ui/select.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// Setup › Company Settings › Report Templates.
/// Changes how report downloads (PDF / Excel), tax invoices and payment receipts look.
/// Nothing changes until Save template is pressed; then the next download uses it.
class ReportTemplatesView extends StatefulWidget {
  const ReportTemplatesView({super.key});
  @override
  State<ReportTemplatesView> createState() => _ReportTemplatesViewState();
}

class _ReportTemplatesViewState extends State<ReportTemplatesView> {
  late ReportTemplate t = reportTemplate.copy();
  String report = templateReports.keys.first;
  final Map<String, TextEditingController> _ctl = {};
  bool dirty = false;

  TextEditingController _c(String key, String value) => _ctl.putIfAbsent(key, () => TextEditingController(text: value));

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(VoidCallback f) => setState(() {
        f();
        dirty = true;
      });

  void _reload() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    _ctl.clear();
  }

  /// Fields that are mandatory and currently empty (shown with a red border and "Required").
  final Set<String> _bad = {};

  /// Checks the mandatory fields; returns true when the template can be saved.
  bool _validate() {
    _bad.clear();
    String? first;
    String? badReport;
    void need(String key, String value, String label) {
      if (value.trim().isEmpty) {
        _bad.add(key);
        first ??= label;
      }
    }

    need('inv_title', t.invoiceTitle, 'Invoice Title');
    need('bank', t.bankDetails, 'Bank Details');
    need('rcpt_title', t.receiptTitle, 'Receipt Title');
    for (final e in t.titles.entries) {
      if (e.value.trim().isEmpty) {
        _bad.add('title_${e.key}');
        if (first == null) {
          first = 'Title on Download (${e.key})';
          badReport = e.key;
        }
      }
    }
    for (final r in templateReports.entries) {
      if ((t.hidden[r.key]?.length ?? 0) >= r.value.length) {
        first ??= 'at least one column on ${r.key}';
        badReport ??= r.key;
      }
    }
    if (first == null) return true;
    setState(() {
      if (badReport != null) report = badReport;
    });
    toast('Please fill in: $first');
    return false;
  }

  bool _save() {
    if (!_validate()) return false;
    // the printed texts are saved without stray spaces
    t
      ..invoiceTitle = t.invoiceTitle.trim()
      ..invoiceCopy = t.invoiceCopy.trim()
      ..bankDetails = t.bankDetails.trim()
      ..invoiceFooter = t.invoiceFooter.trim()
      ..receiptTitle = t.receiptTitle.trim()
      ..receiptFooter = t.receiptFooter.trim()
      ..footerNote = t.footerNote.trim();
    for (final k in t.titles.keys.toList()) {
      t.titles[k] = t.titles[k]!.trim();
    }
    reportTemplate.apply(t);
    // editing one of the company's own templates: keep that saved copy up to date too
    final mine = myTemplates.where((m) => m.name == t.name).firstOrNull;
    if (mine != null) mine.apply(t);
    setState(() => dirty = false);
    toast('Template "${t.name}" saved · the next download uses it');
    return true;
  }

  // ---------------------------------------------------------------- choosing / managing templates
  /// Ready-made look: changes the style and layout; titles, columns, custom fields and texts stay.
  void _usePreset(String style) {
    setState(() {
      t.applyLook(presetTemplate(style));
      t.name = style;
      _reload();
      dirty = true;
    });
    toast('$style template chosen · press Save template to use it');
  }

  /// One of the company's own templates: everything it saved is loaded and can be edited.
  void _useMine(ReportTemplate m) {
    setState(() {
      t = m.copy();
      _reload();
      dirty = true;
    });
    toast('"${m.name}" loaded · change anything, then Save template');
  }

  bool _nameTaken(String n, [ReportTemplate? except]) =>
      templateStyles.keys.any((k) => k.toLowerCase() == n.toLowerCase()) || myTemplates.any((m) => m != except && m.name.toLowerCase() == n.toLowerCase());

  /// Saves the current settings as a new named template the company can pick later.
  void _saveAsNew() {
    if (!_validate()) return;
    mform('Save as new template', [
      const F.header('Template'),
      const F('name', 'Template Name', req: true, hint: 'e.g. Board reports, Warehouse copy'),
    ], (v, _) {
      final n = (v['name'] as String).trim();
      if (_nameTaken(n)) {
        toast('A template called "$n" already exists');
        return false;
      }
      setState(() => t.name = n);
      myTemplates.add(t.copy());
      _save();
      return true;
    }, btn: 'Save template', icon: 'check');
  }

  void _renameMine(ReportTemplate m) {
    mform('Rename template · ${m.name}', [
      const F.header('Template'),
      F('name', 'Template Name', req: true, def: m.name),
    ], (v, _) {
      final n = (v['name'] as String).trim();
      if (_nameTaken(n, m)) {
        toast('A template called "$n" already exists');
        return false;
      }
      final old = m.name;
      setState(() {
        m.name = n;
        if (t.name == old) t.name = n;
        if (reportTemplate.name == old) reportTemplate.name = n;
      });
      toast('Template renamed to "$n"');
      return true;
    }, btn: 'Save changes', icon: 'check');
  }

  void _deleteMine(ReportTemplate m) => confirmDelete('template "${m.name}"', () {
        setState(() {
          myTemplates.remove(m);
          // the deleted template was in use: fall back to the Classic look
          if (t.name == m.name) {
            t.applyLook(presetTemplate('Classic'));
            t.name = 'Classic';
            dirty = true;
          }
        });
        Navigator.of(rootCtx).pop();
        toast('Template "${m.name}" deleted');
      });

  void _reset() {
    setState(() {
      t = ReportTemplate();
      _reload();
      dirty = true;
    });
    toast('Default template restored · press Save template to keep it');
  }

  /// Two sample rows for the chosen report, so a layout can be checked without real data.
  List<List<String>> _sampleRows(List<String> cols, {int n = 2}) {
    // row k: its own number, date and amount; names alternate between two examples
    String sample(String col, int k) {
      final l = col.toLowerCase();
      final a = k.isEven;
      if (l.contains('date') || l == 'expected delivery') return '2026-10-${(k + 6).toString().padLeft(2, '0')}';
      if (l.contains('amount') || l.contains('value')) return '₹${const ['13,275', '40,320', '24,192', '56,640', '9,880', '31,450', '18,600', '20,023'][k % 8]}';
      if (l.contains('qty') || l.contains('quantity') || l.contains('hand') || l.contains('reserved') || l.contains('available') || l.contains('balance') || l.contains('level') || l == 'quantity in' || l == 'quantity out') {
        return '${const [25, 96, 120, 150, 40, 75, 60, 200][k % 8]}';
      }
      if (l.contains('status')) return a ? 'Open' : 'Completed';
      if (l.contains('number') || l.contains('order')) return 'DOC-2026-${(k + 1).toString().padLeft(4, '0')}';
      if (l.contains('customer')) return a ? 'Sri Lakshmi Supermarkets' : 'Metro Mart Stores';
      if (l.contains('supplier')) return a ? 'SafeGuard Industrial Supplies' : 'Andhra Corrugators';
      if (l.contains('item')) return a ? 'Industrial Safety Helmet × 25 Nos' : 'Barcode Label Roll × 200 Roll';
      if (l.contains('warehouse')) return 'VZG-DC';
      return 'Sample';
    }

    return [for (var k = 0; k < n; k++) [for (final c in cols) sample(c, k)]];
  }


  /// Saves, then downloads the chosen report with two sample rows so the layout can be checked.
  void _preview() {
    if (!_save()) return;
    final cols = templateReports[report]!.where((c) => t.shows(report, c)).toList();
    toast('Preparing sample PDF…');
    exportPdf('Template_Preview', t.titleOf(report), cols, _sampleRows(cols), summary: const [('Records', '2'), ('Total value', '₹53,595')])
        .then((f) => toast('Downloaded $f (also opened in a new tab)'), onError: (Object e) => toast('Preview failed: $e'));
  }

  /// Shows how a template looks: a sample of the chosen report in that template, opened to view.
  /// Nothing is saved or changed — the template in use stays as it is.
  Future<void> _view(String label, ReportTemplate look) async {
    final cols = templateReports[report]!.where((c) => look.shows(report, c)).toList();
    final inUse = reportTemplate.copy();
    toast('Opening the $label template…');
    try {
      reportTemplate.apply(look); // the PDF builder reads the template in use
      final bytes = await buildPdf(look.titleOf(report), cols, _sampleRows(cols, n: 8), const {'Status': 'All'}, const [('Records', '8'), ('Total value', '₹2,14,380')]);
      reportTemplate.apply(inUse);
      final where = await viewPdf(bytes);
      toast('$label template opened in $where · sample of $report');
    } catch (e) {
      reportTemplate.apply(inUse);
      toast('Could not open the preview: $e');
    }
  }

  /// A ready-made style shown with your current titles, columns and custom fields.
  ReportTemplate _presetLook(String style) => t.copy()
    ..applyLook(presetTemplate(style))
    ..name = style;

  // ---------------------------------------------------------------- building blocks
  Widget _field(String label, Widget control, double w, {bool req = false}) => SizedBox(
        width: w,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text.rich(
            TextSpan(children: [TextSpan(text: label), if (req) const TextSpan(text: ' *', style: TextStyle(color: C.red))]),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft),
          ),
          const SizedBox(height: 6),
          control,
        ]),
      );

  Widget _select(String value, List<String> options, ValueChanged<String> on) =>
      ProtoSelect(value: value, options: [for (final o in options) SelOpt(o, o)], onChanged: (v) => _set(() => on(v)));

  Widget _text(String key, String value, ValueChanged<String> on, {String? hint}) => TextField(
        controller: _c(key, value),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          errorText: _bad.contains(key) ? 'Required' : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
        ),
        onChanged: (v) => _set(() {
          on(v);
          if (v.trim().isNotEmpty) _bad.remove(key);
        }),
      );

  Widget _toggle(String label, String help, bool value, ValueChanged<bool> on, double w) => SizedBox(
        width: w,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w600)),
                Text(help, style: const TextStyle(fontSize: 11, color: C.faint)),
              ]),
            ),
            Switch(value: value, onChanged: (v) => _set(() => on(v))),
          ]),
        ),
      );

  Widget _card(String title, String hint, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: CardBox(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CardHead(title, hint: hint),
            Padding(padding: const EdgeInsets.all(20), child: child),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cols = templateReports[report]!;
    final hidden = t.hidden.putIfAbsent(report, () => <String>{});
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Report Templates', sub: 'How downloaded reports, tax invoices and payment receipts look · changes apply to the next download', actions: [
        Btn.secondary('Reset to default', icon: 'refresh', onTap: _reset),
        Btn.secondary('Save & preview PDF', icon: 'eye', onTap: _preview),
        Btn(dirty ? 'Save template' : 'Saved', icon: 'check', onTap: dirty ? _save : null),
      ]),
      if (dirty) const Padding(padding: EdgeInsets.only(bottom: 14), child: NoteBox(Tone.amber, 'alert', 'Unsaved changes.', 'Press Save template to use them in downloads.')),
      LayoutBuilder(builder: (ctx, c) {
        final per = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
        final full = c.maxWidth - 44; // card padding and border
        final w = ((full - 14 * (per - 1)) / per).floorToDouble();
        final tileW = c.maxWidth >= 900 ? ((full - 14 * 3) / 4).floorToDouble() : (c.maxWidth >= 560 ? ((full - 14) / 2).floorToDouble() : full);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ---- choose a template
          _card(
            'Choose a Template',
            'In use: ${t.name}',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Press View to see a sample of the chosen report (Report Columns, below) in that template. Use this changes the look; Save template keeps it.',
                    style: TextStyle(fontSize: 12, color: C.faint)),
              ),
              Wrap(spacing: 14, runSpacing: 14, children: [
                for (final e in templateStyles.entries)
                  _tile(e.key, e.value, e.key, tileW, selected: t.name == e.key, onUse: () => _usePreset(e.key), onView: () => _view(e.key, _presetLook(e.key))),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: Text('My templates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                Btn.secondary('Save as new template', icon: 'plus', small: true, onTap: _saveAsNew),
              ]),
              const SizedBox(height: 10),
              if (myTemplates.isEmpty)
                const Text('None yet. Set everything below the way you want, then press Save as new template to keep it under a name.',
                    style: TextStyle(fontSize: 12, color: C.faint))
              else
                Wrap(spacing: 14, runSpacing: 14, children: [
                  for (final m in myTemplates)
                    _tile(m.name, 'Your template · ${m.style} style, ${m.accent.toLowerCase()} colour${m.customFields.isEmpty ? '' : ', ${m.customFields.length} custom field(s)'}',
                        m.style, tileW,
                        accent: m.accent, selected: t.name == m.name, onUse: () => _useMine(m), onView: () => _view(m.name, m), onRename: () => _renameMine(m), onDelete: () => _deleteMine(m)),
                ]),
            ]),
          ),
          // ---- page layout
          _card(
            'Page Layout',
            'All report downloads',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 14, runSpacing: 14, children: [
                _field('Accent Colour', _select(t.accent, accentColors.keys.toList(), (v) => t.accent = v), w),
                _field('Page Orientation', _select(t.orientation, orientations, (v) => t.orientation = v), w),
                _field('Date Format', _select(t.dateFormat, dateFormats, (v) => t.dateFormat = v), w),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 14, runSpacing: 10, children: [
                _toggle('Company logo', 'Logo in the header', t.showLogo, (v) => t.showLogo = v, w),
                _toggle('Company address', 'Address, GSTIN, contact', t.showAddress, (v) => t.showAddress = v, w),
                _toggle('Report details', 'As on, warehouse, filters', t.showInfoBar, (v) => t.showInfoBar = v, w),
                _toggle('Key figures', 'Summary boxes above the table', t.showKeyFigures, (v) => t.showKeyFigures = v, w),
                _toggle('Shaded rows', 'Alternate row shading', t.shadeRows, (v) => t.shadeRows = v, w),
                _toggle('Total row', 'Totals under amount and quantity', t.showTotals, (v) => t.showTotals = v, w),
                _toggle('Prepared by', 'Name of the person who downloaded', t.showPreparedBy, (v) => t.showPreparedBy = v, w),
                _toggle('Page numbers', 'Page X of Y in the footer', t.showPageNumbers, (v) => t.showPageNumbers = v, w),
              ]),
              const SizedBox(height: 16),
              _field('Footer Note', _text('footer', t.footerNote, (v) => t.footerNote = v, hint: 'e.g. Confidential · for internal use only'), full),
            ]),
          ),
          // ---- the company's own lines on every report
          _card(
            'Custom Fields',
            'Your own lines printed under the report details',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (t.customFields.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('Add any line you want on every report, e.g. Department: Stores · Prepared for: Board meeting · CIN: U51909AP2019PTC112233.',
                      style: TextStyle(fontSize: 12, color: C.faint)),
                ),
              for (var i = 0; i < t.customFields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(flex: 2, child: _field('Label', _text('cf_l_$i', t.customFields[i][0], (v) => t.customFields[i][0] = v, hint: 'e.g. Department'), double.infinity)),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: _field('Value', _text('cf_v_$i', t.customFields[i][1], (v) => t.customFields[i][1] = v, hint: 'e.g. Stores'), double.infinity)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: IconBtn('trash', () => _set(() {
                            t.customFields.removeAt(i);
                            _reload();
                          }), tip: 'Remove'),
                    ),
                  ]),
                ),
              Btn.secondary('Add field', icon: 'plus', small: true, onTap: t.customFields.length >= 8 ? null : () => _set(() => t.customFields.add(['', '']))),
            ]),
          ),
          // ---- columns per report
          _card(
            'Report Columns',
            'Choose a report, then the columns it shows',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 14, runSpacing: 14, children: [
                _field('Report', ProtoSelect(value: report, options: [for (final r in templateReports.keys) SelOpt(r, r)], onChanged: (v) => setState(() => report = v)), w),
                _field('Title on Download', _text('title_$report', t.titles[report] ?? report, (v) => t.titles[report] = v), per == 1 ? w : w * 2 + 14, req: true),
              ]),
              const SizedBox(height: 16),
              Text('Columns (${cols.length - hidden.length} of ${cols.length} shown)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 8, children: [
                for (final col in cols)
                  SizedBox(
                    width: per == 1 ? full : ((full - 10 * per) / (per + 1)).floorToDouble(),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _toggleCol(hidden, col, cols.length),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
                        child: Row(children: [
                          Checkbox(value: !hidden.contains(col), onChanged: (_) => _toggleCol(hidden, col, cols.length)),
                          Expanded(child: Text(col, style: const TextStyle(fontSize: 12.8))),
                        ]),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              const Text('Unticked columns are hidden on the report screen and in its PDF and Excel downloads. At least one column stays.', style: TextStyle(fontSize: 11.5, color: C.faint)),
            ]),
          ),
          // ---- invoice and receipt
          _card(
            'Tax Invoice & Payment Receipt',
            'Printed documents',
            Wrap(spacing: 14, runSpacing: 14, children: [
              _field('Invoice Title', _text('inv_title', t.invoiceTitle, (v) => t.invoiceTitle = v), w, req: true),
              _field('Copy Label', _text('inv_copy', t.invoiceCopy, (v) => t.invoiceCopy = v, hint: 'e.g. Original for recipient'), w),
              _field('Bank Details', _text('bank', t.bankDetails, (v) => t.bankDetails = v), full, req: true),
              _field('Invoice Footer', _text('inv_footer', t.invoiceFooter, (v) => t.invoiceFooter = v), full),
              _field('Receipt Title', _text('rcpt_title', t.receiptTitle, (v) => t.receiptTitle = v), w, req: true),
              _field('Receipt Footer', _text('rcpt_footer', t.receiptFooter, (v) => t.receiptFooter = v), per == 1 ? w : full - w - 14),
            ]),
          ),
        ]);
      }),
    ]);
  }

  /// A template card: a small drawing of the look, its name and description, and actions.
  Widget _tile(String name, String desc, String style, double w,
      {String? accent, required bool selected, required VoidCallback onUse, required VoidCallback onView, VoidCallback? onRename, VoidCallback? onDelete}) {
    final look = presetTemplate(style);
    final colours = accentColors[accent ?? look.accent]!;
    final col = Color(colours.$1);
    final head = style == 'Minimal' ? Colors.white : Color(style == 'Modern' ? colours.$1 : colours.$2);
    Widget bar(double wf, {Color c = C.border, double h = 4}) => FractionallySizedBox(
        widthFactor: wf,
        alignment: Alignment.centerLeft,
        child: Container(height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))));
    final rows = style == 'Compact' ? 5 : 3;
    final rowH = style == 'Compact' ? 6.0 : 8.0;
    final preview = Container(
      height: 92,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (style == 'Modern')
          Container(height: 16, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3)))
        else ...[
          Row(children: [
            if (style != 'Minimal') ...[Container(width: 10, height: 10, color: col), const SizedBox(width: 4)],
            Expanded(child: bar(.5, c: C.text)),
          ]),
          Container(height: style == 'Minimal' ? 1 : 2, margin: const EdgeInsets.only(top: 4), color: style == 'Minimal' ? C.text : col),
        ],
        const SizedBox(height: 5),
        Container(height: rowH, decoration: BoxDecoration(color: head, border: style == 'Minimal' ? const Border(bottom: BorderSide(color: C.text)) : null)),
        for (var k = 0; k < rows; k++)
          Container(
            height: rowH,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: style == 'Classic' && k.isOdd ? C.bg : Colors.white,
              border: style == 'Compact'
                  ? Border.all(color: C.border, width: .6)
                  : style == 'Modern'
                      ? null
                      : const Border(bottom: BorderSide(color: C.border)),
            ),
          ),
      ]),
    );
    return SizedBox(
      width: w,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? C.blue50 : C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? C.blue600 : C.border, width: selected ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          preview,
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
            if (selected) const StatusBadge('In use', tone: Tone.blue),
          ]),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 11.5, color: C.soft, height: 1.35)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Btn(selected ? 'Chosen' : 'Use this', icon: 'check', small: true, onTap: selected ? null : onUse),
            Btn.secondary('View', icon: 'eye', small: true, onTap: onView),
            if (onRename != null) Btn.ghost('Rename', icon: 'edit', small: true, onTap: onRename),
            if (onDelete != null) Btn.ghost('Delete', icon: 'trash', small: true, onTap: onDelete),
          ]),
        ]),
      ),
    );
  }

  void _toggleCol(Set<String> hidden, String col, int total) {
    if (!hidden.contains(col) && hidden.length >= total - 1) {
      toast('At least one column must stay on the report');
      return;
    }
    _set(() => hidden.contains(col) ? hidden.remove(col) : hidden.add(col));
  }
}
