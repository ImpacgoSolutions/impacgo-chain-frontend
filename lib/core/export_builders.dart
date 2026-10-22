import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../app_state.dart';
import 'format.dart';
import 'store.dart';
import 'models.dart';
import 'report_template.dart';

/// Builds the bytes of real .xlsx / .pdf / .csv files (platform independent):
/// report downloads, the GST tax invoice and the payment receipt.

const _companyAddress = 'Plot 12, Industrial Estate, Autonagar, Visakhapatnam, Andhra Pradesh 530012';
const _companyContact = '+91 891 2500100 · info@impacgo.com';
const _user = 'Srinivas Rao';

String _two(int n) => n.toString().padLeft(2, '0');
/// A yyyy-mm-dd date in the report template's date format.
String _dmy(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : fmtTemplateDate(d);
}

String _stamp() {
  final d = DateTime.now();
  return '${fmtTemplateDate(d)} ${_two(d.hour)}:${_two(d.minute)}';
}

/// File name with today's date, e.g. Sales_Order_Register_2026-10-06.pdf
String reportFileName(String base, String ext) {
  final clean = base.replaceAll(RegExp(r'\.(xlsx|xls|pdf|csv)$'), '').replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
  final d = DateTime.now();
  return '${clean}_${d.year}-${_two(d.month)}-${_two(d.day)}.$ext';
}

/// "1,23,456.00" — Indian grouping, always two decimals.
String money(num v) {
  final neg = v < 0;
  final r = (v.abs() * 100).round();
  var whole = (r ~/ 100).toString();
  final frac = _two(r % 100);
  if (whole.length > 3) {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    whole = '${parts.join(',')},$last3';
  }
  return '${neg ? '-' : ''}$whole.$frac';
}

/// Amount in words, Indian system: "Rupees Twenty-Seven Thousand Five Hundred Seventy-Eight Only".
String rupeesInWords(num amount) {
  const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
  String two(int n) => n < 20 ? ones[n] : '${tens[n ~/ 10]}${n % 10 > 0 ? '-${ones[n % 10]}' : ''}';
  String three(int n) => [if (n >= 100) '${ones[n ~/ 100]} Hundred', if (n % 100 > 0) two(n % 100)].join(' ');
  final total = (amount.abs() * 100).round();
  var n = total ~/ 100;
  final paise = total % 100;
  if (n == 0 && paise == 0) return 'Rupees Zero Only';
  final parts = <String>[];
  for (final u in [(10000000, 'Crore'), (100000, 'Lakh'), (1000, 'Thousand')]) {
    if (n >= u.$1) {
      parts.add('${n ~/ u.$1 > 99 ? three(n ~/ u.$1) : two(n ~/ u.$1)} ${u.$2}');
      n %= u.$1;
    }
  }
  if (n > 0) parts.add(three(n));
  return 'Rupees ${parts.join(' ')}${paise > 0 ? ' and ${two(paise)} Paise' : ''} Only';
}

/// A cell such as "₹1,23,456.00" or "-2,500" as a number; null when it is text.
double? _asNumber(String s) {
  final t = s.trim().replaceAll('₹', '').replaceAll(',', '').replaceAll('Rs.', '').trim();
  return RegExp(r'^-?\d+(\.\d+)?$').hasMatch(t) ? double.parse(t) : null;
}

/// Columns that hold money / quantities to add up in the total row.
List<bool> _totalColumns(List<String> headers, List<List<String>> rows) {
  final key = RegExp(r'amount|value|sales|net|returns?\b|total|qty|quantity|deficit|in$|out$', caseSensitive: false);
  return [
    for (var i = 0; i < headers.length; i++)
      rows.isNotEmpty &&
          key.hasMatch(headers[i]) &&
          !RegExp(r'date|no\.?$|number|level|status|%', caseSensitive: false).hasMatch(headers[i]) &&
          rows.every((r) => i >= r.length || r[i].trim().isEmpty || r[i].trim() == '—' || _asNumber(r[i]) != null),
  ];
}

String _filterLine(Map<String, String>? filters) =>
    filters == null || filters.isEmpty ? 'Filters: none' : 'Filters: ${filters.entries.map((e) => '${e.key}: ${e.value}').join(' · ')}';

