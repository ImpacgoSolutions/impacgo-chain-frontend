import 'package:flutter/material.dart';
import 'app_state.dart';
import 'core/store.dart';
import 'screens/settings.dart';
import 'ui/overlays.dart';
import 'ui/perf_hud.dart';
import 'ui/shell.dart';
import 'ui/tokens.dart';

void main() {
  registerTableHooks();
  // ?fresh=1 in the address: start with no demo data at all (no transactions, no demo items / customers / suppliers)
  if (Uri.base.queryParameters['fresh'] == '1') AppStore.freshStart = true;
  // There is no backend: every start (restart or reload) begins from the standard data.
  // Anything an earlier version saved in this browser is removed.
  S.forgetSaved();
  runApp(const ImpacgoChainApp());
}

class ImpacgoChainApp extends StatelessWidget {
  const ImpacgoChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMPACGO Chain — Supply Chain Management',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      scaffoldMessengerKey: messengerKey,
      theme: buildTheme(),
      // Keep text at exactly the prototype's pixel sizes (ignore OS text scaling on desktop web).
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.noScaling),
        child: PerfHud(child: child!),
      ),
      home: const AppShell(),
    );
  }
}
