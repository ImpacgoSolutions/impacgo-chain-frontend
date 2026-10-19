import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../ui/overlays.dart';
import '../ui/table.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart';

/// Buy › Quality Check: every goods receipt seen from the QC side — what is waiting,
/// what is with the QC team, and the result of each inspection.
/// QC is raised on the goods receipt (Goods Receipts screen); here the QC team posts the result, and the QC report is ready on the goods receipt at once.

/// Where a goods receipt is in quality check.
String qcStage(Doc g) => g.status == 'QC Pending'
    ? 'Waiting for QC'
    : g.status == 'QC Requested'
        ? 'With QC team'
        : 'QC done';

int _received(Doc g) => g.lines.fold(0, (a, l) => a + l.qty);
int _accepted(Doc g) => g.lines.fold(0, (a, l) => a + l.acc);

/// Result of a finished inspection (older receipts without a recorded result are worked out from the quantities).
String qcResultOf(Doc g) {
  if (!qcDone(g)) return '—';
  if ((g.qcResult ?? '').isNotEmpty) return g.qcResult!;
  final acc = _accepted(g), rec = _received(g);
  return acc >= rec ? 'Passed' : (acc == 0 ? 'Failed' : 'Partially passed');
}

Tone _resultTone(String r) => r == 'Passed'
    ? Tone.green
    : r == 'Failed'
        ? Tone.red
        : r == '—'
            ? Tone.gray
            : Tone.amber;

/// The goods raised for QC: item names and the quantity of each.
(String, String) _goods(Doc g) {
  final names = [for (final l in g.lines) l.desc ?? S.item(l.item).name];
  final qty = [for (final l in g.lines) '${l.qty} ${S.item(l.item).uom}'];
  final first = names.take(2).join(', ') + (names.length > 2 ? ' +${names.length - 2} more' : '');
  return (first, '${qty.take(2).join(', ')}${qty.length > 2 ? ' …' : ''} received');
}

/// Records the QC result for one ticked goods receipt that is with the QC team.
void _recordFor(List rows) {
  final ready = rows.cast<Doc>().where((g) => g.status == 'QC Requested').toList();
  if (rows.isEmpty) {
    toast('Tick the goods receipt you inspected');
    return;
  }
  if (ready.length != 1 || rows.length != 1) {
    toast(ready.isEmpty ? 'Raise QC first · only goods receipts with the QC team can be recorded' : 'Tick one goods receipt at a time to record its result');
    return;
  }
  dlgQc(ready.first);
}

Widget qcView() {
  final rows = sortedDocs(S.docsOf('GRN'))
    // open inspections first, then the finished ones
    ..sort((a, b) => (qcDone(a) ? 1 : 0).compareTo(qcDone(b) ? 1 : 0));
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Quality Check', sub: 'Inspect received goods before they go into stock · accepted goods are stocked, rejects go back to the supplier'),
    DataTableCard(
      id: 'qc-table',
      rows: rows,
      bulk: true,
      allowDelete: false,
      exportName: 'quality-check',
      actions: [
        // QC is raised from Goods Receipts; the QC team records the result here, and the report is ready on the goods receipt as soon as it is posted
        TableAction('Post QC result', 'checksq', _recordFor, primary: true),
      ],
      onRow: (r) => openDoc((r as Doc).id),
      search: (r) {
        final g = r as Doc;
        return '${g.id} ${g.ref ?? ''} ${S.partyName(g)} ${g.qcBy ?? ''} ${qcResultOf(g)} ${g.status}';
      },
      filters: [
        Filt('Stage', const ['Waiting for QC', 'With QC team', 'QC done'], (r) => qcStage(r as Doc)),
        Filt('Result', const ['Passed', 'Partially passed', 'Failed'], (r) => qcResultOf(r as Doc)),
      ],
      cols: [
        Col('GRN No.', (r) => CellTwo((r as Doc).id, '${r.date} · ${r.ref ?? '—'}'), sort: (r) => (r as Doc).id, text: (r) => (r as Doc).id),
        Col('Supplier', (r) => partyCell(r as Doc), sort: (r) => S.partyName(r as Doc), text: (r) => S.partyName(r as Doc)),
        // which goods were raised for QC
        Col('Goods', (r) {
          final g = _goods(r as Doc);
          return CellTwo(g.$1, g.$2);
        }, text: (r) => _goods(r as Doc).$1),
        Col.t('Accepted', (r) => qcDone(r as Doc) ? '${_accepted(r)}' : '—', num: true),
        Col('Rejected', (r) {
          final g = r as Doc;
          if (!qcDone(g)) return const Text('—', style: tsBody);
          final rej = _received(g) - _accepted(g);
          return Text('$rej', style: TextStyle(fontSize: 13, fontWeight: rej > 0 ? FontWeight.w700 : FontWeight.w400, color: rej > 0 ? C.red : C.text));
        }, num: true, text: (r) => qcDone(r as Doc) ? '${_received(r) - _accepted(r)}' : '—'),
        Col('Result', (r) {
          final g = r as Doc;
          // not inspected yet: show where it is (waiting / with the QC team)
          final res = qcDone(g) ? qcResultOf(g) : qcStage(g);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            StatusBadge(res, tone: qcDone(g) ? _resultTone(res) : (g.status == 'QC Pending' ? Tone.amber : Tone.blue)),
            if (qcDone(g) && (g.qcBy ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('by ${g.qcBy}', style: tsFaint)),
          ]);
        }, status: true, text: (r) => qcDone(r as Doc) ? qcResultOf(r) : qcStage(r)),
        // the report is ready as soon as the QC team posts the result
        Col('QC Report', (r) {
          final g = r as Doc;
          if (!qcDone(g)) return const Text('After QC', style: tsFaint);
          return Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const StatusBadge('Ready', tone: Tone.green),
            Btn.ghost('Download', icon: 'download', small: true, onTap: () => downloadQc(g)),
          ]);
        }, text: (r) => qcDone(r as Doc) ? 'Ready' : ''),
      ],
    ),
  ]);
}
