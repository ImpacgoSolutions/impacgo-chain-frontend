// Drives the REAL screens (taps, typing, dropdowns) through the whole Buy flow and saves a picture of every step.
// Run:  flutter test tool/video/buy_flow_frames.dart      then:  python tool/video/make_video.py
// It doubles as an end-to-end check: if any step cannot be done on screen, the run fails.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/ui/overlays.dart';
import 'package:impacgo_chain/ui/table.dart';

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

class Rec {
  Rec(this.t);
  final WidgetTester t;
  final List<Map<String, dynamic>> frames = [];
  int n = 0;
  String step = '';

  Future<void> settle([int ms = 450]) async {
    await t.pump(Duration(milliseconds: ms));
    await t.pump(const Duration(milliseconds: 60));
  }

  /// Saves a picture of the screen as it is now. [point] = where the mouse is, [box] = the part being explained.
  Future<void> shot(String caption, {Finder? point, Finder? box, double hold = 3.0, String? title}) async {
    await t.pump(const Duration(milliseconds: 80));
    n++;
    final name = 'f${n.toString().padLeft(3, '0')}.png';
    await t.runAsync(() async {
      final b = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/video/frames/$name').writeAsBytesSync(data!.buffer.asUint8List());
    });
    Offset? p;
    Rect? r;
    try { if (point != null) p = t.getCenter(point.first); } catch (_) {}
    try { if (box != null) r = t.getRect(box.first); } catch (_) {}
    frames.add({
      'file': name,
      'step': step,
      'caption': caption,
      'hold': hold,
      if (title != null) 'title': title,
      if (p != null) 'pointer': [p.dx, p.dy],
      if (r != null) 'box': [r.left, r.top, r.right, r.bottom],
    });
  }

  /// Shows the mouse on [f], then clicks it.
  Future<void> tap(Finder f, String caption, {Finder? box, double hold = 2.0, bool after = false, String? afterCaption, double afterHold = 2.5}) async {
    expect(f, findsWidgets, reason: 'cannot find what to click for: $caption');
    await t.ensureVisible(f.first);
    await t.pump(const Duration(milliseconds: 80));
    await shot(caption, point: f, box: box, hold: hold);
    await t.tap(f.first, warnIfMissed: false);
    await settle();
    if (after) await shot(afterCaption ?? caption, hold: afterHold);
  }

  /// Types [text] in a field and shows the result.
  Future<void> type(Finder f, String text, String caption, {double hold = 3.0}) async {
    expect(f, findsWidgets, reason: 'cannot find the field for: $caption');
    await t.ensureVisible(f.first);
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(f.first, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 200));
    await t.enterText(f.first, text);
    await settle(250);
    await shot(caption, box: f, hold: hold);
  }

  Future<void> scroll(double dy) async {
    final s = find.byType(Scrollable);
    // the form page's own scroll view is the last one on screen
    await t.drag(s.last, Offset(0, -dy), warnIfMissed: false);
    await settle(350);
  }

  Future<void> save() async {
    File('build/video/frames.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(frames));
  }
}

