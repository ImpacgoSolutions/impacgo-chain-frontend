import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/export_helper.dart' show pdfPreview, viewPdf;
import 'overlays.dart';
import 'tokens.dart';
import 'widgets.dart';

/// One part of a document or report that can be left out of the file.
/// A [locked] part is required by GST (or holds the figures themselves) and always stays.
class ExportChoice {
  final String key, label;
  final String? group;
  final bool locked;
  const ExportChoice(this.key, this.label, {this.group, this.locked = false});
}

/// What was left out last time, per document type or report, so the next download starts the same way.
final Map<String, Set<String>> _remembered = {};

/// The choice is made in a window before the file is saved: tick what goes in, see it, then download.
/// The saved document itself never changes; only the file does.
Future<void> openDocExport({
  required String title,
  required String rememberAs,
  required List<ExportChoice> choices,
  required Future<Uint8List> Function(Set<String> hide) build,
  required Future<void> Function(Uint8List bytes) download,
}) =>
    showDialog<void>(
      context: rootCtx,
      barrierColor: const Color(0x73141B2D),
      builder: (_) => _ExportWindow(
        title: title,
        rememberAs: rememberAs,
        choices: choices,
        pdf: build,
        actions: [('Download PDF', 'download', (hide) async => download(await build(hide)))],
      ),
    );

/// Report and table exports: choose the columns (a quick look at the first rows shows the result), then export.
/// [outputs]: one button per file type, each given the chosen headings and rows.
Future<void> openColumnExport({
  required String title,
  required String rememberAs,
  required List<String> headers,
  required List<List<String>> rows,
  required List<(String, String, Future<void> Function(List<String> headers, List<List<String>> rows))> outputs,
}) {
  final choices = [for (var i = 0; i < headers.length; i++) ExportChoice('$i:${headers[i]}', headers[i])];
  List<int> keep(Set<String> hide) => [for (var i = 0; i < headers.length; i++) if (!hide.contains(choices[i].key)) i];
  return showDialog<void>(
    context: rootCtx,
    barrierColor: const Color(0x73141B2D),
    builder: (_) => _ExportWindow(
      title: title,
      rememberAs: rememberAs,
      choices: choices,
      columns: (hide) {
        final k = keep(hide);
        return ([for (final i in k) headers[i]], [for (final r in rows.take(6)) [for (final i in k) i < r.length ? r[i] : '']]);
      },
      rowCount: rows.length,
      actions: [
        for (final o in outputs)
          (o.$1, o.$2, (Set<String> hide) async {
            final k = keep(hide);
            await o.$3([for (final i in k) headers[i]], [for (final r in rows) [for (final i in k) i < r.length ? r[i] : '']]);
          }),
      ],
    ),
  );
}

class _ExportWindow extends StatefulWidget {
  final String title, rememberAs;
  final List<ExportChoice> choices;
  /// Documents: the PDF for the current choice (shown in the preview).
  final Future<Uint8List> Function(Set<String> hide)? pdf;
  /// Reports and tables: the headings and first rows for the current choice.
  final (List<String>, List<List<String>>) Function(Set<String> hide)? columns;
  final int rowCount;
  final List<(String, String, Future<void> Function(Set<String> hide))> actions;
  const _ExportWindow({required this.title, required this.rememberAs, required this.choices, required this.actions, this.pdf, this.columns, this.rowCount = 0});
  @override
  State<_ExportWindow> createState() => _ExportWindowState();
}

class _ExportWindowState extends State<_ExportWindow> {
  late Set<String> _hide = {...?_remembered[widget.rememberAs]}..removeWhere((k) => widget.choices.any((c) => c.key == k && c.locked));
  bool _remember = true;
  bool _busy = false;
  Uint8List? _bytes;
  Timer? _wait;
  int _made = 0;

