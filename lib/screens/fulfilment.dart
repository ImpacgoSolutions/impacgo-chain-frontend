import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/auth.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'logistics.dart' show deliveryTrackingTable;

/// One stage of a delivery and the form used at that stage.
class FulfilStage {
  final String id, title, icon, doc, form, does, after;
  final List<String> mandatory, auto;
  final int Function() waiting;
  final String waitingLabel;
  const FulfilStage({
    required this.id,
    required this.title,
    required this.icon,
    required this.doc,
    required this.form,
    required this.does,
    required this.mandatory,
    required this.auto,
    required this.after,
    required this.waiting,
    required this.waitingLabel,
  });
}

int _count(String t, bool Function(String s) f) => S.docsOf(t).where((d) => f(d.status)).length;

/// Picking → Packing → Dispatch → Delivery tracking, in the order the work happens.
final fulfilStages = <FulfilStage>[
  FulfilStage(
    id: 'picking',
    title: 'Picking',
    icon: 'package',
    doc: 'PK',
    form: 'Confirm picking',
    does: 'Created when a sales order is released to the warehouse. The picker collects the goods from the suggested bins (earliest-expiry batch first).',
    mandatory: ['Picker', 'Picked Qty (each line)', 'Batch No. / Serial Nos. (batch- or serial-tracked items only)'],
    auto: ['Pick No.', 'SO Ref.', 'Warehouse', 'Item, ordered qty and bin'],
    after: 'Becomes Picked and the packing task is created.',
    waiting: () => _count('PK', (s) => s == 'To Pick'),
    waitingLabel: 'to pick',
  ),
  FulfilStage(
    id: 'packing',
    title: 'Packing',
    icon: 'package',
    doc: 'PCK',
    form: 'Confirm packing',
    does: 'Pack the picked goods and record how many cartons and how heavy the consignment is.',
    mandatory: ['No. of Cartons', 'Gross Weight (kg)', 'Packed By'],
    auto: ['Pack No.', 'Pick Ref.', 'Pack Date (today, can be changed)'],
    after: 'Becomes Packed and the delivery note is created, ready to dispatch.',
    waiting: () => _count('PCK', (s) => s == 'Packing'),
    waitingLabel: 'to pack',
  ),
  FulfilStage(
    id: 'deliveries',
    title: 'Dispatch',
    icon: 'truck',
    doc: 'DN',
    form: 'Dispatch',
    does: 'The delivery note travels with the goods. Choose the vehicle and driver and send the consignment.',
    mandatory: ['Dispatch Date', 'Vehicle', 'Driver', 'E-way Bill No. (only when the value is above ₹50,000)'],
    auto: ['Delivery No.', 'SO Ref.', 'Customer'],
    after: 'Becomes Dispatched: stock is reduced, the tax invoice is created and delivery tracking starts.',
    waiting: () => _count('DN', (s) => s == 'Ready to Dispatch'),
    waitingLabel: 'to dispatch',
  ),
  FulfilStage(
    id: 'dtracking',
    title: 'Delivery Tracking',
    icon: 'map',
    doc: 'SHP',
    form: 'Update delivery status',
    does: 'Follow the consignment until the customer receives it.',
    mandatory: ['Status (In Transit / Out for Delivery / Delivered)', 'Delivered Date and Received By (when Delivered)'],
    auto: ['Delivery No.', 'Customer', 'Carrier / vehicle and expected delivery date'],
    after: 'On Delivered the shipment is closed and the delivery note becomes Delivered.',
    waiting: () => _count('SHP', (s) => s != 'Delivered'),
    waitingLabel: 'on the way',
  ),
];

/// Deliveries: the four warehouse stages after a sales order, on one screen.
/// The stage cards switch the list below; each stage says which form it uses and
/// which fields are mandatory.
class FulfilmentView extends StatefulWidget {
  const FulfilmentView({super.key});
  /// Selected stage, kept while moving around the app.
  static int stage = 0;
  @override
  State<FulfilmentView> createState() => _FulfilmentViewState();
}

class _FulfilmentViewState extends State<FulfilmentView> {
  int get i => FulfilmentView.stage;

  Widget _stageCard(int n, bool compact) {
    final st = fulfilStages[n];
    final sel = n == i;
    final w = st.waiting();
    return Material(
      color: sel ? C.blue50 : C.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => FulfilmentView.stage = n),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? C.blue600 : C.border, width: sel ? 1.6 : 1)),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: sel ? C.blue600 : C.bg, shape: BoxShape.circle),
              child: Text('${n + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: sel ? Colors.white : C.soft)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sel ? C.blue600 : C.text)),
                const SizedBox(height: 2),
                Text(w == 0 ? 'Nothing waiting' : '$w ${st.waitingLabel}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: w == 0 ? C.faint : C.amber, fontWeight: w == 0 ? FontWeight.w400 : FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _list(FulfilStage st) {
    if (st.doc == 'SHP') return deliveryTrackingTable();
    return docTable('t${st.doc}', st.doc, S.docsOf(st.doc));
  }

  @override
  Widget build(BuildContext context) {
    // each role sees only the stages it works on (the manager sees all four)
    final shown = [for (var n = 0; n < fulfilStages.length; n++) if (S.canView(fulfilStages[n].id)) n];
    if (shown.isEmpty) return const Empty('No delivery stages for your role');
    if (!shown.contains(i)) FulfilmentView.stage = shown.first;
    final st = fulfilStages[i];
    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth >= 900;
      final cols = wide ? shown.length : (c.maxWidth >= 420 ? 2 : 1);
      final cardW = (c.maxWidth - (cols - 1) * 10) / cols;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader('Deliveries', sub: 'After the sales order: pick → pack → dispatch → track the delivery'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final n in shown) SizedBox(width: cardW, child: _stageCard(n, !wide)),
        ]),
        const SizedBox(height: 14),
        // keyed by stage so each list keeps its own search, filters and page
        KeyedSubtree(key: ValueKey('fulfil-${st.id}'), child: _list(st)),
      ]);
    });
  }
}