// ================================================================ Excel report
/// Plain, text-only sheet with clean alignment:
///   report title, then the report details and key figures as label / value pairs,
///   then the table (bold header with a line under it), text left-aligned,
///   numbers right-aligned and stored as real numbers (amounts as 1,23,456.00),
///   dates as dd-mm-yyyy, long text wrapped inside its own column, and a total row.
Uint8List buildXlsx(String title, List<String> headers, List<List<String>> rows, Map<String, String>? filters, [List<(String, String)>? summary]) {
  final book = xl.Excel.createExcel();
  final first = book.getDefaultSheet() ?? 'Sheet1';
  book.rename(first, 'Report');
  final sh = book['Report'];
  final n = headers.length;
  const maxW = 45.0;
  // Indian digit grouping: 1,23,45,678.00
  const amountFmt = xl.CustomNumericNumFormat(formatCode: r'[>=10000000]##\,##\,##\,##0.00;[>=100000]##\,##\,##0.00;##,##0.00');
  const qtyFmt = xl.CustomNumericNumFormat(formatCode: r'[>=10000000]##\,##\,##\,##0;[>=100000]##\,##\,##0;##,##0');

  xl.CellIndex at(int c, int r) => xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r);
  final line = xl.Border(borderStyle: xl.BorderStyle.Thin);
  final left = xl.CellStyle(horizontalAlign: xl.HorizontalAlign.Left, verticalAlign: xl.VerticalAlign.Top);
  final labelStyle = xl.CellStyle(bold: true, horizontalAlign: xl.HorizontalAlign.Left, verticalAlign: xl.VerticalAlign.Top);

  String cellText(String v) {
    final t = v.trim();
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t) ? _dmy(t) : t;
  }

  // which table columns hold numbers, and which of those are money
  final isNum = [for (var i = 0; i < n; i++) rows.isNotEmpty && rows.every((r) => i >= r.length || r[i].trim().isEmpty || r[i].trim() == '—' || _asNumber(r[i]) != null)];
  final isMoney = [for (var i = 0; i < n; i++) isNum[i] && rows.any((r) => i < r.length && r[i].contains('₹'))];

  /// A number with the right format, or plain text.
  void put(int c, int r, String v, {bool bold = false, xl.Border? top, xl.Border? bottom, bool wrap = false}) {
    final nv = _asNumber(v);
    final money = v.contains('₹');
    final style = xl.CellStyle(
      bold: bold,
      horizontalAlign: nv != null ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left,
      verticalAlign: xl.VerticalAlign.Top,
      textWrapping: wrap ? xl.TextWrapping.WrapText : null,
      topBorder: top,
      bottomBorder: bottom,
      numberFormat: nv == null ? xl.NumFormat.standard_0 : (money || v.contains('.') ? amountFmt : qtyFmt),
    );
    final xl.CellValue value = nv == null ? xl.TextCellValue(cellText(v)) : (money || v.contains('.') ? xl.DoubleCellValue(nv) : xl.IntCellValue(nv.round()));
    sh.updateCell(at(c, r), value, cellStyle: style);
  }

  // column widths from the table content
  final widths = List<double>.generate(n, (i) {
    var w = headers[i].length.toDouble();
    for (final r in rows) {
      final t = i < r.length ? cellText(r[i]) : '';
      if (t.length > w) w = t.length.toDouble();
    }
    return (w + 4).clamp(12, maxW).toDouble();
  });

  var r = 0;
  // ---- title
  sh.updateCell(at(0, r), xl.TextCellValue(title), cellStyle: xl.CellStyle(bold: true, fontSize: 14, horizontalAlign: xl.HorizontalAlign.Left));
  sh.setRowHeight(r, 22);
  r++;
  final tp = reportTemplate;
  sh.updateCell(at(0, r), xl.TextCellValue(S.currentCompany), cellStyle: left);
  r++;
  if (tp.showAddress) {
    sh.updateCell(at(0, r), xl.TextCellValue(_companyAddress), cellStyle: left);
    r++;
  }
  r++;

  // ---- report details (label in A, value in B)
  final details = <(String, String)>[
    if (tp.showInfoBar) ...[
      ('As on', _dmy(todayStr())),
      ('Warehouse', '${S.currentWh.code} - ${S.currentWh.city}'),
      ('Filters', filters == null || filters.isEmpty ? 'None (all records)' : filters.entries.map((e) => '${e.key}: ${e.value}').join(', ')),
      ('Records', '${rows.length}'),
    ],
    ('Generated', tp.showPreparedBy ? '${_stamp()} by $_user' : _stamp()),
  ];
  for (final d in details) {
    sh.updateCell(at(0, r), xl.TextCellValue(d.$1), cellStyle: labelStyle);
    // a whole number (Records) is stored as a number so Excel shows no "number stored as text" warning
    final whole = int.tryParse(d.$2);
    sh.updateCell(at(1, r), whole == null ? xl.TextCellValue(d.$2) : xl.IntCellValue(whole), cellStyle: left);
    r++;
  }
  r++;

  // ---- key figures (label in A, value in B, numbers right-aligned)
  if (tp.showKeyFigures && summary != null && summary.isNotEmpty) {
    sh.updateCell(at(0, r), xl.TextCellValue('Summary'), cellStyle: xl.CellStyle(bold: true, fontSize: 12, horizontalAlign: xl.HorizontalAlign.Left));
    r++;
    for (final f in summary) {
      sh.updateCell(at(0, r), xl.TextCellValue(f.$1), cellStyle: labelStyle);
      final fv = _asNumber(f.$2);
      if (fv != null) {
        put(1, r, f.$2.contains('₹') ? '₹${fv.toStringAsFixed(2)}' : f.$2.replaceAll(',', ''));
      } else {
        sh.updateCell(at(1, r), xl.TextCellValue(f.$2), cellStyle: xl.CellStyle(horizontalAlign: xl.HorizontalAlign.Right));
      }
      r++;
    }
    r++;
  }

  // ---- table header: bold, line under it, aligned like its column
  final headerRow = r;
  for (var i = 0; i < n; i++) {
    sh.updateCell(at(i, r), xl.TextCellValue(headers[i]),
        cellStyle: xl.CellStyle(
          bold: true,
          horizontalAlign: isNum[i] ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left,
          verticalAlign: xl.VerticalAlign.Bottom,
          textWrapping: xl.TextWrapping.WrapText,
          topBorder: line,
          bottomBorder: line,
        ));
  }
  sh.setRowHeight(r, 20);
  r++;

  // ---- data rows
  for (final row in rows) {
    var tall = 1;
    for (var i = 0; i < n; i++) {
      final v = i < row.length ? row[i] : '';
      put(i, r, isMoney[i] && _asNumber(v) != null ? '₹${_asNumber(v)!.toStringAsFixed(2)}' : v, wrap: !isNum[i], bold: i == 0);
      final lines = (cellText(v).length / (widths[i] - 2)).ceil();
      if (lines > tall) tall = lines;
    }
    sh.setRowHeight(r, 15.0 * tall + 3);
    r++;
  }

  // ---- total row: label in the first column, SUM under each money / quantity column
  final sum = _totalColumns(headers, rows);
  if (tp.showTotals && rows.isNotEmpty && sum.contains(true)) {
    String colName(int i) => i < 26 ? String.fromCharCode(65 + i) : '${String.fromCharCode(64 + i ~/ 26)}${String.fromCharCode(65 + i % 26)}';
    final firstData = headerRow + 2, lastData = headerRow + 1 + rows.length; // 1-based Excel rows
    for (var i = 0; i < n; i++) {
      final style = xl.CellStyle(
        bold: true,
        horizontalAlign: sum[i] ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left,
        topBorder: line,
        bottomBorder: xl.Border(borderStyle: xl.BorderStyle.Double),
        numberFormat: sum[i] ? (isMoney[i] ? amountFmt : qtyFmt) : xl.NumFormat.standard_0,
      );
      sh.updateCell(
        at(i, r),
        sum[i] ? xl.FormulaCellValue('SUM(${colName(i)}$firstData:${colName(i)}$lastData)') : xl.TextCellValue(i == 0 ? 'Total (${rows.length} records)' : ''),
        cellStyle: style,
      );
    }
  }

  if (tp.footerNote.trim().isNotEmpty) {
    sh.updateCell(at(0, r + 2), xl.TextCellValue(tp.footerNote.trim()), cellStyle: xl.CellStyle(italic: true, horizontalAlign: xl.HorizontalAlign.Left));
  }

  // first two columns also hold the details / summary labels and values
  final labelW = [...details.map((d) => d.$1.length), ...?summary?.map((f) => f.$1.length)].fold<int>(0, (a, b) => a > b ? a : b) + 4.0;
  if (widths.isNotEmpty && widths[0] < labelW) widths[0] = labelW.clamp(12, maxW).toDouble();
  for (var i = 0; i < n; i++) {
    sh.setColumnWidth(i, widths[i]);
  }
  return Uint8List.fromList(book.encode() ?? <int>[]);
}

// ================================================================ PDF building blocks
/// The built-in PDF fonts only cover Latin-1, so map the few symbols the app uses.
/// The app's own font (Lato) for every PDF. The built-in Helvetica has no Unicode
/// support and makes the PDF library print a warning for each document.
pw.ThemeData? _theme;
Future<pw.ThemeData> _pdfTheme() async => _theme ??= pw.ThemeData.withFont(
      base: pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-400.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-700.ttf')),
    );

String _pdfSafe(String s) {
  const m = {'₹': 'Rs.', '—': '-', '–': '-', '→': '->', '…': '...', '≥': '>=', '≤': '<=', '“': '"', '”': '"', '‘': "'", '’': "'", '•': '-', '³': '3', '✓': 'Yes', '✕': 'x', '·': '-'};
  final b = StringBuffer();
  for (final ch in s.runes) {
    final c = String.fromCharCode(ch);
    if (m.containsKey(c)) {
      b.write(m[c]);
    } else if (ch <= 0xFF) {
      b.write(c);
    } else {
      b.write('?');
    }
  }
  return b.toString();
}

const _ink = PdfColor.fromInt(0xFF141B2D);
const _soft = PdfColor.fromInt(0xFF55607A);
const _line = PdfColor.fromInt(0xFFD9DEE8);
const _band = PdfColor.fromInt(0xFFF2F5FB);
PdfColor get _blue => PdfColor.fromInt(accentColors[reportTemplate.accent]?.$1 ?? 0xFF2F5BEA);

pw.Widget _t(String s, {double size = 9, bool bold = false, PdfColor color = _ink, pw.TextAlign? align}) =>
    pw.Text(_pdfSafe(s), textAlign: align, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color));

pw.Widget _label(String s) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2), child: _t(s.toUpperCase(), size: 7, bold: true, color: _soft));

/// Company block (logo, name, address, GSTIN, contact — one per line, evenly spaced)
/// on the left and the document title on the right, vertically centred together.
pw.Widget _brandBlock(String title, List<String> right) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          if (reportTemplate.showLogo) ...[
          pw.Container(
            width: 46,
            height: 46,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(color: _blue, borderRadius: pw.BorderRadius.circular(9)),
            child: _t('IC', size: 16, bold: true, color: PdfColors.white),
          ),
          pw.SizedBox(width: 14),
          ],
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _t(S.currentCompany, size: 13, bold: true),
            if (reportTemplate.showAddress) ...[
            pw.SizedBox(height: 4),
            _t(_companyAddress, size: 8.5, color: _soft),
            pw.SizedBox(height: 2.5),
            _t('GSTIN ${S.companyInfo['gstin']}     PAN ${S.companyInfo['pan']}', size: 8.5, color: _soft),
            pw.SizedBox(height: 2.5),
            _t(_companyContact.replaceAll(' · ', '     '), size: 8.5, color: _soft),
            ],
          ]),
        ]),
        pw.SizedBox(width: 16),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          _t(title, size: 17, bold: true),
          for (final r in right) ...[pw.SizedBox(height: 4), _t(r, size: 8.5, color: _soft)],
        ]),
      ],
    );

/// Brand block followed by a heavy rule (invoice, receipt).
pw.Widget _docHeader(String title, List<String> right) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      margin: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.6))),
      child: _brandBlock(title, right),
    );

pw.Widget _footer(pw.Context ctx, String left) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line, width: .6))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(child: _t([left, if (reportTemplate.footerNote.trim().isNotEmpty) reportTemplate.footerNote.trim()].join('   |   '), size: 7.5, color: _soft)),
        if (reportTemplate.showPageNumbers) _t('Page ${ctx.pageNumber} of ${ctx.pagesCount}', size: 7.5, color: _soft),
      ]),
    );