void main() {
  testWidgets('record the Buy flow on the real screens', (tester) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = Directory('build/video/frames');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    await tester.pumpWidget(RepaintBoundary(key: _boundary, child: const ImpacgoChainApp()));
    await tester.pump(const Duration(milliseconds: 700));
    final r = Rec(tester);

    // ---------------------------------------------------------------- 0. start
    r.step = 'Start';
    await r.shot('This is the SCM Workspace — the home screen. The Buy section is in the sidebar on the left.', box: find.text('BUY'), hold: 3.5);

    // ---------------------------------------------------------------- 1. open Purchase Requests
    r.step = '1 · Purchase Request';
    await r.tap(find.text('Purchase Requests').first, 'Open Buy › Purchase Requests.', hold: 2.0, after: true, afterCaption: 'The list is empty. The four cards count requests by status. Click “New request” to create one.', afterHold: 3.5);
    await r.tap(find.text('New request'), 'Click “New request”.', hold: 2.0);
    await r.settle(700);
    await r.shot('The New Purchase Request form opens. Fields with a red * are mandatory. Status starts as Draft.', box: find.text('Draft').first, hold: 3.5);

    // ---- what happens when mandatory fields are left empty
    await r.tap(find.text('Create Purchase Request'), 'First, what if mandatory fields are empty? Click “Create Purchase Request” with nothing filled in.', hold: 2.5);
    await r.settle(500);
    await r.shot('The request is refused: a message in the bottom-right corner lists what is missing, and nothing is saved.', hold: 4.0);
    await tester.pump(const Duration(seconds: 4));

    // ---- walk through every field
    await r.shot('Now fill it in. Purchase Request No. is created automatically — you never type it.', box: find.text('PR-2026-0001'), hold: 3.5);
    await r.shot('Request Date * is today’s date, set by the system.', box: find.byType(TextField).at(0), hold: 3.0);

    await r.tap(find.text('Select supplier'), 'Supplier (optional): a request may not know its supplier yet. Click to choose one.', hold: 2.0);
    await r.shot('The supplier list (searchable). Pick the preferred supplier.', hold: 3.0);
    await r.tap(find.text('SafeGuard Industrial Supplies').last, 'Choose “SafeGuard Industrial Supplies”.', hold: 1.8);
    await r.shot('Supplier chosen. (It can also be left empty.)', box: find.text('SafeGuard Industrial Supplies').first, hold: 2.5);

    await r.shot('Deliver To Warehouse * is the warehouse you are working in (top bar). Currency * is INR.', box: find.text('VZG-DC — Visakhapatnam').last, hold: 3.5);
    await r.shot('Requested By * is the signed-in person (name and role).', box: find.text('Srinivas Rao — SCM Manager'), hold: 3.0);

    await r.tap(find.text('Select department'), 'Department * — who needs the goods. Click to choose.', hold: 2.0);
    await r.shot('Choose the department.', hold: 2.5);
    await r.tap(find.text('Stores').last, 'Choose “Stores”.', hold: 1.8);

    await r.shot('Required By Date * defaults to 7 days from today. Click the box to pick another date if needed.', box: find.byType(TextField).at(1), hold: 3.5);

    await r.scroll(260);
    await r.shot('Line Items: what is being requested. Click “Select item” to search the item list.', box: find.text('Select item'), hold: 3.0);
    await r.tap(find.text('Select item'), 'Click “Select item”.', hold: 1.8);
    await r.settle(500);
    await r.shot('The item picker lists every item with its stock. You can search by name, code, category or HSN.', hold: 3.0);
    await tester.enterText(find.byType(TextField).last, 'helmet');
    await r.settle(400);
    await r.shot('Typing “helmet” narrows the list.', hold: 3.0);
    await r.tap(find.text('Industrial Safety Helmet').last, 'Choose “Industrial Safety Helmet”.', hold: 1.8);
    await r.settle(600);
    await r.shot('Description, HSN / SAC code, UOM, Rate and Tax Code fill in from the item. Only the quantity is left to type.', hold: 4.0);

    await r.type(find.byType(TextField).at(4), '100', 'Qty: type the quantity needed — 100. The Line Total, Subtotal, GST and Grand Total update at once.', hold: 4.0);

    await r.scroll(500);
    await r.shot('Business Justification * — explain why the purchase is needed.', box: find.text('Why is this purchase needed?'), hold: 2.5);
    await r.type(find.byType(TextField).last, 'Safety helmets for the new warehouse crew starting next week.', 'Justification typed.', hold: 3.5);

    await r.tap(find.text('Create Purchase Request'), 'Everything mandatory is filled. Click “Create Purchase Request”.', hold: 2.5);
    await r.settle(800);
    await r.shot('PR-2026-0001 is created as a Draft. It is a draft until it is submitted for approval.', hold: 4.0);
    await tester.pump(const Duration(seconds: 3));

    // ---------------------------------------------------------------- 2. submit + approve
    r.step = '2 · Approval';
    await r.tap(find.text('PR-2026-0001').first, 'Click the request in the list to open its record page.', hold: 2.0);
    await r.settle(700);
    await r.shot('The record page shows the request, its status and — at the top — the next step. A Draft can be edited or submitted.', box: find.text('Submit for approval'), hold: 4.0);
    await r.tap(find.text('Submit for approval').first, 'Click “Submit for approval”.', hold: 2.0, after: true, afterCaption: 'Status is now Pending Approval. The manager must approve it.', afterHold: 3.5);
    await r.shot('Only a manager can approve. Here the signed-in user is the SCM Manager, so “Approve request” (and Reject) are shown.', box: find.text('Approve request'), hold: 4.0);
    await r.tap(find.text('Approve request').first, 'Click “Approve request”.', hold: 2.0, after: true, afterCaption: 'Approved. The next step is to turn it into a purchase order.', afterHold: 3.5);

    // ---------------------------------------------------------------- 3. purchase order
    r.step = '3 · Purchase Order';
    await r.tap(find.text('Convert to purchase order').first, 'Click “Convert to purchase order”.', hold: 2.0);
    await r.settle(800);
    await r.shot('A purchase order form opens already filled from the approved request (supplier, items, quantity, rates).', hold: 4.0);
    await r.shot('PO No. is automatic, “Against Request” links back to the PR. PO Date, Warehouse, Currency and Branch are set for you.', box: find.text('Against Request'), hold: 4.0);
    await r.shot('Expected Delivery Date, Payment Terms and Billing Address come from the supplier. Change any of them if needed.', box: find.text('Payment Terms').first, hold: 4.0);
    await r.scroll(700);
    await r.shot('Line items and totals are copied from the request. Rates can be negotiated here.', hold: 4.0);
    await r.tap(find.text('Create purchase order').last, 'Click “Create purchase order”.', hold: 2.0);
    await r.settle(900);
    await r.shot('The PO is created and sent to the supplier (Sent to Supplier). The PR becomes “Ordered”.', hold: 4.0);
    await tester.pump(const Duration(seconds: 3));

    // ---------------------------------------------------------------- 4. goods receipt
    r.step = '4 · Goods Receipt';
    await r.tap(find.text('PO-2026-0001').first, 'Open the purchase order from the list.', hold: 2.0);
    await r.settle(700);
    await r.shot('When the supplier’s truck arrives, the next step is “Goods received”.', box: find.text('Goods received').first, hold: 3.5);
    await r.tap(find.text('Goods received').first, 'Click “Goods received”.', hold: 2.0);
    await r.settle(800);
    await r.shot('The Goods Receipt form: GRN No. is automatic, GRN Date is today, and the PO and supplier details are shown.', hold: 4.0);
    await r.scroll(450);
    await r.shot('Receiving Warehouse and Received By are chosen here. Vehicle No. is optional.', hold: 3.5);
    await r.type(find.widgetWithText(TextField, 'e.g. AP 31 TX 4410'), 'AP 31 TX 4410', 'Vehicle No. (optional): the truck that delivered the goods.', hold: 3.0);
    await r.scroll(450);
    await r.shot('Line items: Ordered 100, Already received 0, Received qty starts at what is still open. Change it if the delivery is short.', hold: 4.5);
    await r.scroll(500);
    await r.type(find.byType(TextField).last, '2 cartons slightly damaged on arrival', 'Remarks (optional).', hold: 3.0);
    await r.tap(find.text('Create goods receipt'), 'Click “Create goods receipt”.', hold: 2.0);
    await r.settle(900);
    await r.shot('GRN-2026-0001 is created with status QC Pending. The goods wait in the receiving area until quality check.', hold: 4.0);
    await tester.pump(const Duration(seconds: 3));
    await r.tap(find.byType(ProtoCheck).at(1), 'Tick the goods receipt, then click “Raise QC” to send it to the QC team.', hold: 2.5);
    await r.tap(find.textContaining('Raise QC').first, 'Click “Raise QC”.', hold: 2.0, after: true, afterCaption: 'Status is now QC Requested: with the QC team.', afterHold: 3.5);
    await tester.pump(const Duration(seconds: 3));

    // ---------------------------------------------------------------- 5. quality check
    r.step = '5 · Quality Check';
    await r.tap(find.text('Quality Check').first, 'The QC team opens Buy › Quality Check.', hold: 2.0);
    await r.settle(600);
    await r.shot('GRN-2026-0001 is waiting for inspection.', hold: 3.0);
    await r.tap(find.byType(ProtoCheck).at(1), 'Tick the goods receipt that was inspected.', hold: 2.0);
    await r.tap(find.textContaining('Record QC result').first, 'Click “Record QC result”.', hold: 2.0);
    await r.settle(800);
    await r.shot('The QC form: QC Inspector and QC Status are chosen, then the Accepted quantity is entered. Whatever is not accepted is rejected.', hold: 5.0);
    final acc = find.widgetWithText(TextField, '100');
    await r.type(acc, '90', 'Accepted Qty: 90 of the 100 received are good, so 10 are rejected.', hold: 3.5);
    await r.type(find.widgetWithText(TextField, 'Mandatory if any quantity is rejected'), '10 helmets cracked on delivery', 'Rejection Reason is mandatory when any unit is rejected.', hold: 3.5);
    await r.tap(find.text('Post QC result').last, 'Click “Post QC result”.', hold: 2.0);
    await r.settle(900);
    await r.shot('QC result posted. Accepted stock is now available; the 10 rejected units create a purchase return automatically.', hold: 4.5);
    await tester.pump(const Duration(seconds: 3));

    await r.shot('The GRN now shows QC Checked, the QC report ready to download, and the 10 rejected units with their reason.', hold: 4.5);
    await tester.ensureVisible(find.text('Rejection Reason'));
    await r.settle(300);
    await r.shot('Quality Check section: inspector, date, result and the rejection reason are recorded on the receipt.', box: find.text('Rejection Reason'), hold: 4.0);
    await r.shot('“Download QC report” at the bottom gives the QC report as a PDF.', box: find.text('Download QC report'), hold: 3.5);
    Navigator.of(tester.element(find.text('Download QC report'))).pop();
    await r.settle(500);

    // ---------------------------------------------------------------- 6. bin allocation
    r.step = '6 · Bin Allocation';
    await r.tap(find.text('Bin Allocation').first, 'Open Buy › Bin Allocation. The 90 accepted helmets must be put into storage bins.', hold: 2.0);
    await r.settle(600);
    await r.shot('A put-away task PA-2026-0001 was created automatically for the accepted goods only.', hold: 3.5);
    await r.tap(find.text('PA-2026-0001').first, 'Click the task to open it.', hold: 2.0);
    await r.settle(800);
    await r.shot('For every item choose the storage Bin. A suggested bin is already selected.', hold: 4.0);
    await r.tap(find.text('Confirm bin allocation').last, 'Click “Confirm bin allocation”.', hold: 2.0);
    await r.settle(900);
    await r.shot('Bins confirmed. The goods receipt opens with status “Bin Allocated”: the 90 accepted helmets are stored.', hold: 4.0);
    await tester.ensureVisible(find.text('Storage Bins'));
    await r.settle(300);
    await r.shot('Storage Bins: the bin each item was put into.', box: find.text('Storage Bins'), hold: 3.5);
    Navigator.of(tester.element(find.text('Download QC report'))).pop();
    await r.settle(500);

    // ---------------------------------------------------------------- 7. purchase invoice
    r.step = '7 · Purchase Invoice';
    await r.tap(find.text('Purchase Invoices').first, 'Open Buy › Purchase Invoices — the supplier’s bill for the goods.', hold: 2.0);
    await r.settle(600);
    await r.tap(find.text('Generate invoice').first, 'Click “Generate invoice”.', hold: 2.0);
    await r.settle(700);
    await r.shot('Choose the purchase order the supplier sent goods for.', hold: 3.0);
    await r.tap(find.text('Continue').last, 'Click “Continue”.', hold: 2.0);
    await r.settle(800);
    await r.shot('The invoice form: supplier invoice number and date, then quantity and rate per line (from the PO, editable).', hold: 5.0);
    await r.tap(find.text('Generate invoice').last, 'Click “Generate invoice”.', hold: 2.0);
    await r.settle(900);
    await r.shot('The system checks the invoice against the PO and the goods receipt by itself (3-way match). No manual verify step.', hold: 5.0);
    await tester.pump(const Duration(seconds: 3));

    await tester.ensureVisible(find.text('3-way match'));
    await r.settle(300);
    await r.shot('3-way match: Purchase Order, Goods Receipt and Supplier Invoice side by side. Every line says “Matches”, so the invoice is Approved by the system and goes to Finance for payment.', box: find.text('3-way match'), hold: 6.0);
    Navigator.of(tester.element(find.text('3-way match'))).popUntil((r) => r.isFirst);
    await r.settle(500);

    // ---------------------------------------------------------------- 8. purchase return
    r.step = '8 · Purchase Return';
    await r.shot('Back in Buy › Purchase Invoices: PI-2026-0001 is Verified and Approved for payment. Finance pays it from here.', hold: 5.0);
    await tester.drag(find.text('Purchase Invoices').first, const Offset(0, 400), warnIfMissed: false);
    await r.settle(400);
    await r.tap(find.text('Purchase Returns').first, 'Open Buy › Purchase Returns. The 10 rejected helmets are returned to the supplier.', hold: 2.0);
    await r.settle(700);
    await r.shot('The return was created automatically when QC rejected the units, and is already Approved (it was the QC team’s decision). Only rejected units can be returned.', hold: 5.5);
    await r.tap(find.textContaining('PRT-').first, 'Open the return.', hold: 2.0);
    await r.settle(800);
    await r.shot('The return shows the GRN, PO, supplier and the reason copied from QC (10 helmets cracked on delivery).', hold: 4.5);
    await r.tap(find.text('Dispatch items').first, 'Click “Dispatch items” when the goods go back to the supplier.', hold: 2.0);
    await r.settle(900);
    await r.shot('Status is now Returned and a debit note is raised once, for the rejected value. Stock is not reduced again (the rejects were never stocked).', hold: 5.5);
    await tester.pump(const Duration(seconds: 3));

    await r.save();
    print('FRAMES ${r.frames.length}');
    return;

    await r.save();
    print('FRAMES ${r.frames.length}');
  });
}
