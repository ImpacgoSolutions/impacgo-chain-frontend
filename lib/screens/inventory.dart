import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/overlays.dart';
import '../ui/table.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'edit_forms.dart';
import 'remove.dart';

class StockRow {
  final Item p;
  final Warehouse w;
  final StockCell s;
  StockRow(this.p, this.w, this.s);
  String get health => s.avail < p.reorder
      ? 'Below reorder'
      : (s.avail < p.reorder * 1.5 ? 'Low' : 'OK');
  double get value => s.onhand * p.cost;
}

Widget onHandView() {
  final rows = <StockRow>[];
  for (final p in S.items) {
    for (final w in S.warehouses) {
      rows.add(StockRow(p, w, S.stk(w.id, p.id)));
    }
  }
  final reserved = rows.fold<int>(0, (a, r) => a + r.s.reserved);
  final transit = rows.fold<int>(0, (a, r) => a + r.s.transit);
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    PageHeader('Stock Overview',
        sub:
            'Available = on hand − reserved · calculated from the stock ledger, never typed in',
        actions: [
          Btn.secondary('Stock ledger',
              icon: 'history', onTap: () => S.go('ledger')),
        ]),
    StatRow([
      Stat('Stock value at ${S.currentWh.code}',
          fmtINR(S.stockValue(S.currentWh.id)), 'At cost', 'box', Tone.blue),
      Stat('Reserved for orders', '${fmtNum(reserved)} units', 'All warehouses',
          'lock', Tone.purple),
      Stat('In transit (transfers)', '${fmtNum(transit)} units',
          'Between sites', 'truck', Tone.cyan),
      Stat('Below reorder level', '${S.belowReorder()}', 'Raise PR', 'alert',
          Tone.red,
          up: false),
    ], max: 4, compact: true),
    DataTableCard(
      id: 'soh',
      rows: rows,
      pageSize: 10,
      exportName: 'stock-on-hand',
      initialFilters: {0: S.currentWh.code},
      onRow: (r) => openItemPanel((r as StockRow).p.id),
      // an item that is low or below its reorder level gets a one-tap "Request purchase" (a Purchase Request form for its supplier)
      rowActions: (r) => (r as StockRow).health == 'OK'
          ? const SizedBox.shrink()
          : IconBtn('bag', () => openDocForm('PR', party: r.p.sup),
              size: 30, tip: 'Request purchase'),
      search: (r) => '${(r as StockRow).p.id} ${r.p.name} ${r.p.cat}',
      filters: [
        Filt('Warehouse', S.warehouses.map((w) => w.code).toList(),
            (r) => (r as StockRow).w.code),
        Filt('Category', S.categories, (r) => (r as StockRow).p.cat),
        Filt('Health', const ['OK', 'Low', 'Below reorder'],
            (r) => (r as StockRow).health),
      ],
      cols: [
        Col('Item',
            (r) => CellTwo((r as StockRow).p.name, '${r.p.id} · ${r.p.cat}'),
            sort: (r) => (r as StockRow).p.name,
            text: (r) => (r as StockRow).p.name),
        Col('Warehouse', (r) => chipWh((r as StockRow).w.id),
            text: (r) => (r as StockRow).w.code),
        Col('On Hand',
            (r) => Text('${fmtNum((r as StockRow).s.onhand)} ${r.p.uom}'),
            num: true,
            sort: (r) => (r as StockRow).s.onhand,
            text: (r) => '${(r as StockRow).s.onhand}'),
        Col.t('Reserved', (r) => '${(r as StockRow).s.reserved}', num: true),
        Col('Available',
            (r) => Text(fmtNum((r as StockRow).s.avail), style: tsB),
            num: true,
            sort: (r) => (r as StockRow).s.avail,
            text: (r) => '${(r as StockRow).s.avail}'),
        Col.t('In Transit', (r) => '${(r as StockRow).s.transit}', num: true),
        Col.t('Reorder Lvl', (r) => '${(r as StockRow).p.reorder}', num: true),
        Col('Value', (r) => Text(fmtINR((r as StockRow).value)),
            num: true,
            sort: (r) => (r as StockRow).value,
            text: (r) => (r as StockRow).value.toStringAsFixed(0)),
        Col('Status', (r) => StatusBadge((r as StockRow).health),
            text: (r) => (r as StockRow).health, status: true),
      ],
    ),
  ]);
}