pw.Widget _box(pw.Widget child, {pw.EdgeInsets padding = const pw.EdgeInsets.all(7)}) =>
    pw.Container(padding: padding, decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: .6)), child: child);

/// Two boxes side by side drawn as one grid: both cells take the height of the taller one,
/// and neighbouring borders are shared instead of doubled. [joinAbove] drops the top border
/// when the grid sits directly under another bordered block.
pw.Widget _pair(pw.Widget left, pw.Widget right, {double? rightWidth, bool joinAbove = false}) {
  const side = pw.BorderSide(color: _line, width: .6);
  return pw.Table(
    border: pw.TableBorder(left: side, right: side, bottom: side, top: joinAbove ? pw.BorderSide.none : side, verticalInside: side),
    columnWidths: {0: const pw.FlexColumnWidth(1), 1: rightWidth == null ? const pw.FlexColumnWidth(1) : pw.FixedColumnWidth(rightWidth)},
    children: [
      pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(7), child: left),
        pw.Padding(padding: const pw.EdgeInsets.all(7), child: right),
      ]),
    ],
  );
}

pw.Widget _kv(List<(String, String)> pairs) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      for (final p in pairs)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 1.5),
          child: pw.Row(children: [pw.SizedBox(width: 78, child: _t(p.$1, size: 8, color: _soft)), pw.Expanded(child: _t(p.$2, size: 8.5, bold: p.$1.contains('No.')))]),
        ),
    ]);

// ================================================================ PDF report
PdfColor get _navy => PdfColor.fromInt(accentColors[reportTemplate.accent]?.$2 ?? 0xFF1F2A44);
const _zebra = PdfColor.fromInt(0xFFF7F9FC);

/// "2026-09-28" -> "28-09-2026"; "₹15,930" -> "Rs. 15,930"; anything else unchanged.
String _pdfCell(String v) {
  final t = v.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) return _dmy(t);
  if (t.contains('₹') && _asNumber(t) != null) return 'Rs. ${money(_asNumber(t)!)}'; // every amount with 2 decimals
  return t.replaceAll('₹', 'Rs. ');
}

Future<Uint8List> buildPdf(String title, List<String> headers, List<List<String>> rows, Map<String, String>? filters, [List<(String, String)>? summary]) async {
  final doc = pw.Document(theme: await _pdfTheme(), title: title, author: S.currentCompany);
  final n = headers.length;
  final tp = reportTemplate;
  final wide = tp.orientation == 'Landscape' || (tp.orientation == 'Automatic' && n > 6);
  final data = [for (final r in rows) [for (var i = 0; i < n; i++) _pdfCell(i < r.length ? r[i] : '')]];
  final sum = _totalColumns(headers, rows);
  final numeric = [for (var i = 0; i < n; i++) rows.isNotEmpty && rows.every((r) => i >= r.length || _asNumber(r[i]) != null || r[i].trim() == '—' || r[i].trim().isEmpty)];
  final totals = <String?>[
    for (var i = 0; i < n; i++)
      sum[i]
          ? () {
              final t = rows.fold<double>(0, (a, r) => a + (_asNumber(r[i]) ?? 0));
              return rows.any((r) => r[i].contains('₹')) ? 'Rs. ${money(t)}' : money(t).replaceAll('.00', '');
            }()
          : null,
  ];
  final totalLabel = 'Total - ${rows.length} records';
  // column widths: longest of header / cell / total, so figures never wrap
  // short columns (dates, numbers, status) take exactly the width they need so they never wrap;
  // long text columns share the rest of the page
  double longest(int i) => [
        ...data.map((r) => r[i].length.toDouble()),
        (totals[i]?.length ?? 0).toDouble(),
        if (i == 0 && totals.any((t) => t != null)) totalLabel.length.toDouble(),
      ].fold<double>(0, (a, b) => a > b ? a : b);
  final widths = <int, pw.TableColumnWidth>{
    for (var i = 0; i < n; i++)
      i: longest(i) <= 18
          ? const pw.IntrinsicColumnWidth()
          : pw.FlexColumnWidth([headers[i].length * 1.15, longest(i)].reduce((a, b) => a > b ? a : b).clamp(8, 40).toDouble()),
  };

  // the chosen template style decides density, header and table lines
  final style = tp.style;
  final compact = style == 'Compact', modern = style == 'Modern', minimal = style == 'Minimal';
  final fs = compact ? 7.4 : 8.2;
  pw.Widget cell(String s, {bool right = false, bool bold = false, PdfColor color = _ink, double? size}) => pw.Padding(
        padding: compact ? const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5) : const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: _t(s, size: size ?? fs, bold: bold, color: color, align: right ? pw.TextAlign.right : pw.TextAlign.left),
      );
  final headBg = minimal ? PdfColors.white : (modern ? _blue : _navy);
  final headFg = minimal ? _ink : PdfColors.white;
  final tableBorder = compact
      ? pw.TableBorder.all(color: _line, width: .4)
      : modern
          ? const pw.TableBorder(bottom: pw.BorderSide(color: _line, width: .5))
          : minimal
              ? const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: .4), bottom: pw.BorderSide(color: _ink, width: .8))
              : const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: .5), bottom: pw.BorderSide(color: _line, width: .5));
  final extra = [for (final f in tp.customFields) if (f[0].trim().isNotEmpty && f[1].trim().isNotEmpty) (f[0].trim(), f[1].trim())];

  pw.Widget infoItem(String l, String v, {int flex = 1}) => pw.Expanded(
        flex: flex,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_label(l), _t(v, size: 8.5, bold: true)]),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: wide ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 24),
    header: (ctx) => modern
        // Modern: a coloured band with the company and the report title in white
        ? pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: pw.BoxDecoration(color: _blue, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _t(S.currentCompany, size: 12.5, bold: true, color: PdfColors.white),
                if (tp.showAddress) ...[pw.SizedBox(height: 3), _t('GSTIN ${S.companyInfo['gstin']}   |   ${_companyContact}', size: 8, color: PdfColors.grey200)],
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                _t(title, size: 15, bold: true, color: PdfColors.white),
                pw.SizedBox(height: 3),
                _t('Generated ${_stamp()}${tp.showPreparedBy ? '   |   $_user' : ''}', size: 8, color: PdfColors.grey200),
              ]),
            ]),
          )
        : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            // company on the left, report title on the right — both centred on the logo
            _brandBlock(title, ['Generated ${_stamp()}', if (tp.showPreparedBy) 'Prepared by $_user']),
            pw.SizedBox(height: compact ? 8 : 14),
            pw.Container(height: minimal ? 1 : 2, color: minimal ? _ink : _blue),
            pw.SizedBox(height: compact ? 6 : 10),
          ]),
    footer: (ctx) => _footer(ctx, '${S.currentCompany}   |   $title${tp.showPreparedBy ? '   |   Generated by $_user' : ''}'),
    build: (ctx) => [
      // information bar
      if (tp.showInfoBar) pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: minimal ? 0 : 12, vertical: compact ? 5 : 8),
        decoration: minimal
            ? const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: .6)))
            : pw.BoxDecoration(color: _band, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(children: [
          infoItem('As on', _dmy(todayStr())),
          infoItem('Warehouse', '${S.currentWh.code} - ${S.currentWh.city}'),
          infoItem('Records', '${rows.length}'),
          infoItem('Filters', filters == null || filters.isEmpty ? 'None (all records)' : filters.entries.map((e) => '${e.key}: ${e.value}').join('   |   '), flex: 2),
        ]),
      ),
      if (tp.showInfoBar) pw.SizedBox(height: compact ? 6 : 10),
      // the company's own lines (Setup › Report Templates › Custom fields)
      if (extra.isNotEmpty) ...[
        pw.Wrap(spacing: 22, runSpacing: 4, children: [
          for (final f in extra)
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: '${_pdfSafe(f.$1)}: ', style: pw.TextStyle(fontSize: 8.2, color: _soft)),
              pw.TextSpan(text: _pdfSafe(f.$2), style: pw.TextStyle(fontSize: 8.4, fontWeight: pw.FontWeight.bold, color: _ink)),
            ])),
        ]),
        pw.SizedBox(height: compact ? 6 : 10),
      ],
      // key figures
      if (tp.showKeyFigures && summary != null && summary.isNotEmpty) ...[
        pw.Row(children: [
          for (var i = 0; i < summary.length; i++) ...[
            if (i > 0) pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(11, 8, 11, 9),
                decoration: modern
                    ? pw.BoxDecoration(color: _band, border: pw.Border(left: pw.BorderSide(color: _blue, width: 3)))
                    : pw.BoxDecoration(border: pw.Border.all(color: _line, width: .7), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _label(summary[i].$1),
                  pw.SizedBox(height: 2),
                  _t(summary[i].$2.replaceAll('₹', 'Rs. '), size: 14, bold: true),
                ]),
              ),
            ),
          ],
        ]),
        pw.SizedBox(height: 12),
      ],
      // the table: dark header, light horizontal rules, alternate row shading, bold total
      if (rows.isEmpty)
        pw.Padding(padding: const pw.EdgeInsets.all(16), child: _t('No records match the selected filters.', size: 10, color: _soft, align: pw.TextAlign.center))
      else
        pw.Table(
          columnWidths: widths,
          border: tableBorder,
          children: [
            pw.TableRow(
              decoration: minimal ? const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1))) : pw.BoxDecoration(color: headBg),
              repeat: true,
              children: [for (var i = 0; i < n; i++) cell(headers[i].toUpperCase(), right: numeric[i], bold: true, color: headFg, size: compact ? 6.6 : 7.2)],
            ),
            for (var k = 0; k < data.length; k++)
              pw.TableRow(
                decoration: pw.BoxDecoration(color: tp.shadeRows && k.isOdd ? _zebra : PdfColors.white),
                children: [for (var i = 0; i < n; i++) cell(data[k][i], right: numeric[i], bold: i == 0)],
              ),
            if (tp.showTotals && totals.any((t) => t != null))
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _band, border: pw.Border(top: pw.BorderSide(color: _ink, width: 1))),
                children: [for (var i = 0; i < n; i++) cell(totals[i] ?? (i == 0 ? totalLabel : ''), right: totals[i] != null, bold: true, size: compact ? 7.8 : 8.6)],
              ),
          ],
        ),
    ],
  ));
  return doc.save();
}

