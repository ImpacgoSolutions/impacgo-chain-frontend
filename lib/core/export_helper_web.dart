// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'export_builders.dart';

/// Saves [bytes] as a file. The object URL is kept alive for a while so the
/// browser can finish the download (revoking it at once makes Chrome report
/// "Failed – network error") and so the preview tab can still read it.
void _download(Uint8List bytes, String mime, String fname, {bool preview = false}) {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  if (preview) html.window.open(url, '_blank');
  final a = html.AnchorElement(href: url)
    ..download = fname
    ..style.display = 'none';
  html.document.body?.append(a);
  a.click();
  a.remove();
  Future.delayed(const Duration(minutes: 2), () => html.Url.revokeObjectUrl(url));
}

/// Real Excel workbook (.xlsx). Returns the file name that was saved.
Future<String> exportExcel(String filename, String title, List<String> headers, List<List<String>> rows, {Map<String, String>? activeFilters, List<(String, String)>? summary}) async {
  final fname = reportFileName(filename, 'xlsx');
  _download(buildXlsx(title, headers, rows, activeFilters, summary), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', fname);
  return fname;
}

/// Real PDF: opens in a new tab and downloads. Returns the file name that was saved.
Future<String> exportPdf(String filename, String title, List<String> headers, List<List<String>> rows, {Map<String, String>? activeFilters, List<(String, String)>? summary}) async {
  final fname = reportFileName(filename, 'pdf');
  _download(await buildPdf(title, headers, rows, activeFilters, summary), 'application/pdf', fname, preview: true);
  return fname;
}

/// CSV file (opens in Excel). Returns the file name that was saved.
Future<String> exportCsv(String filename, List<String> headers, List<List<String>> rows) async {
  final fname = reportFileName(filename, 'csv');
  _download(buildCsv(headers, rows), 'text/csv;charset=utf-8', fname);
  return fname;
}

/// Shows a PDF in a new browser tab only (nothing is downloaded) — used for previews.
Future<String> viewPdf(Uint8List bytes) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], 'application/pdf'));
  html.window.open(url, '_blank');
  Future.delayed(const Duration(minutes: 5), () => html.Url.revokeObjectUrl(url));
  return 'a new tab';
}

/// A ready-made PDF document (tax invoice, payment receipt): opens in a new tab and downloads.
Future<String> exportDocPdf(String fname, Uint8List bytes) async {
  _download(bytes, 'application/pdf', fname, preview: true);
  return fname;
}


String _mimeOf(String name) {
  final e = name.split('.').last.toLowerCase();
  return const {
        'pdf': 'application/pdf', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp',
        'txt': 'text/plain', 'csv': 'text/csv', 'doc': 'application/msword',
        'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'xls': 'application/vnd.ms-excel',
        'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      }[e] ??
      'application/octet-stream';
}

/// Opens the browser's file chooser (several files allowed) and returns each file's name and bytes.
/// Returns an empty list if nothing was chosen.
Future<List<(String, Uint8List)>> pickFiles() {
  final done = Completer<List<(String, Uint8List)>>();
  final input = html.FileUploadInputElement()
    ..multiple = true
    ..accept = '.pdf,.jpg,.jpeg,.png,.webp,.doc,.docx,.xls,.xlsx,.csv,.txt'
    ..style.display = 'none';
  html.document.body?.append(input);
  input.onChange.listen((_) async {
    final out = <(String, Uint8List)>[];
    for (final f in input.files ?? const <html.File>[]) {
      final r = html.FileReader()..readAsArrayBuffer(f);
      await r.onLoadEnd.first;
      final res = r.result;
      if (res is ByteBuffer) out.add((f.name, res.asUint8List()));
      if (res is Uint8List) out.add((f.name, res));
    }
    input.remove();
    if (!done.isCompleted) done.complete(out);
  });
  input.click();
  return done.future;
}

/// Opens an attached file: PDFs and images open in a new tab; every file is also downloaded.
void openAttachment(String name, Uint8List bytes) {
  final mime = _mimeOf(name);
  _download(bytes, mime, name, preview: mime == 'application/pdf' || mime.startsWith('image/'));
}
