import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/format.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/ui/overlays.dart';
import 'package:impacgo_chain/ui/widgets.dart';

/// Saves every "New …" form with ONLY its mandatory fields filled (everything else left empty), the way a person
/// now fills them in. A save that relied on the old pre-filled values would throw here.
void main() {
  final screens = ['leads','opps','contacts','h_customers','cgroups','suppliers','h_items','itemcategories','itemsetup','pricing','h_warehouses','bins','h_team','salespersons','territories','vehicles','drivers','batches','putaway','transfers','counting','series','setuplists'];
  testWidgets('every New form saves with only the mandatory fields', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ImpacgoChainApp());
    await tester.pump(const Duration(milliseconds: 400));
    final report = <String>[];
    final bad = <String>[];
    final seen = <String>{};
    for (final id in screens) {
      S.go(id);
      await tester.pump(const Duration(milliseconds: 350));
      final n = find.byType(Btn).evaluate().length;
      for (var i = 0; i < n; i++) {
        S.go(id);
        await tester.pump(const Duration(milliseconds: 250));
        final btns = find.byType(Btn);
        if (i >= btns.evaluate().length) break;
        final label = (tester.widget(btns.at(i)) as dynamic).label.toString();
        if (!label.toLowerCase().startsWith('new ')) continue;
        debugLastForm = null;
        await tester.ensureVisible(btns.at(i));
        await tester.tap(btns.at(i), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 450));
        final form = debugLastForm;
        if (form == null || !form.title.startsWith('New ') || !seen.add(form.title)) { closeAll(); await tester.pump(const Duration(milliseconds: 200)); tester.takeException(); continue; }
        // build what a person types: only the mandatory fields
        final v = <String, dynamic>{};
        for (final f in form.fields) {
          if (f.type == 'header') continue;
          final must = f.req;
          switch (f.type) {
            case 'select': v[f.k] = must && f.options.isNotEmpty ? f.options.first.value : (f.options.any((o) => o.value == f.def) && (f.k == 'status' || f.k == 'currency') ? f.def : ''); break;
            case 'number': v[f.k] = must ? 5 : null; break;
            case 'email': v[f.k] = must ? 'a@b.co' : ''; break;
            case 'date': v[f.k] = f.def.isEmpty ? todayStr() : f.def; break;
            case 'checks': v[f.k] = must && f.options.isNotEmpty ? [f.options.first.value] : <String>[]; break;
            case 'readonly': v[f.k] = f.def; break;
            default: v[f.k] = must ? 'Test ${f.k}' : (f.k == 'phone' ? '+91 9876543210' : (f.def.isNotEmpty && (f.type == 'readonly') ? f.def : ''));
          }
        }
        String outcome;
        try {
          final before = S.snapshotText();
          final told = debugToasts.length;
          form.onSave(v, navKey.currentContext!);
          await tester.pump(const Duration(milliseconds: 120));
          final msgs = debugToasts.skip(told).join(' / ');
          outcome = S.snapshotText() != before ? 'SAVED a record' : 'not saved - message: $msgs';
        } catch (e) {
          outcome = 'THREW: ${e.toString().split('\n').first}';
          bad.add('${form.title}: $outcome');
        }
        report.add('${form.title} -> $outcome');
        tester.takeException();
        closeAll();
        await tester.pump(const Duration(milliseconds: 250));
        tester.takeException();
      }
    }
    for (final r in report) { print('SAVE $r'); }
    print('SAVEPROBLEMS ${bad.length}: ${bad.join(' | ')}');
    expect(bad, isEmpty);
  });
}