// ================================================================ GST tax invoice
/// The sales invoice created on dispatch, laid out as a GST tax invoice.
Future<Uint8List> buildInvoicePdf(Doc inv) async {
  final c = S.cust(inv.party!);
  final calc = S.calc(inv);
  final so = inv.ref == null ? null : S.doc(inv.ref!);
  final dn = S.docsOf('DN').where((d) => d.ref == inv.ref || d.id == inv.ref).firstOrNull;
  final inter = calc.inter;
  final ad = S.addressDoc(inv);
  final shipState = ad?.shipState ?? c.state;
  final stateCode = kStateCodes[shipState] ?? (c.gstin.length >= 2 ? c.gstin.substring(0, 2) : '37');
  final rounded = calc.total.roundToDouble();
  final doc = pw.Document(theme: await _pdfTheme(), title: 'Invoice ${inv.id}', author: S.currentCompany);

  pw.Widget cell(String s, {bool head = false, bool right = false, bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: _t(head ? s.toUpperCase() : s, size: head ? 6.8 : 8, bold: head || bold, color: head ? _soft : _ink, align: right ? pw.TextAlign.right : pw.TextAlign.left),
      );

  double cgstTotal = 0, igstTotal = 0;
  final lineRows = <pw.TableRow>[];
  for (var i = 0; i < inv.lines.length; i++) {
    final l = inv.lines[i];
    final p = S.item(l.item);
    final taxable = l.qty * l.rate;
    final tax = taxable * p.gst / 100;
    if (inter) {
      igstTotal += tax;
    } else {
      cgstTotal += tax / 2;
    }
    lineRows.add(pw.TableRow(children: [
      cell('${i + 1}'),
      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_t(l.desc ?? p.name, size: 8), _t(p.id, size: 7, color: _soft)])),
      cell(p.hsn),
      cell('${l.qty} ${p.uom}', right: true),
      cell(money(l.rate), right: true),
      cell(money(taxable), right: true),
      if (inter) cell('${p.gst}% - ${money(tax)}', right: true) else ...[
        cell('${p.gst / 2}% - ${money(tax / 2)}'.replaceAll('.0%', '%'), right: true),
        cell('${p.gst / 2}% - ${money(tax / 2)}'.replaceAll('.0%', '%'), right: true),
      ],
      cell(money(taxable + tax), right: true),
    ]));
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 24),
    footer: (ctx) => _footer(ctx, reportTemplate.invoiceFooter),
    build: (ctx) => [
      _docHeader(reportTemplate.invoiceTitle, [reportTemplate.invoiceCopy]),
      _pair(
        _kv([('Invoice No.', inv.id), ('Invoice Date', _dmy(inv.date)), ('Due Date', _dmy(inv.due ?? inv.date)), ('Payment Terms', 'Net ${c.terms} days')]),
        _kv([
          ('Sales Order', so?.id ?? '-'),
          ('Customer PO No.', ((so?.custPo ?? inv.custPo) ?? '').trim().isEmpty ? '-' : (so?.custPo ?? inv.custPo)!),
          ('Delivery Note', dn?.id ?? '-'),
          ('E-way Bill', calc.total > S.params.ewayLimit ? (inv.eway ?? dn?.eway ?? 'Generated') : 'Not required (below Rs.50,000)'),
          ('Vehicle', dn?.vehicle ?? '-'),
        ])),
      _pair(
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _label('Bill to'),
          _t(c.name, size: 9.5, bold: true),
          _t(ad?.billTo ?? '${c.city}, ${c.state}', size: 8),
          _t('GSTIN ${c.gstin}', size: 8),
          _t('Contact: ${c.contact} - ${c.phone}', size: 8, color: _soft),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _label('Ship to'),
          _t(c.name, size: 9.5, bold: true),
          _t(ad?.shipTo ?? '${c.city}, ${c.state}', size: 8),
          pw.SizedBox(height: 4),
          _t('Place of supply: $stateCode - $shipState', size: 8, bold: true),
        ]),
        joinAbove: true),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: .6),
        columnWidths: {
          0: const pw.FixedColumnWidth(18),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FixedColumnWidth(36),
          3: const pw.FixedColumnWidth(48),
          4: const pw.FixedColumnWidth(50),
          5: const pw.FixedColumnWidth(58),
          if (inter) 6: const pw.FixedColumnWidth(70) else ...{6: const pw.FixedColumnWidth(62), 7: const pw.FixedColumnWidth(62)},
          (inter ? 7 : 8): const pw.FixedColumnWidth(62),
        },
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _band), children: [
            cell('#', head: true), cell('Item', head: true), cell('HSN/SAC', head: true), cell('Qty', head: true, right: true), cell('Rate', head: true, right: true),
            cell('Taxable', head: true, right: true),
            if (inter) cell('IGST', head: true, right: true) else ...[cell('CGST', head: true, right: true), cell('SGST', head: true, right: true)],
            cell('Amount', head: true, right: true),
          ]),
          ...lineRows,
        ],
      ),
      _pair(
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _label('Amount in words'),
          _t(rupeesInWords(rounded), size: 8.5, bold: true),
          pw.SizedBox(height: 6),
          _label('Bank details'),
          _t(reportTemplate.bankDetails, size: 8),
        ]),
        pw.Column(children: [
              for (final r in [
                ('Taxable value', calc.sub),
                if (inter) ('IGST', igstTotal) else ...[('CGST', cgstTotal), ('SGST', cgstTotal)],
                ('Round-off', rounded - calc.total),
              ])
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_t(r.$1, size: 8.5, color: _soft), _t(money(r.$2), size: 8.5)]),
              pw.Divider(color: _ink, thickness: .8, height: 8),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_t('Invoice total', size: 10, bold: true), _t('Rs. ${money(rounded)}', size: 10, bold: true)]),
            ]),
        rightWidth: 190,
        joinAbove: true),
      pw.SizedBox(height: 10),
      _label('Terms & conditions'),
      _t('1. Prices are ex-warehouse unless stated otherwise. 2. Payment as per agreed terms; interest at 18% p.a. on overdue amounts. 3. Transit damage must be reported within 48 hours of delivery. 4. Subject to Visakhapatnam jurisdiction.',
          size: 7.8, color: _soft),
    ],
  ));
  return doc.save();
}

