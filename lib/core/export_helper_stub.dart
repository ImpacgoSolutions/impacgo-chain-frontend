import 'dart:io';
import 'dart:typed_data';
import 'export_builders.dart';

/// Desktop / mobile: writes the file to the user's Downloads folder (or the temp folder).
Future<String> _save(List<int> bytes, String fname) async {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  final sep = Platform.pathSeparator;
  final dl = home == null ? null : '$home${sep}Downloads';
  final dir = dl != null && Directory(dl).existsSync() ? dl : Directory.systemTemp.path;
  final path = '$dir$sep$fname';
  await File(path).writeAsBytes(bytes);
  return path;
}

Future<String> exportExcel(String filename, String title, List<String> headers, List<List<String>> rows, {Map<String, String>? activeFilters, List<(String, String)>? summary}) =>
    _save(buildXlsx(title, headers, rows, activeFilters, summary), reportFileName(filename, 'xlsx'));

Future<String> exportPdf(String filename, String title, List<String> headers, List<List<String>> rows, {Map<String, String>? activeFilters, List<(String, String)>? summary}) async =>
    _save(await buildPdf(title, headers, rows, activeFilters, summary), reportFileName(filename, 'pdf'));

Future<String> exportCsv(String filename, List<String> headers, List<List<String>> rows) => _save(buildCsv(headers, rows), reportFileName(filename, 'csv'));

/// Preview: desktop has no browser tab, so the PDF is saved to Downloads to open from there.
Future<String> viewPdf(List<int> bytes) => _save(bytes, 'Template_Preview.pdf');

/// A ready-made PDF document (tax invoice, payment receipt) saved to Downloads.
Future<String> exportDocPdf(String fname, List<int> bytes) => _save(bytes, fname);


/// File chooser is available in the web app; on other platforms nothing is picked.
Future<List<(String, Uint8List)>> pickFiles() async => const [];

/// Saves an attached file to Downloads.
void openAttachment(String name, Uint8List bytes) => _save(bytes, name);
