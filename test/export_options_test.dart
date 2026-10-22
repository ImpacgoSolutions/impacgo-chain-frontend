import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/export_builders.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/screens/common.dart';
import 'package:impacgo_chain/ui/export_options.dart';
import 'package:impacgo_chain/ui/overlays.dart';

/// Download options: every document builds with any part left out, the GST parts of tax documents stay locked,
/// and the options window fits a laptop and a phone.
void main() {
  // the website's demo data: one worked example of every document (set before the store is first used)
  AppStore.singleDemo = true;
  final builders = <String, Future<Uint8List> Function(Set<String> hide)>{
    'QT': (h) => buildOrderPdf(S.docsOf('QT').first, hide: h),
    'SO': (h) => buildOrderPdf(S.docsOf('SO').first, hide: h),
    'PR': (h) => buildPurchaseRequestPdf(S.docsOf('PR').first, hide: h),
    'PO': (h) => buildPurchaseOrderPdf(S.docsOf('PO').first, hide: h),
    'GRN': (h) => buildGrnPdf(S.docsOf('GRN').first, hide: h),
    'QC': (h) => buildQcPdf(S.docsOf('GRN').first, hide: h),
    'PI': (h) => buildPurchaseInvoicePdf(S.docsOf('PI').first, hide: h),
    'PRT': (h) => buildPurchaseReturnPdf(S.docsOf('PRT').first, hide: h),
    'INV': (h) => buildInvoicePdf(S.docsOf('INV').first, hide: h),
    'CP': (h) => buildReceiptPdf(S.docsOf('CP').first, hide: h),
  };

  for (final e in builders.entries) {
    test('${e.key}: the PDF builds with everything, and with every optional part left out', () async {
      final full = await e.value(const {});
      final choices = docExportChoices(e.key);
      expect(choices, isNotEmpty);
      final hideAll = {for (final c in choices) if (!c.locked) c.key};
      final lean = await e.value(hideAll);
      expect(full.length, greaterThan(1000));
      expect(lean.length, greaterThan(1000));
      if (hideAll.isNotEmpty) expect(lean.length, lessThan(full.length), reason: 'leaving parts out makes a smaller file');
    });
  }

  test('tax documents keep GSTIN, HSN and GST locked; other documents let them go', () {
    for (final t in ['INV', 'PI', 'PRT']) {
      final locked = {for (final c in docExportChoices(t)) if (c.locked) c.key};
      expect(locked, containsAll([ExportPart.gstin, ExportPart.hsn, ExportPart.gst]), reason: t);
    }
    expect({for (final c in docExportChoices('INV')) if (c.locked) c.key}, contains(ExportPart.address));
    for (final t in ['QT', 'SO', 'PR', 'PO', 'GRN', 'QC', 'CP']) {
      expect(docExportChoices(t).where((c) => c.locked), isEmpty, reason: t);
    }
  });

  for (final (name, size) in [('laptop', const Size(1536, 800)), ('phone', const Size(390, 844))]) {
    testWidgets('document options window on a $name: opens cleanly, locked parts stay ticked', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ImpacgoChainApp());
      await tester.pump(const Duration(milliseconds: 300));
      Set<String>? built;
      final inv = S.docsOf('INV').first;
      openDocExport(
        title: 'Download Tax Invoice · ${inv.id}',
        rememberAs: 'test-INV',
        choices: docExportChoices('INV'),
        build: (h) async {
          built = h;
          return Uint8List(0);
        },
        download: (_) async {},
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('Customer GSTIN'), findsOneWidget);
      expect(find.text('Bank details'), findsOneWidget);
      // a locked part cannot be unticked
      await tester.tap(find.text('Customer GSTIN'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(built, isNot(contains(ExportPart.gstin)));
      // an optional part can
      await tester.ensureVisible(find.text('Bank details'));
      await tester.tap(find.text('Bank details'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(built, contains(ExportPart.bank));
      closeAll();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('column options window on a $name: only the chosen columns are exported', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ImpacgoChainApp());
      await tester.pump(const Duration(milliseconds: 300));
      List<String>? heads;
      List<List<String>>? data;
      openColumnExport(
        title: 'Export CSV · 2 rows',
        rememberAs: 'test-cols-$name',
        headers: const ['Item Code', 'Item Name', 'Qty'],
        rows: const [['ITM-1', 'Carton', '5'], ['ITM-2', 'Tape', '9']],
        outputs: [('Download CSV', 'download', (h, d) async {
            heads = h;
            data = d;
          })],
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Item Name').first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Download CSV'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(heads, ['Item Code', 'Qty']);
      expect(data, [['ITM-1', '5'], ['ITM-2', '9']]);
      expect(tester.takeException(), isNull);
    });
  }
}