// ================================================================ payment receipt
/// Receipt for one customer payment (CP document) against an invoice.
Future<Uint8List> buildReceiptPdf(Doc cp) async {
  final c = S.cust(cp.party!);
  final inv = cp.ref == null ? null : S.doc(cp.ref!);
  final invAmt = inv?.amount ?? cp.amount;
  final paidBefore = inv == null ? 0.0 : S.docsOf('CP').where((p) => p.ref == inv.id && p.id.compareTo(cp.id) < 0).fold<double>(0, (a, p) => a + p.amount);
  final balance = invAmt - paidBefore - cp.amount;
  final doc = pw.Document(theme: await _pdfTheme(), title: 'Receipt ${cp.id}', author: S.currentCompany);

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 24),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      _docHeader(reportTemplate.receiptTitle, [cp.id, 'Date ${_dmy(cp.date)}']),
      pw.SizedBox(height: 14),
      pw.RichText(
          text: pw.TextSpan(style: const pw.TextStyle(fontSize: 9.5, color: _ink), children: [
        const pw.TextSpan(text: 'Received with thanks from '),
        pw.TextSpan(text: _pdfSafe(c.name), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TextSpan(text: ' (GSTIN ${c.gstin}) the sum of '),
        pw.TextSpan(text: _pdfSafe(rupeesInWords(cp.amount)), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        const pw.TextSpan(text: ' towards the invoice below.'),
      ])),
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 1.4)),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_label('Amount received'), _t('Rs. ${money(cp.amount)}', size: 16, bold: true)]),
      ),
      pw.SizedBox(height: 12),
      _pair(
        _kv([
          ('Payment mode', cp.mode ?? '-'),
          ('Bank reference', (cp.utr ?? '').isEmpty ? '-' : cp.utr!),
          ('Transaction date', _dmy(cp.date)),
          ('Deposited to', (cp.mode ?? '') == 'Cash' ? 'Cash' : 'HDFC Current A/c ...5678'),
        ]),
        _kv([
          ('Against invoice', inv?.id ?? '-'),
          ('Invoice amount', money(invAmt)),
          ('Paid earlier', money(paidBefore)),
          ('This payment', money(cp.amount)),
          ('Balance due', money(balance < 0 ? 0 : balance)),
        ])),
      pw.Spacer(),
      _footer(ctx, reportTemplate.receiptFooter),
    ]),
  ));
  return doc.save();
}

// ================================================================ CSV
Uint8List buildCsv(List<String> headers, List<List<String>> rows) {
  String q(String s) => '"${s.replaceAll('"', '""')}"';
  final sb = StringBuffer('﻿'); // BOM so Excel reads ₹ and other symbols correctly
  sb.writeln(headers.map(q).join(','));
  for (final r in rows) {
    sb.writeln(r.map(q).join(','));
  }
  return Uint8List.fromList(utf8.encode(sb.toString()));
}

// ================================================================ supplier tax invoice
/// The supplier's tax invoice for goods sent against our purchase order
/// (raised in the supplier portal or entered by Accounts): supplier as seller, our company as buyer.
Future<Uint8List> buildSupplierInvoicePdf(Doc pi) async {
  final s = S.sup(pi.party!);
  final w = S.wh(pi.wh);
  final calc = S.calc(pi);
  final inter = calc.inter;
  final po = pi.ref == null ? null : S.doc(pi.ref!);
  final grn = po == null ? null : S.docsOf('GRN').where((g) => g.ref == po.id).firstOrNull;
  final rounded = calc.total.roundToDouble();
  final initials = s.name.split(' ').where((x) => x.isNotEmpty).take(2).map((x) => x[0].toUpperCase()).join();
  final doc = pw.Document(theme: await _pdfTheme(), title: 'Supplier invoice ${pi.supInv ?? pi.id}', author: s.name);

  pw.Widget cell(String v, {bool head = false, bool right = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: _t(head ? v.toUpperCase() : v, size: head ? 6.8 : 8, bold: head, color: head ? _soft : _ink, align: right ? pw.TextAlign.right : pw.TextAlign.left),
      );

  double half = 0, igst = 0;
  final rows = <pw.TableRow>[];
  for (var i = 0; i < pi.lines.length; i++) {
    final l = pi.lines[i];
    final p = S.item(l.item);
    final taxable = l.qty * l.rate;
    final tax = taxable * p.gst / 100;
    if (inter) {
      igst += tax;
    } else {
      half += tax / 2;
    }
    rows.add(pw.TableRow(children: [
      cell('${i + 1}'),
      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_t(l.desc ?? p.name, size: 8), _t(p.id, size: 7, color: _soft)])),
      cell(p.hsn),
      cell('${l.qty} ${p.uom}', right: true),
      cell(money(l.rate), right: true),
      cell(money(taxable), right: true),
      if (inter) cell('${p.gst}% - ${money(tax)}', right: true) else ...[
        cell('${p.gst / 2}% - ${money(tax / 2)}'.replaceAll('.0%', '%'), right: true),
        cell('${p.gst / 2}% - ${money(tax / 2)}'.replaceAll('.0%', '%'), right: true),
      ],
      cell(money(taxable + tax), right: true),
    ]));
  }

  final verified = pi.match == null ? 'Not verified yet' : pi.match!.msg;

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 24),
    footer: (ctx) => _footer(ctx, 'Supplier invoice recorded in ${S.currentCompany} as ${pi.id}'),
    build: (ctx) => [
      // the supplier is the seller on this invoice
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        margin: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.6))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Container(
                width: 46,
                height: 46,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(9)),
                child: _t(initials, size: 15, bold: true, color: PdfColors.white)),
            pw.SizedBox(width: 14),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _t(s.name, size: 13, bold: true),
              pw.SizedBox(height: 4),
              _t('${s.city}, ${s.state}', size: 8.5, color: _soft),
              pw.SizedBox(height: 2.5),
              _t('GSTIN ${s.gstin}', size: 8.5, color: _soft),
              pw.SizedBox(height: 2.5),
              _t('Contact: ${s.contact}', size: 8.5, color: _soft),
            ]),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            _t('TAX INVOICE', size: 17, bold: true),
            pw.SizedBox(height: 4),
            _t('Original for recipient', size: 8.5, color: _soft),
          ]),
        ]),
      ),
      _pair(
        _kv([('Invoice No.', pi.supInv ?? '-'), ('Invoice Date', _dmy(pi.date)), ('Due Date', _dmy(pi.due ?? pi.date)), ('Payment Terms', 'Net ${s.terms} days')]),
        _kv([('Purchase Order', po?.id ?? '-'), ('Goods Receipt', grn?.id ?? 'Not received yet'), ('Our Reference', pi.id), ('Status', pi.status)])),
      _pair(
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _label('Bill to (buyer)'),
          _t(S.currentCompany, size: 9.5, bold: true),
          _t(_companyAddress, size: 8),
          _t('GSTIN ${S.companyInfo['gstin']}', size: 8),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _label('Ship to'),
          _t('${w.code} - ${w.name}', size: 9.5, bold: true),
          _t('${w.city}, ${w.state}', size: 8),
          pw.SizedBox(height: 4),
          _t('Place of supply: ${kStateCodes[w.state] ?? '37'} - ${w.state}', size: 8, bold: true),
        ]),
        joinAbove: true),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: .6),
        columnWidths: {
          0: const pw.FixedColumnWidth(18),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FixedColumnWidth(36),
          3: const pw.FixedColumnWidth(48),
          4: const pw.FixedColumnWidth(50),
          5: const pw.FixedColumnWidth(58),
          if (inter) 6: const pw.FixedColumnWidth(70) else ...{6: const pw.FixedColumnWidth(62), 7: const pw.FixedColumnWidth(62)},
          (inter ? 7 : 8): const pw.FixedColumnWidth(62),
        },
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _band), children: [
            cell('#', head: true), cell('Item', head: true), cell('HSN/SAC', head: true), cell('Qty', head: true, right: true), cell('Rate', head: true, right: true),
            cell('Taxable', head: true, right: true),
            if (inter) cell('IGST', head: true, right: true) else ...[cell('CGST', head: true, right: true), cell('SGST', head: true, right: true)],
            cell('Amount', head: true, right: true),
          ]),
          ...rows,
        ],
      ),
      _pair(
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _label('Amount in words'),
          _t(rupeesInWords(rounded), size: 8.5, bold: true),
          pw.SizedBox(height: 6),
          _label('Verification by ${S.currentCompany}'),
          _t(verified, size: 8),
        ]),
        pw.Column(children: [
              for (final r in [
                ('Taxable value', calc.sub),
                if (inter) ('IGST', igst) else ...[('CGST', half), ('SGST', half)],
                ('Round-off', rounded - calc.total),
              ])
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_t(r.$1, size: 8.5, color: _soft), _t(money(r.$2), size: 8.5)]),
              pw.Divider(color: _ink, thickness: .8, height: 8),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_t('Invoice total', size: 10, bold: true), _t('Rs. ${money(rounded)}', size: 10, bold: true)]),
            ]),
        rightWidth: 190,
        joinAbove: true),
    ],
  ));
  return doc.save();
}

