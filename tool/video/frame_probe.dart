import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/main.dart';

final _boundary = GlobalKey();

/// Test mode draws every letter as a block unless the real fonts are loaded.
Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      l.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await l.load();
  }
  final lato = [for (final w in ['400', '500', '600', '700', '800']) 'assets/fonts/Lato-$w.ttf'];
  await family('Lato', lato);
  await family('Roboto', lato);
  await family('MaterialIcons', ['C:/Users/saisu/Downloads/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

void main() {
  testWidgets('can the test draw the real screens?', (tester) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: _boundary, child: const ImpacgoChainApp()));
    await tester.pump(const Duration(milliseconds: 600));
    S.go('preqs');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('New request'));
    await tester.pump(const Duration(milliseconds: 700));
    final texts = tester.widgetList<RichText>(find.byType(RichText)).map((e) => e.text.toPlainText()).where((x) => x.trim().isNotEmpty).toList();
    print('PRFORM texts: ${texts.join(' | ')}');
    final fields = find.byType(TextField);
    for (var i = 0; i < fields.evaluate().length; i++) {
      final w = tester.widget<TextField>(fields.at(i));
      print('PRFORM field#$i hint="${w.decoration?.hintText}" text="${w.controller?.text}" enabled=${w.enabled} kb=${w.keyboardType}');
    }
    await tester.runAsync(() async {
      final b = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/video/frames/probe_prform.png').writeAsBytesSync(data!.buffer.asUint8List());
      print('PROBE ${img.width}x${img.height}');
    });
  });
}