Widget ledgerView() =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Stock Ledger',
          sub:
              'Every stock movement with its source document · the only way stock changes'),
      DataTableCard(
        id: 'led',
        rows: S.ledger,
        pageSize: 10,
        exportName: 'stock-ledger',
        onRow: (r) => openDocNav((r as LedgerEntry).ref),
        search: (r) => '${(r as LedgerEntry).item} ${r.ref} ${r.type}',
        filters: [
          Filt('Warehouse', S.warehouses.map((w) => w.code).toList(),
              (r) => S.wh((r as LedgerEntry).wh).code),
          Filt(
              'Movement',
              const [
                'Sales issue',
                'Purchase receipt',
                'Transfer out',
                'Transfer in',
                'Sales return',
                'Purchase return',
                'Adjustment (damage)',
                'Adjustment (count difference)'
              ],
              (r) => (r as LedgerEntry).type),
        ],
        cols: [
          Col('Date', (r) => Text('${(r as LedgerEntry).date}  ${r.time}'),
              sort: (r) => (r as LedgerEntry).date,
              text: (r) => (r as LedgerEntry).date),
          Col('Item',
              (r) => CellTwo(S.item((r as LedgerEntry).item).name, r.item),
              text: (r) => (r as LedgerEntry).item),
          Col('Warehouse', (r) => chipWh((r as LedgerEntry).wh),
              text: (r) => (r as LedgerEntry).wh),
          Col('Movement', (r) => Tag((r as LedgerEntry).type),
              text: (r) => (r as LedgerEntry).type),
          Col(
              'Qty',
              (r) => Text(
                  '${(r as LedgerEntry).qty > 0 ? '+' : ''}${fmtNum(r.qty)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: r.qty < 0 ? C.red : C.green)),
              num: true,
              sort: (r) => (r as LedgerEntry).qty,
              text: (r) => '${(r as LedgerEntry).qty}'),
          Col.t('Balance', (r) => '${(r as LedgerEntry).bal}', num: true),
          Col('Document', (r) => Tag((r as LedgerEntry).ref),
              text: (r) => (r as LedgerEntry).ref),
          Col.t('By', (r) => (r as LedgerEntry).who),
        ],
      ),
    ]);

void newBatchForm() {
  mform('New batch', [
    const F.header('Batch'),
    const F('batch_no', 'Batch No.',
        req: true, hint: 'From the supplier’s label, e.g. B2609-0142'),
    F('item', 'Item',
        type: 'select',
        req: true,
        options: S.items
            .where((p) => p.track == 'Batch')
            .map((p) => Opt(p.id, '${p.name} (${p.id})'))
            .toList()),
    F('wh', 'Warehouse',
        type: 'select',
        req: true,
        def: S.currentWh.id,
        options: S.warehouses
            .map((w) => Opt(w.id, '${w.code} — ${w.city}'))
            .toList()),
    const F('qty', 'Quantity', type: 'number', def: '100', req: true),
    F('exp', 'Expiry Date',
        type: 'date', def: addDays(todayStr(), 180), req: true),
    F('mfg', 'Manufacture Date', type: 'date', def: todayStr(), show: true),
    F('sup', 'Supplier', type: 'select', req: true, options: [
      const Opt('', 'Select supplier'),
      ...S.suppliers
          .where((s) => s.status != 'Inactive')
          .map((s) => Opt(s.id, s.name))
    ]),
    F('status', 'Status',
        type: 'select',
        show: true,
        options: opts(['Released', 'Expiring Soon', 'Quarantine', 'Expired'])),
  ], (v, _) {
    if ((v['sup'] as String).isEmpty) {
      toast('Select the Supplier');
      return false;
    }
    if ((v['exp'] as String).compareTo(todayStr()) <= 0) {
      toast('Expiry Date must be after today');
      return false;
    }
    final id = (v['batch_no'] as String).trim();
    if (S.batches.any((b) => b.id == id && b.item == v['item'])) {
      toast('Batch $id already exists for this item');
      return false;
    }
    S.batches.add(Batch(
        id,
        v['item'] as String,
        v['wh'] as String,
        ((v['qty'] ?? 100) as num).toInt(),
        v['mfg'] as String,
        v['exp'] as String,
        v['sup'] as String,
        v['status'] as String));
    after(Res('Batch $id recorded'));
    return false;
  });
}