// ================================================================ order documents
/// Printable quotation, sales order, purchase order or purchase request.
Future<Uint8List> buildOrderPdf(Doc d) async {
  const titles = {'QT': 'QUOTATION', 'SO': 'SALES ORDER', 'PO': 'PURCHASE ORDER', 'PR': 'PURCHASE REQUEST'};
  final sales = d.type == 'QT' || d.type == 'SO';
  final w = S.wh(d.wh);
  final calc = S.calc(d);
  final inter = calc.inter;
  final rounded = calc.total.roundToDouble();
  final doc = pw.Document(theme: await _pdfTheme(), title: '${titles[d.type] ?? d.type} ${d.id}', author: S.currentCompany);

  // the other party: customer for sales documents, supplier for purchase documents
  String partyName = '-', partyLines = '', partyGstin = '', terms = '';
  if (d.party != null && sales) {
    final c = S.cust(d.party!);
    final ad = S.addressDoc(d);
    partyName = c.name;
    partyLines = ad?.billTo ?? '${c.city}, ${c.state}';
    partyGstin = c.gstin;
    terms = 'Net ${c.terms} days';
  } else if (d.party != null) {
    final s = S.sup(d.party!);
    partyName = s.name;
    partyLines = '${s.city}, ${s.state}';
    partyGstin = s.gstin;
    terms = 'Net ${s.terms} days';
  }
  final shipName = sales ? partyName : '${w.code} - ${w.name}';
  final shipLines = sales ? (S.addressDoc(d)?.shipTo ?? partyLines) : '${w.city}, ${w.state}';
  final shipState = sales ? (S.addressDoc(d)?.shipState ?? (d.party == null ? w.state : S.cust(d.party!).state)) : w.state;

  final dateLabel = {'QT': ('Valid Until', d.valid), 'SO': ('Delivery Date', d.delivery), 'PO': ('Expected By', d.need ?? d.delivery), 'PR': ('Needed By', d.need)}[d.type];

  pw.Widget cell(String v, {bool head = false, bool right = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: _t(head ? v.toUpperCase() : v, size: head ? 6.8 : 8, bold: head, color: head ? _soft : _ink, align: right ? pw.TextAlign.right : pw.TextAlign.left),
      );

  double half = 0, igst = 0;
  final rows = <pw.TableRow>[];
  for (var i = 0; i < d.lines.length; i++) {
    final l = d.lines[i];
    final p = S.item(l.item);
    final qty = l.qty.abs();
    final taxable = qty * l.rate;
    final tax = taxable * p.gst / 100;
    if (inter) {
      igst += tax;
    } else {
      half += tax / 2;
    }
    rows.add(pw.TableRow(children: [
      cell('${i + 1}'),
      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_t(l.desc ?? p.name, size: 8), _t(p.id, size: 7, color: _soft)])),
      cell(p.hsn),
      cell('$qty ${p.uom}', right: true),
      cell(money(l.rate), right: true),
      cell(money(taxable), right: true),
      if (inter) cell('${p.gst}% - ${money(tax)}', right: true) else ...[
        cell('${p.gst / 2}% - ${money(tax / 2)}'.replaceAll('.0%', '%'), right: true),
        cell('${p.gst / 2}% - ${money(tax / 2)}'.replaceAll('.0%', '%'), right: true),
      ],
      cell(money(taxable + tax), right: true),
    ]));
  }

  final tnc = sales
      ? '1. Prices are ex-warehouse unless stated otherwise. 2. Payment as per agreed terms; interest at 18% p.a. on overdue amounts. 3. Transit damage must be reported within 48 hours of delivery. 4. Subject to Visakhapatnam jurisdiction.'
      : '1. Quote our PO number on the invoice and delivery challan. 2. Goods are accepted only after quality check; rejected goods are returned at the supplier\'s cost. 3. Deliver to the warehouse shown, Monday to Saturday, 9 am to 5 pm. 4. Subject to Visakhapatnam jurisdiction.';

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 24),
    footer: (ctx) => _footer(ctx, '${titles[d.type] ?? d.type} ${d.id}'),
    build: (ctx) => [
      _docHeader(titles[d.type] ?? d.type, [d.id, 'Date ${_dmy(d.date)}']),
      _pair(
        _kv([
          ('Document No.', d.id),
          ('Date', _dmy(d.date)),
          if (dateLabel != null && dateLabel.$2 != null) (dateLabel.$1, _dmy(dateLabel.$2!)),
          ('Status', d.status),
        ]),
        _kv([
          ('Reference', d.ref ?? '-'),
          ('Warehouse', '${w.code} - ${w.city}'),
          if (terms.isNotEmpty) ('Payment Terms', terms),
          ('Prepared by', (d.by ?? 'Srinivas Rao').split(' (').first),
        ]),
      ),
      _pair(
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _label(sales ? 'Customer' : (d.type == 'PR' ? 'Preferred supplier' : 'Supplier')),
          _t(partyName, size: 9.5, bold: true),
          if (partyLines.isNotEmpty) _t(partyLines, size: 8),
          if (partyGstin.isNotEmpty) _t('GSTIN $partyGstin', size: 8),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _label(sales ? 'Ship to' : 'Deliver to'),
          _t(shipName, size: 9.5, bold: true),
          _t(shipLines, size: 8),
          pw.SizedBox(height: 4),
          _t('Place of supply: ${kStateCodes[shipState] ?? '37'} - $shipState', size: 8, bold: true),
        ]),
        joinAbove: true,
      ),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: .6),
        columnWidths: {
          0: const pw.FixedColumnWidth(18),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FixedColumnWidth(36),
          3: const pw.FixedColumnWidth(48),
          4: const pw.FixedColumnWidth(50),
          5: const pw.FixedColumnWidth(58),
          if (inter) 6: const pw.FixedColumnWidth(70) else ...{6: const pw.FixedColumnWidth(62), 7: const pw.FixedColumnWidth(62)},
          (inter ? 7 : 8): const pw.FixedColumnWidth(62),
        },
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _band), children: [
            cell('#', head: true), cell('Item', head: true), cell('HSN/SAC', head: true), cell('Qty', head: true, right: true), cell('Rate', head: true, right: true),
            cell('Taxable', head: true, right: true),
            if (inter) cell('IGST', head: true, right: true) else ...[cell('CGST', head: true, right: true), cell('SGST', head: true, right: true)],
            cell('Amount', head: true, right: true),
          ]),
          ...rows,
        ],
      ),
      _pair(
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _label('Amount in words'),
          _t(rupeesInWords(rounded), size: 8.5, bold: true),
          if (fxNote(d) != null) ...[pw.SizedBox(height: 6), _label('Currency'), _t(fxNote(d)!, size: 8.5)],
        ]),
        pw.Column(children: [
          for (final r in [
            ('Taxable value', calc.sub),
            if (inter) ('IGST', igst) else ...[('CGST', half), ('SGST', half)],
            ('Round-off', rounded - calc.total),
          ])
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_t(r.$1, size: 8.5, color: _soft), _t(money(r.$2), size: 8.5)]),
          pw.Divider(color: _ink, thickness: .8, height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_t('Total', size: 10, bold: true), _t('Rs. ${money(rounded)}', size: 10, bold: true)]),
        ]),
        rightWidth: 190,
        joinAbove: true,
      ),
      pw.SizedBox(height: 10),
      _label('Terms & conditions'),
      _t(tnc, size: 7.8, color: _soft),
    ],
  ));
  return doc.save();
}

