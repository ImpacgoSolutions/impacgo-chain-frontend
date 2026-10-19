import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/screens/common.dart';
import 'package:impacgo_chain/screens/crm.dart';
import 'package:impacgo_chain/ui/overlays.dart';

String texts(WidgetTester t) => t.widgetList<Text>(find.byType(Text)).map((e) => e.data ?? '').join(' | ');
/// What is typed in the text boxes (not hints).
String typed(WidgetTester t) => t.widgetList<TextField>(find.byType(TextField)).map((e) => e.controller?.text ?? '').where((x) => x.isNotEmpty).join(' | ');

void main() {
  testWidgets('New lead: only the number, date and status are filled in', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ImpacgoChainApp());
    await tester.pump(const Duration(milliseconds: 400));
    newLeadForm();
    await tester.pump(const Duration(milliseconds: 500));
    final all = texts(tester);
    // what a person decides is not pre-picked
    for (final decided in ['Website enquiry', 'Priya Sharma', 'Andhra Pradesh', 'Industrial Safety Helmet']) {
      expect(all.contains(decided), isFalse, reason: '"$decided" must not be pre-picked');
    }
    final boxes = typed(tester);
    for (final decided in ['Kurnool', '100000']) {
      expect(boxes.contains(decided), isFalse, reason: '"$decided" must not be pre-typed (typed boxes: $boxes)');
    }
    // placeholders are shown instead
    expect(all.contains('Select lead source'), isTrue);
    expect(all.contains('Select sales person'), isTrue);
    expect(all.contains('Select state'), isTrue);
    expect(all.contains('Select product interest'), isTrue);
    // what the system decides is there
    expect(all.contains('LEAD-0'), isTrue);
    // saving the empty form is refused
    await tester.tap(find.text('Save lead'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(S.leads.length, 3, reason: 'nothing may be saved from an empty form');
    closeAll();
  });

  testWidgets('New quotation and sales order start without a customer, sales person, terms or items', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ImpacgoChainApp());
    await tester.pump(const Duration(milliseconds: 400));
    for (final t in ['QT', 'SO']) {
      openDocForm(t);
      await tester.pump(const Duration(milliseconds: 500));
      final all = texts(tester);
      expect(all.contains('Select customer'), isTrue, reason: '$t customer');
      expect(all.contains('Select sales person'), isTrue, reason: '$t sales person');
      expect(all.contains('Select payment terms'), isTrue, reason: '$t payment terms');
      for (final invented in ['Sri Lakshmi Supermarkets', 'Ramesh Kumar', '12 Industrial Estate', '37ABCDE1234F1Z5', 'Net 30 days']) {
        expect(all.contains(invented), isFalse, reason: '$t must not invent "$invented"');
      }
      expect(tester.takeException(), isNull);
      closeAll();
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
