import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/ui/overlays.dart';

void main() {
  testWidgets('the confirmation message sits in the bottom-right corner and goes away by itself', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ImpacgoChainApp());
    await tester.pump(const Duration(milliseconds: 400));
    toast('Lead LEAD-0104 created');
    await tester.pump(const Duration(milliseconds: 600));
    final box = find.byType(SnackBar);
    expect(box, findsOneWidget);
    final card = find.descendant(of: box, matching: find.byType(Material)).first;
    final right = tester.getBottomRight(card);
    final left = tester.getTopLeft(card);
    print('TOAST left=${left.dx.round()} right=${right.dx.round()} bottom=${right.dy.round()} of 1600x1000');
    expect(right.dx, greaterThan(1560), reason: 'right edge near the right side of the screen');
    expect(left.dx, greaterThan(1100), reason: 'not centred: starts in the right part of the screen');
    expect(right.dy, greaterThan(940), reason: 'at the bottom');
    // gone after a few seconds
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.byType(SnackBar), findsNothing);
    print('TOAST disappeared by itself');
  });
}