// ================================================================ clean buying documents
/// One clean layout for the buying documents (request, order, goods receipt, QC report,
/// purchase invoice): title block, two columns of details, a bordered table, totals,
/// and notes — all on the same margins. (No signature or authorised-signatory blocks are printed on any document.)
Future<Uint8List> _cleanPdf({
  required String title,
  required String id,
  required String status,
  required List<(String, String)> left,
  required List<(String, String)> right,
  required List<String> heads,
  required Map<int, pw.TableColumnWidth> widths,
  required Set<int> rightCols,
  required List<List<String>> rows,
  List<String?> subs = const [],
  String tableTitle = 'Line items',
  List<(String, String)> totals = const [],
  (String, String)? grand,
  List<(String, String)> notes = const [],
}) async {
  // no supplier on the document: leave its supplier lines out instead of printing '-'
  bool keep((String, String) p) => !(p.$1.startsWith('Supplier') && p.$2 == '-');
  left = left.where(keep).toList();
  right = right.where(keep).toList();
  final doc = pw.Document(theme: await _pdfTheme(), title: '$title $id', author: S.currentCompany);
  const side = pw.BorderSide(color: _line, width: .7);

  pw.Widget field((String, String) f) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 96, child: _t(f.$1, size: 8.5, color: _soft)),
          pw.Expanded(child: _t(f.$2, size: 9, bold: true)),
        ]),
      );

  pw.Widget section(String t) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink, width: .8))),
        child: _t(t.toUpperCase(), size: 8.5, bold: true),
      );

  pw.Widget cell(String v, {bool head = false, bool right = false, bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: _t(v, size: head ? 7.5 : 8.5, bold: head || bold, color: head ? _soft : _ink, align: right ? pw.TextAlign.right : pw.TextAlign.left),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
    footer: (ctx) => _footer(ctx, '${titleCaseWords(title)} $id'),
    build: (ctx) => [
      // ---- title block
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _t(S.currentCompany, size: 13, bold: true),
            pw.SizedBox(height: 3),
            _t(_companyAddress, size: 8, color: _soft),
            pw.SizedBox(height: 2),
            _t('GSTIN ${S.companyInfo['gstin']}', size: 8, color: _soft),
          ]),
        ),
        pw.SizedBox(width: 20),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          _t(title, size: 15, bold: true),
          pw.SizedBox(height: 4),
          _t(id, size: 10, bold: true),
          pw.SizedBox(height: 2),
          _t('Status: $status', size: 8.5, color: _soft),
        ]),
      ]),
      pw.SizedBox(height: 10),
      pw.Container(height: 1.4, color: _ink),
      // ---- details
      section('Details'),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(children: [for (final f in left) field(f)])),
        pw.SizedBox(width: 24),
        pw.Expanded(child: pw.Column(children: [for (final f in right) field(f)])),
      ]),
      // ---- table
      section(tableTitle),
      pw.Table(
        border: const pw.TableBorder(top: side, bottom: side, left: side, right: side, horizontalInside: side),
        columnWidths: widths,
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _band), children: [
            for (var i = 0; i < heads.length; i++) cell(heads[i].toUpperCase(), head: true, right: rightCols.contains(i)),
          ]),
          for (var r = 0; r < rows.length; r++)
            pw.TableRow(children: [
              for (var i = 0; i < rows[r].length; i++)
                if (i == 1 && r < subs.length && subs[r] != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_t(rows[r][i], size: 8.5, bold: true), _t(subs[r]!, size: 7, color: _soft)]),
                  )
                else
                  cell(rows[r][i], right: rightCols.contains(i), bold: i == rows[r].length - 1 && rightCols.contains(i)),
            ]),
        ],
      ),
      // ---- totals
      if (totals.isNotEmpty || grand != null) ...[
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Spacer(),
          pw.SizedBox(
            width: 220,
            child: pw.Column(children: [
              for (final t in totals)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_t(t.$1, size: 8.5, color: _soft), _t(t.$2, size: 8.5)]),
                ),
              if (grand != null) ...[
                pw.Container(height: .8, color: _ink, margin: const pw.EdgeInsets.symmetric(vertical: 3)),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_t(grand.$1, size: 9.5, bold: true), _t(grand.$2, size: 9.5, bold: true)]),
              ],
            ]),
          ),
        ]),
      ],
      // ---- notes
      for (final n in notes) ...[section(n.$1), _t(n.$2.isEmpty ? '-' : n.$2, size: 8.8)],
    ],
  ));
  return doc.save();
}

String titleCaseWords(String s) => s.split(' ').map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()).join(' ');

String _rs(num v) => 'Rs. ${money(v)}';

/// A document agreed in a foreign currency: "USD · 1 USD = Rs. 83.50 · total USD 1,234.56" (null for ₹ documents).
String? fxNote(Doc d) {
  final cur = d.extra['v:currency'] ?? 'INR';
  if (cur == 'INR') return null;
  final fx = double.tryParse(d.extra['v:exrate'] ?? '') ?? S.currencies.where((c) => c.code == cur).firstOrNull?.rate ?? 1;
  if (fx <= 0) return null;
  final total = S.calc(d).total / fx;
  final parts = total.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'Agreed in $cur at 1 $cur = Rs. ${fx.toStringAsFixed(2)} · total $cur $whole.${parts[1]} (amounts above are in rupees)';
}

/// Standard money columns for priced documents: # | item | HSN | qty | rate | GST | amount
/// Goods receipt and quality check tables: four quantity columns wide enough for their headers.
const _qtyWidths = <int, pw.TableColumnWidth>{
  0: pw.FixedColumnWidth(22),
  1: pw.FlexColumnWidth(3),
  2: pw.FixedColumnWidth(54),
  3: pw.FixedColumnWidth(60),
  4: pw.FixedColumnWidth(60),
  5: pw.FixedColumnWidth(62),
  6: pw.FixedColumnWidth(60),
};

const _pricedWidths = <int, pw.TableColumnWidth>{
  0: pw.FixedColumnWidth(22),
  1: pw.FlexColumnWidth(3),
  2: pw.FixedColumnWidth(54),
  3: pw.FixedColumnWidth(56),
  4: pw.FixedColumnWidth(62),
  5: pw.FixedColumnWidth(36),
  6: pw.FixedColumnWidth(72),
};

List<List<String>> _pricedRows(Doc d) => [
      for (var i = 0; i < d.lines.length; i++)
        () {
          final l = d.lines[i];
          final it = S.item(l.item);
          return ['${i + 1}', l.desc ?? it.name, it.hsn, '${l.qty.abs()} ${it.uom}', money(l.rate), '${it.gst}%', money(l.qty.abs() * l.rate)];
        }(),
    ];

List<String?> _codes(Doc d) => [for (final l in d.lines) S.item(l.item).id];

List<(String, String)> _taxLines(Doc d) {
  final c = S.calc(d);
  return [('Taxable value', _rs(c.sub)), if (c.inter) ('IGST', _rs(c.tax)) else ...[('CGST', _rs(c.tax / 2)), ('SGST', _rs(c.tax / 2))]];
}

String _supName(Doc d) => d.party == null ? '-' : (S.suppliers.where((s) => s.id == d.party).firstOrNull?.name ?? '-');
String _supGstin(Doc d) => d.party == null ? '-' : (S.suppliers.where((s) => s.id == d.party).firstOrNull?.gstin ?? '-');
String _supPlace(Doc d) {
  final s = d.party == null ? null : S.suppliers.where((x) => x.id == d.party).firstOrNull;
  return s == null ? '-' : '${s.city}, ${s.state}';
}

String _deliverTo(Doc d) {
  final w = S.wh(d.wh);
  return '${w.code} - ${w.name}, ${w.city}';
}

/// Purchase request: same order as the request form.
Future<Uint8List> buildPurchaseRequestPdf(Doc d) => _cleanPdf(
      title: 'PURCHASE REQUEST',
      id: d.id,
      status: d.status,
      left: [('Request No.', d.id), ('Request Date', _dmy(d.date)), ('Requested By', d.requester ?? (d.source ?? '').split('— ').last), ('Department', d.dept ?? '-')],
      right: [
        ('Required By', d.need == null ? '-' : _dmy(d.need!)),
        // lines from several suppliers: all of them are named (no single GSTIN)
        if (d.party == null) ('Suppliers', S.prSupplierNames(d).isEmpty ? '-' : S.prSupplierNames(d)) else ...[('Supplier', _supName(d)), ('Supplier GSTIN', _supGstin(d))],
        ('Deliver To', _deliverTo(d)),
      ],
      heads: ['#', 'Item / Description', 'HSN / SAC', 'Qty', 'Est. Rate', 'GST', 'Amount'],
      widths: _pricedWidths,
      rightCols: {3, 4, 5, 6},
      rows: _pricedRows(d),
      subs: _codes(d),
      totals: _taxLines(d),
      grand: ('Estimated total', _rs(S.calc(d).total)),
      notes: [
        if (fxNote(d) != null) ('Currency', fxNote(d)!),
        ('Business justification', d.purpose ?? ''),
        if (d.status == 'Rejected' && (d.reason ?? '').isNotEmpty) ('Rejection reason', d.reason!),
      ],
    );