void newSerialForm() {
  mform('New serial number', [
    const F.header('Serial Number'),
    const F('serial_no', 'Serial No.', req: true, hint: 'e.g. SN-889201'),
    F('item', 'Item',
        type: 'select',
        req: true,
        options: S.items
            .where((p) => p.track == 'Serial')
            .map((p) => Opt(p.id, '${p.name} (${p.id})'))
            .toList()),
    F('wh', 'Warehouse',
        type: 'select',
        req: true,
        def: S.currentWh.id,
        options: S.warehouses
            .map((w) => Opt(w.id, '${w.code} — ${w.city}'))
            .toList()),
    const F('grn', 'GRN Ref.', show: true),
    F('status', 'Status',
        type: 'select',
        show: true,
        options: opts(['Available', 'Allocated', 'Dispatched', 'Scrapped'])),
  ], (v, _) {
    final id = (v['serial_no'] as String).trim();
    if (S.serials.any((x) => x.id == id)) {
      toast('Serial No. $id already exists');
      return false;
    }
    S.serials.add(Serial(
        id,
        v['item'] as String,
        v['wh'] as String,
        (v['status'] as String).isEmpty ? 'Available' : v['status'] as String,
        (v['grn'] as String).isEmpty ? '—' : v['grn'] as String));
    after(Res('Serial $id recorded'));
    return false;
  });
}

Widget batchesView() =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Batches & Serial Numbers',
          sub:
              'Batch-tracked and serial-tracked items · batches with the earliest expiry are picked first'),
      // New batch / New serial number are in each tab's table card, next to Export CSV
      Tabs([
        TabDef(
            'Batches',
            () => DataTableCard(
                  id: 'bat',
                  rowActions: (r) => deleteIcon(() => deleteBatch(r as Batch)),
                  rows: S.batches,
                  exportName: 'batches',
                  createLabel: 'New batch',
                  onCreate: newBatchForm,
                  onRow: (r) => editBatch(r as Batch),
                  search: (r) => '${(r as Batch).id} ${r.item}',
                  filters: [
                    Filt(
                        'Status',
                        const ['Released', 'Expiring Soon', 'Quarantine'],
                        (r) => (r as Batch).status),
                    Filt('Warehouse', S.warehouses.map((w) => w.code).toList(),
                        (r) => S.wh((r as Batch).wh).code),
                  ],
                  cols: [
                    Col('Batch', (r) => Text((r as Batch).id, style: tsB),
                        sort: (r) => (r as Batch).id,
                        text: (r) => (r as Batch).id),
                    Col.t('Item', (r) => S.item((r as Batch).item).name),
                    Col('Warehouse', (r) => chipWh((r as Batch).wh)),
                    Col.t('Qty', (r) => '${(r as Batch).qty}', num: true),
                    Col.t('Mfg Date', (r) => (r as Batch).mfg),
                    Col.t('Expiry', (r) => (r as Batch).exp),
                    Col.t('Supplier', (r) => S.sup((r as Batch).sup).name),
                    Col('Status', (r) => StatusBadge((r as Batch).status),
                        status: true, text: (r) => (r as Batch).status),
                  ],
                )),
        TabDef(
            'Serial numbers',
            () => DataTableCard(
                  id: 'ser',
                  rowActions: (r) =>
                      deleteIcon(() => deleteSerial(r as Serial)),
                  rows: S.serials,
                  exportName: 'serials',
                  createLabel: 'New serial number',
                  onCreate: newSerialForm,
                  onRow: (r) => openItemPanel((r as Serial).item),
                  search: (r) => '${(r as Serial).id} ${r.item} ${r.ref}',
                  cols: [
                    Col('Serial No.', (r) => Text((r as Serial).id, style: tsB),
                        text: (r) => (r as Serial).id),
                    Col.t('Item', (r) => S.item((r as Serial).item).name),
                    Col('Warehouse', (r) => chipWh((r as Serial).wh)),
                    Col('Last Document', (r) => Tag((r as Serial).ref),
                        text: (r) => (r as Serial).ref),
                    Col('Status', (r) => StatusBadge((r as Serial).status),
                        status: true, text: (r) => (r as Serial).status),
                  ],
                )),
      ], storeKey: 'batches'),
    ]);

// ---------------------------------------------------------------- bin movements
void openMove(BinMove m) {
  recPanel(
      m.id,
      'Bin movement · ${S.wh(m.wh).code}',
      [
        Kv.t('Item', S.item(m.item).name),
        Kv.t('Quantity', '${m.qty} ${S.item(m.item).uom}'),
        Kv.t('From bin', m.from),
        Kv.t('To bin', m.to),
        Kv.t('Reason', m.reason),
        Kv.t('Raised by', m.by),
        Kv.t('Date', m.date),
        Kv('Status', StatusBadge(m.status == 'Open' ? 'To Do' : 'Completed')),
      ],
      footer: (_) => [
            if (m.status == 'Open')
              Btn('Confirm move', icon: 'check', onTap: () {
                m.status = 'Done';
                after(
                    Res('Move confirmed · ${m.qty} moved ${m.from} → ${m.to}'));
              }),
          ]);
}