  @override
  void initState() {
    super.initState();
    _refresh(now: true);
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  /// The PDF preview is redrawn a moment after the last tick, so ticking several boxes quickly draws it once.
  void _refresh({bool now = false}) {
    if (widget.pdf == null) return;
    _wait?.cancel();
    _wait = Timer(Duration(milliseconds: now ? 0 : 350), () async {
      final n = ++_made;
      final b = await widget.pdf!({..._hide});
      if (mounted && n == _made) setState(() => _bytes = b);
    });
  }

  void _toggle(ExportChoice c, bool on) {
    if (c.locked) return;
    setState(() => on ? _hide.remove(c.key) : _hide.add(c.key));
    _refresh();
  }

  void _all(bool on) {
    setState(() => _hide = on ? {} : {for (final c in widget.choices) if (!c.locked) c.key});
    _refresh();
  }

  Future<void> _run(Future<void> Function(Set<String> hide) f) async {
    final kept = widget.choices.where((c) => !_hide.contains(c.key)).length;
    if (widget.columns != null && kept == 0) {
      toast('Choose at least one column');
      return;
    }
    if (_remember) {
      _remembered[widget.rememberAs] = {..._hide};
    } else {
      _remembered.remove(widget.rememberAs);
    }
    setState(() => _busy = true);
    try {
      await f({..._hide});
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      toast('Download failed: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _choices() {
    final groups = <String?, List<ExportChoice>>{};
    for (final c in widget.choices) {
      groups.putIfAbsent(c.group, () => []).add(c);
    }
    final free = widget.choices.where((c) => !c.locked).toList();
    final allOn = free.every((c) => !_hide.contains(c.key));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Text(widget.columns != null ? 'COLUMNS TO INCLUDE' : 'CHOOSE WHAT TO INCLUDE', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.soft, letterSpacing: .5))),
        if (free.isNotEmpty) Btn.ghost(allOn ? 'Clear all' : 'Select all', small: true, onTap: () => _all(!allOn)),
      ]),
      const SizedBox(height: 4),
      for (final g in groups.entries) ...[
        if (g.key != null) Padding(padding: const EdgeInsets.only(top: 10, bottom: 2), child: Text(g.key!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        for (final c in g.value) _row(c),
      ],
    ]);
  }

  Widget _row(ExportChoice c) {
    final on = c.locked || !_hide.contains(c.key);
    return InkWell(
      onTap: c.locked ? null : () => _toggle(c, !on),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 32, height: 30, child: Checkbox(value: on, onChanged: c.locked ? null : (v) => _toggle(c, v ?? false))),
          const SizedBox(width: 4),
          Expanded(child: Text(c.label, style: TextStyle(fontSize: 13, color: c.locked ? C.soft : C.text))),
          if (c.locked)
            const Tooltip(
              message: 'Required by GST on this document — always included',
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline, size: 13, color: C.faint),
                SizedBox(width: 3),
                Text('Required', style: TextStyle(fontSize: 11, color: C.faint)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _preview(bool phone) {
    if (widget.columns != null) {
      final (heads, rows) = widget.columns!(_hide);
      if (heads.isEmpty) return const Center(child: Text('No columns chosen', style: TextStyle(color: C.faint)));
      Widget cell(String v, {bool head = false}) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Text(v, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: head ? 11 : 12, fontWeight: head ? FontWeight.w700 : FontWeight.w400, color: head ? Colors.white : C.text)),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.rowCount <= rows.length ? 'Preview · all ${widget.rowCount} ${widget.rowCount == 1 ? 'row' : 'rows'}' : 'Preview · first ${rows.length} of ${widget.rowCount} rows', style: const TextStyle(fontSize: 11.5, color: C.faint)),
        const SizedBox(height: 8),
        // every chosen column fits the width (long text wraps), nothing scrolls sideways;
        // each column's share follows its longest text, so names are not broken in the middle of a word
        Table(
          border: const TableBorder(horizontalInside: BorderSide(color: C.border), bottom: BorderSide(color: C.border)),
          columnWidths: {
            for (var i = 0; i < heads.length; i++)
              i: () {
                final texts = [heads[i], for (final r in rows) i < r.length ? r[i] : ''];
                final longest = texts.map((t) => t.length).reduce((a, b) => a > b ? a : b);
                final word = texts.expand((t) => t.split(RegExp(r'\s+'))).map((w) => w.length).reduce((a, b) => a > b ? a : b);
                // at least as wide as the longest single word (up to 110 px), the rest shared by text length
                return MaxColumnWidth(FixedColumnWidth((word * 7.2 + 18).clamp(40, 110).toDouble()), FlexColumnWidth(longest.clamp(4, 26).toDouble()));
              }(),
          },
          children: [
            TableRow(decoration: const BoxDecoration(color: C.navy900), children: [for (final h in heads) cell(h, head: true)]),
            for (final r in rows) TableRow(children: [for (final v in r) cell(v)]),
          ],
        ),
      ]);
    }
    if (phone) {
      // phones cannot show a PDF inside the page: it opens in a new tab
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Btn.secondary('See preview', icon: 'eye', onTap: _bytes == null ? null : () => viewPdf(_bytes!)),
      ]);
    }
    return Container(
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(R.sm), border: Border.all(color: C.border)),
      clipBehavior: Clip.antiAlias,
      child: _bytes == null ? const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))) : pdfPreview(_bytes!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final phone = size.width < 760;
    final doc = widget.pdf != null;
    final head = Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
      child: Row(children: [
        Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        IconBtn('x', () => Navigator.of(context).pop()),
      ]),
    );
    final note = Text(
      doc ? 'Only the downloaded file changes — the saved document stays as it is.' : 'Only the exported file changes — the screen stays as it is.',
      style: const TextStyle(fontSize: 11.5, color: C.faint),
    );
    final remember = InkWell(
      onTap: () => setState(() => _remember = !_remember),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 32, height: 30, child: Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true))),
        const SizedBox(width: 4),
        const Flexible(child: Text('Use these choices next time', style: TextStyle(fontSize: 12.5))),
      ]),
    );
    final buttons = Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
      Btn.secondary('Cancel', onTap: _busy ? null : () => Navigator.of(context).pop()),
      // the last button is the main (blue) one
      for (var i = 0; i < widget.actions.length; i++)
        i == widget.actions.length - 1
            ? Btn(widget.actions[i].$1, icon: widget.actions[i].$2, onTap: _busy ? null : () => _run(widget.actions[i].$3))
            : Btn.secondary(widget.actions[i].$1, icon: widget.actions[i].$2, onTap: _busy ? null : () => _run(widget.actions[i].$3)),
    ]);
    final foot = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.border))),
      child: phone
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [remember, const SizedBox(height: 8), buttons])
          : Row(children: [Expanded(child: remember), buttons]),
    );

    // laptop: choices on the left, preview on the right; phone: choices, then the preview below
    final Widget body = phone
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_choices(), const SizedBox(height: 14), _preview(true), const SizedBox(height: 10), note]),
          )
        : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 290,
              child: Container(
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: C.border))),
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 14, 14, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_choices(), const SizedBox(height: 12), note])),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: doc ? _preview(false) : SingleChildScrollView(child: _preview(false)),
              ),
            ),
          ]);

    return Dialog(
      backgroundColor: C.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: phone ? 10 : 40, vertical: phone ? 16 : 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: doc ? 1060 : 980, maxHeight: size.height * .9),
        child: SizedBox(
          // a document window keeps its height for the preview; a column window fits its content on a phone
          height: phone ? null : (doc ? size.height * .9 : (size.height * .9).clamp(0, 560).toDouble()),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            head,
            if (phone) Flexible(child: body) else Expanded(child: body),
            foot,
          ]),
        ),
      ),
    );
  }
}