/// Purchase order sent to the supplier.
Future<Uint8List> buildPurchaseOrderPdf(Doc d) {
  final pr = d.ref == null ? null : S.doc(d.ref!);
  final terms = S.suppliers.where((s) => s.id == d.party).firstOrNull?.terms;
  return _cleanPdf(
    title: 'PURCHASE ORDER',
    id: d.id,
    status: d.status,
    left: [('PO No.', d.id), ('PO Date', _dmy(d.date)), ('Expected By', _dmy(d.need ?? d.delivery ?? addDays(d.date, 7))), ('Against Request', pr?.id ?? '-')],
    right: [('Supplier', _supName(d)), ('Supplier GSTIN', _supGstin(d)), ('Supplier Address', _supPlace(d)), ('Deliver To', _deliverTo(d)), if (terms != null) ('Payment Terms', 'Net $terms days')],
    heads: ['#', 'Item / Description', 'HSN / SAC', 'Qty', 'Rate', 'GST', 'Amount'],
    widths: _pricedWidths,
    rightCols: {3, 4, 5, 6},
    rows: _pricedRows(d),
    subs: _codes(d),
    totals: _taxLines(d),
    grand: ('PO total', _rs(S.calc(d).total)),
    notes: [
      if (fxNote(d) != null) ('Currency', fxNote(d)!),
      ('Terms & conditions',
          '1. Quote this PO number on the invoice and delivery challan.  2. Goods are accepted only after quality check; rejected goods are returned at the supplier\'s cost.  3. Deliver to the warehouse above, Monday to Saturday, 9 am to 5 pm.  4. Payment as per the agreed terms from the date of goods receipt.'),
    ],
  );
}

/// Goods receipt note: what arrived against the PO.
Future<Uint8List> buildGrnPdf(Doc g) {
  final po = g.ref == null ? null : S.doc(g.ref!);
  final qcOk = qcDone(g);
  return _cleanPdf(
    title: 'GOODS RECEIPT NOTE',
    id: g.id,
    status: g.status,
    left: [('GRN No.', g.id), ('GRN Date', _dmy(g.date)), ('PO No.', po?.id ?? '-'), ('Vehicle No.', g.vehicle ?? '-')],
    right: [('Supplier', _supName(g)), ('Supplier GSTIN', _supGstin(g)), ('Received At', _deliverTo(g)), ('Received By', g.by ?? 'Kiran Kumar (Warehouse)')],
    heads: ['#', 'Item / Description', 'HSN / SAC', 'Ordered', 'Received', 'Accepted', 'Rejected'],
    widths: _qtyWidths,
    rightCols: {3, 4, 5, 6},
    rows: [
      for (var i = 0; i < g.lines.length; i++)
        () {
          final l = g.lines[i];
          final it = S.item(l.item);
          final ordered = po?.lines.where((x) => x.item == l.item).firstOrNull?.qty ?? l.qty;
          return ['${i + 1}', l.desc ?? it.name, it.hsn, '$ordered ${it.uom}', '${l.qty} ${it.uom}', qcOk ? '${l.acc}' : 'QC pending', qcOk ? '${l.qty - l.acc}' : '-'];
        }(),
    ],
    subs: _codes(g),
    notes: [
      ('Remarks', qcOk ? 'Quality check completed on ${_dmy(g.qcDate ?? g.date)} by ${g.qcBy ?? 'QC'}.' : 'Goods held in the receiving area until quality check.'),
      if (S.binsOf(g).isNotEmpty) ('Stored in bins', S.binsOf(g).entries.map((e) => '${e.key}: ${e.value}').join(', ')),
    ],
  );
}

/// Quality check report for a goods receipt.
Future<Uint8List> buildQcPdf(Doc g) {
  final po = g.ref == null ? null : S.doc(g.ref!);
  final inspector = g.qcBy ?? 'Lakshmi P (QC Inspector)';
  final qcDate = g.qcDate ?? g.date;
  final isDone = qcDone(g) || g.qcResult != null;
  final totalRej = g.lines.fold<int>(0, (sum, l) => sum + (isDone ? l.qty - l.acc : 0));
  final qcResult = g.qcResult ??
      (isDone
          ? (totalRej == 0 ? 'Passed' : (g.lines.every((l) => l.acc == 0) ? 'Failed' : 'Partially passed'))
          : 'Passed');
  return _cleanPdf(
    title: 'QUALITY CHECK REPORT',
    id: 'QC-${g.id}',
    status: qcResult,
    left: [('GRN No.', g.id), ('QC Date', _dmy(qcDate)), ('Inspector', inspector), ('Result', qcResult)],
    right: [('Supplier', _supName(g)), ('PO No.', po?.id ?? '-'), ('Received By', (g.by ?? 'Warehouse').split(' (').first), ('Warehouse', _deliverTo(g))],
    tableTitle: 'Inspection results',
    heads: ['#', 'Item / Description', 'HSN / SAC', 'Received', 'Accepted', 'Rejected', 'Result'],
    widths: _qtyWidths,
    rightCols: {3, 4, 5},
    rows: [
      for (var i = 0; i < g.lines.length; i++)
        () {
          final l = g.lines[i];
          final it = S.item(l.item);
          final acc = isDone ? l.acc : (l.acc > 0 ? l.acc : l.qty);
          final rej = l.qty - acc;
          return ['${i + 1}', l.desc ?? it.name, it.hsn, '${l.qty} ${it.uom}', '$acc', '$rej', rej == 0 ? 'Passed' : (acc == 0 ? 'Rejected' : 'Partially passed')];
        }(),
    ],
    subs: _codes(g),
    notes: [
      ('Rejection reason', isDone ? qcRejectionText(g) : '-'),
    ],
  );
}

/// Purchase invoice from the supplier, as recorded and verified.
Future<Uint8List> buildPurchaseInvoicePdf(Doc pi) {
  final po = pi.ref == null ? null : S.doc(pi.ref!);
  final grn = po == null ? null : S.docsOf('GRN').where((g) => g.ref == po.id).firstOrNull;
  return _cleanPdf(
    title: 'PURCHASE INVOICE',
    id: pi.id,
    status: pi.status,
    left: [('Supplier Invoice No.', pi.supInv ?? '-'), ('Invoice Date', _dmy(pi.date)), ('Due Date', _dmy(pi.due ?? pi.date)), ('Our Reference', pi.id)],
    right: [('Supplier', _supName(pi)), ('Supplier GSTIN', _supGstin(pi)), ('PO No.', po?.id ?? '-'), ('GRN No.', grn?.id ?? 'Not received yet')],
    heads: ['#', 'Item / Description', 'HSN / SAC', 'Qty', 'Rate', 'GST', 'Amount'],
    widths: _pricedWidths,
    rightCols: {3, 4, 5, 6},
    rows: _pricedRows(pi),
    subs: _codes(pi),
    totals: _taxLines(pi),
    grand: ('Invoice total', _rs(S.calc(pi).total.roundToDouble())),
    notes: [('Amount in words', rupeesInWords(S.calc(pi).total.roundToDouble())), ('Verification', pi.match?.msg ?? 'Not verified yet')],
  );
}

/// Purchase return note: the goods going back to the supplier against a goods receipt.
Future<Uint8List> buildPurchaseReturnPdf(Doc r) {
  final g = r.ref == null ? null : S.doc(r.ref!);
  return _cleanPdf(
    title: 'PURCHASE RETURN',
    id: r.id,
    status: r.status,
    left: [('Return No.', r.id), ('Return Date', _dmy(r.date)), ('GRN No.', g?.id ?? '-'), ('PO No.', g?.ref ?? '-')],
    right: [('Supplier', _supName(r)), ('Supplier GSTIN', _supGstin(r)), ('Return From', _deliverTo(r)), ('Reason', r.reason ?? '-')],
    heads: ['#', 'Item / Description', 'HSN / SAC', 'Qty', 'Rate', 'GST', 'Amount'],
    widths: _pricedWidths,
    rightCols: {3, 4, 5, 6},
    rows: _pricedRows(r),
    subs: _codes(r),
    totals: _taxLines(r),
    grand: ('Return value', _rs(S.calc(r).total.roundToDouble())),
    notes: [if ((r.note ?? '').isNotEmpty) ('Remarks', r.note!)],
  );
}