void newMoveForm() {
  mform('New bin movement', [
    const F.header('Document'),
    F('mv_date', 'Movement Date', type: 'date', def: todayStr(), req: true),
    F('mv_type', 'Movement Type',
        type: 'select',
        req: true,
        options: opts(
            ['Bin transfer', 'Replenishment', 'Quarantine', 'Consolidation'])),
    F('item', 'Item',
        type: 'select',
        req: true,
        options: S.items.map((p) => Opt(p.id, p.name)).toList()),
    const F('qty', 'Quantity', type: 'number', def: '50', req: true),
    F('uom', 'UOM',
        type: 'select',
        options: S.uoms.map((u) => Opt(u.code, u.code)).toList()),
    const F.header('Stock'),
    F('wh', 'Warehouse',
        type: 'select',
        req: true,
        def: S.currentWh.id,
        options: S.warehouses.map((w) => Opt(w.id, w.code)).toList()),
    F('from', 'Source Bin',
        type: 'select',
        options: opts(['B-01', 'B-02', 'B-03', 'A-01', 'A-02', 'RCV-01'])),
    F('to', 'Destination Bin',
        type: 'select',
        options: opts(['A-01', 'A-02', 'A-03', 'A-04', 'QRN-01', 'DSP-01'])),
    const F('batch', 'Batch / Serial No.'),
    const F.header('Other'),
    const F('ref', 'Reference Document',
        req: true, hint: 'e.g. PK-2026-0412 or GRN-2026-0299'),
    F('why', 'Reason',
        type: 'select',
        options: opts([
          'Refill picking area',
          'Consolidation',
          'Move damaged to quarantine'
        ])),
    const F('remarks', 'Remarks', type: 'textarea', full: true),
  ], (v, _) {
    if (v['from'] == v['to']) {
      toast('From and to bins must differ');
      return false;
    }
    final id = 'MV-2026-00${25 + S.moves.length - 4}';
    S.moves.insert(
        0,
        BinMove(
            id,
            todayStr(),
            v['wh'] as String,
            v['item'] as String,
            v['from'] as String,
            v['to'] as String,
            (v['qty'] as num).toInt(),
            v['why'] as String,
            'Open',
            'Srinivas Rao'));
    after(Res('Movement $id created'));
    return false;
  }, btn: 'Create movement', icon: 'move');
}

Widget movesView() =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Bin Movements',
          sub:
              'Moves between bins inside a warehouse · replenishment, consolidation, quarantine'),
      DataTableCard(
        id: 'mv',
        rows: S.moves,
        bulk: true,
        exportName: 'bin-movements',
        createLabel: 'New movement',
        onCreate: newMoveForm,
        onRow: (r) => openMove(r as BinMove),
        search: (r) => '${(r as BinMove).id} ${r.item} ${r.reason}',
        filters: [
          Filt('Status', const ['Open', 'Done'], (r) => (r as BinMove).status),
          Filt('Warehouse', S.warehouses.map((w) => w.code).toList(),
              (r) => S.wh((r as BinMove).wh).code),
        ],
        cols: [
          Col('Movement No.', (r) => Text((r as BinMove).id, style: tsB),
              text: (r) => (r as BinMove).id, sort: (r) => (r as BinMove).id),
          Col.t('Date', (r) => (r as BinMove).date),
          Col('Item', (r) => CellTwo(S.item((r as BinMove).item).name, r.item),
              text: (r) => (r as BinMove).item),
          Col('Warehouse', (r) => chipWh((r as BinMove).wh)),
          Col(
              'From → To',
              (r) => Row(mainAxisSize: MainAxisSize.min, children: [
                    Tag((r as BinMove).from),
                    const Text('  →  '),
                    Tag(r.to)
                  ])),
          Col.t('Qty', (r) => '${(r as BinMove).qty}', num: true),
          Col.t('Reason', (r) => (r as BinMove).reason),
          Col(
              'Status',
              (r) => StatusBadge(
                  (r as BinMove).status == 'Open' ? 'To Do' : 'Completed'),
              status: true,
              text: (r) => (r as BinMove).status),
        ],
      ),
    ]);
