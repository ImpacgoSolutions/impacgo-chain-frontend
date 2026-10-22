import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/auth.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/screens/registry.dart';
import 'package:impacgo_chain/ui/overlays.dart';
import 'package:impacgo_chain/ui/shell.dart';
import 'package:impacgo_chain/ui/table.dart';
import 'package:impacgo_chain/ui/widgets.dart';

/// Signs in as every role and opens each screen it can see, the first records of every list and every create form
/// (pressing its main button), at laptop and phone width; any crash or layout overflow fails the test.
void main() {
  AppStore.singleDemo = true;
  final ids = <String>[];
  for (final g in nav) {
    for (final it in g.items) {
      if (it.id.isNotEmpty) ids.add(it.id);
      for (final s in it.category?.items ?? const <NavItem>[]) {
        if (s.id.isNotEmpty) ids.add(s.id);
      }
    }
  }
  for (final h in hubs.values) {
    for (final t in h) {
      if (!ids.contains(t.$2)) ids.add(t.$2);
    }
  }

  for (final (role, w) in [('admin@impacgo.com', 1440.0), ('admin@impacgo.com', 390.0), ('executive@impacgo.com', 1440.0), ('store@impacgo.com', 1440.0), ('delivery@impacgo.com', 1440.0), ('supplier@andhracorrugators.com', 1440.0), ('supplier@andhracorrugators.com', 390.0)]) {
    testWidgets('crawl $role at $w px', (t) async {
      final u = demoUsers.firstWhere((x) => x.email == role);
      S.login(u.email, u.password);
      t.view.physicalSize = Size(w, 1100);
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(const ImpacgoChainApp());
      await t.pumpAndSettle();
      final errs = <String>{};
      var where = 'start';
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        final first = d.exceptionAsString().split('\n').first;
        final loc = (d.toString().split('\n').firstWhere((l) => l.contains('lib/') && l.contains('.dart:'), orElse: () => '')).trim();
        errs.add('$where :: $first ${loc.isEmpty ? '' : '@ ${loc.replaceAll(RegExp(r'^.*?lib/'), 'lib/')}'}');
      };
      Future<void> settle() async {
        try {
          await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 6));
        } catch (e) {
          errs.add('$where :: did not settle ($e)'.split('\n').first);
        }
      }

      var screens = 0, records = 0, forms = 0, saves = 0;
      for (final id in ids.where(S.canView)) {
        where = '$role $id';
        closeAll();
        await settle();
        S.go(S.isSupplier ? 'sp_po' : 'workspace');
        await settle();
        S.go(id);
        await settle();
        screens++;
        final cards = find.byType(DataTableCard).evaluate().map((e) => e.widget as DataTableCard).toList();
        for (final c in cards) {
          // open the first records of the list
          if (c.onRow != null) {
            for (final r in c.rows.take(2)) {
              where = '$id › open record';
              try {
                c.onRow!(r);
              } catch (e) {
                errs.add('$where :: $e'.split('\n').first);
              }
              await settle();
              records++;
              closeAll();
              await settle();
            }
          }
          // open the create form and press its main button with the defaults
          if (c.onCreate != null) {
            where = '$id › ${c.createLabel}';
            try {
              c.onCreate!();
            } catch (e) {
              errs.add('$where :: $e'.split('\n').first);
            }
            await settle();
            forms++;
            final btns = find.byType(Btn).evaluate().map((e) => e.widget as Btn).where((b) => b.onTap != null && b.kind == BtnKind.primary).toList();
            if (btns.isNotEmpty) {
              where = '$id › ${c.createLabel} › ${btns.last.label}';
              try {
                btns.last.onTap!();
                saves++;
              } catch (e) {
                errs.add('$where :: $e'.split('\n').first);
              }
              await settle();
              await t.pump(const Duration(seconds: 5));
            }
            closeAll();
            await settle();
          }
        }
      }
      FlutterError.onError = old;
      // ignore: avoid_print
      print('CRAWL $role $w: $screens screens, $records records opened, $forms create forms, $saves saves pressed, ${errs.length} problem(s)');
      for (final e in errs) {
        // ignore: avoid_print
        print('PROBLEM $role $w | $e');
      }
      expect(errs, isEmpty, reason: 'every screen, record and form of this role opens cleanly');
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
