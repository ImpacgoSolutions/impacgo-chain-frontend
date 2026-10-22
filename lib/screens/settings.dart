import 'package:flutter/material.dart';
import '../ui/select.dart';
import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/overlays.dart';
import '../ui/table.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'cards.dart';
import 'edit_forms.dart';
import 'remove.dart' show removeRecord, deleteIcon;
import 'importer.dart';
import 'logistics.dart' show drivers, Driver;
import 'setup_lists.dart';

// ================================================================ SCM WORKSPACE
/// Same layout as the prototype: stat cards, the two process flows,
/// module cards and the latest sales orders.
String _longDate(String iso) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final d = DateTime.parse(iso);
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

Widget workspaceView() {
  final openSO = S.docsOf('SO').where((d) => ['Pending Approval', 'On Hold', 'Confirmed', 'Picking', 'Packed'].contains(d.status)).toList();
  final openPO = S.docsOf('PO').where((d) => ['Pending Approval', 'Sent to Supplier', 'Partially Received'].contains(d.status)).toList();
  final pendingDN = S.docsOf('DN').where((d) => ['Ready to Dispatch', 'Dispatched'].contains(d.status)).length;
  var stockValue = 0.0, below = 0;
  for (final it in S.items) {
    for (final w in S.warehouses) {
      stockValue += S.stk(w.id, it.id).onhand * it.cost;
      if (S.avail(w.id, it.id) < it.reorder) below++;
    }
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    PageHeader('SCM Workspace', sub: 'Good afternoon, Srinivas · ${S.currentWh.name} · ${_longDate(todayStr())}', actions: [
      Btn('New sales order', icon: 'plus', onTap: () {
        S.go('sorders');
        openDocForm('SO');
      }),
    ]),
    StatRow([
      Stat('Open sales orders', fmtINR(openSO.fold(0.0, (a, d) => a + d.amount)), '${openSO.length} orders', 'cart', Tone.blue, onTap: () => S.go('sorders')),
      Stat('Ready to dispatch', '${S.docsOf('DN').where((d) => d.status == 'Ready to Dispatch').length}', 'Today', 'truck', Tone.green, onTap: () => S.go('deliveries')),
      Stat('Pending deliveries', '$pendingDN', 'Pending', 'clock', Tone.purple, onTap: () => S.go('dtracking')),
      Stat('Open purchase orders', fmtINR(openPO.fold(0.0, (a, d) => a + d.amount)), '${openPO.length} POs', 'bag', Tone.amber, onTap: () => S.go('porders')),
      Stat('Stock value', fmtINR(stockValue), 'At cost', 'box', Tone.teal, onTap: () => S.go('onhand')),
      Stat('Below reorder level', '$below', 'Action', 'alert', Tone.red, up: false, onTap: () => S.go('rep_low_stock')),
    ], max: 6, compact: true),
    const RGrid(max: 2, minTile: 380, children: [
      FlowChips('Order to Cash', ['Lead', 'Opportunity', 'Quotation', 'Sales Order', 'Credit Check', 'Pick', 'Pack', 'Dispatch', 'Delivery Tracking', 'Invoice', 'Payment'], 3,
          'Credit check, stock reservation, e-way bill, shipment and the invoice are created by the system — users only confirm the physical steps and record the payment.'),
      FlowChips('Procure to Stock', ['Reorder', 'Purchase Request', 'Purchase Order', 'Goods Receipt', 'QC', 'Bin Allocation', 'Purchase Invoice'], 2,
          'Reorder runs daily and suggests requests; bins are allocated after QC so stock is ready to pick.'),
    ]),
    const SizedBox(height: 18),
    const SectionTitle('Latest sales orders'),
    docTable('wsSO', 'SO', sortedDocs(S.docsOf('SO')).take(6).toList(), bulk: false, filters: false),
  ]);
}

// ================================================================ AUTOMATION CENTER
void openScheduleForm([String report = 'Sales register']) {
  const reports = ['Sales register', 'Sales analysis', 'Customer ledger', 'Receivables ageing', 'Outstanding sales orders', 'Pending deliveries', 'Delivery schedule', 'Purchase register', 'Supplier ledger', 'Outstanding POs', 'Supplier performance', 'Warehouse stock summary', 'Stock valuation', 'Stock ageing', 'Batch expiry report'];
  mform('Schedule report', [
    F('rep', 'Report', type: 'select', def: report, options: opts(reports)),
    F('freq', 'Frequency', type: 'select', options: opts(['Daily 08:00', 'Weekly · Mon 09:00', 'Monthly · 1st 09:00', 'Monthly · last day 23:00'])),
    const F('to', 'Recipients (Email)', type: 'email', def: 'srinivas@impacgo.com', req: true, full: true),
    F('fmt', 'Format', type: 'select', options: opts(['PDF', 'CSV', 'PDF + CSV'])),
  ], (v, _) {
    S.reportSchedules.add(ReportSchedule(S.freshId('RS-0', S.reportSchedules.map((x) => x.id)), v['rep'] as String, v['freq'] as String, v['to'] as String, v['fmt'] as String, 'Active'));
    after(Res('${v['rep']} scheduled · ${v['freq']}'));
    return false;
  }, btn: 'Save schedule', icon: 'clock');
}

void _runJob(Job j) {
  final m = S.runJob(j);
  S.refresh();
  toast(m);
}

void _toggleJob(Job j) {
  j.status = j.status == 'Active' ? 'Paused' : 'Active';
  S.refresh();
  toast('${j.name} · ${j.status}');
}

Widget automationView() {
  final touched = S.docs.where((d) => d.log.any((l) => l.who == Users.sys)).length;
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    PageHeader('Automation Center', sub: 'Scheduled jobs, automation rules, emails and the run log · everything the system does without typing', actions: [
      Btn.secondary('Schedule report', icon: 'clock', onTap: openScheduleForm),
      Btn('Run all jobs now', icon: 'play', onTap: () {
        final n = S.runAllJobs();
        S.refresh();
        toast('$n jobs run · see the run log');
      }),
    ]),
    StatRow([
      Stat('Scheduled jobs active', '${S.jobs.where((j) => j.status == 'Active').length} of ${S.jobs.length}', 'Scheduler on', 'clock', Tone.blue),
      Stat('Automation rules', '${S.rules.length}', '${S.rules.where((r) => r.mode == 'AUTO').length} fully auto', 'gear', Tone.purple),
      Stat('Documents touched by system', '$touched', 'Since go-live', 'file', Tone.green),
      Stat('Emails sent', '${S.emails.length}', 'Outbox', 'msg', Tone.amber),
    ], max: 4, compact: true),
    Tabs([
      TabDef('Scheduled jobs', () => DataTableCard(
            id: 'jobs',
            rows: S.jobs,
            exportName: 'scheduled-jobs',
            onRow: (r) => _openJob(r as Job),
            rowActions: (r) => Row(mainAxisSize: MainAxisSize.min, children: [
              IconBtn('play', () => _runJob(r as Job), size: 30, color: C.blue600, tip: 'Run now'),
              const SizedBox(width: 4),
              IconBtn((r as Job).status == 'Active' ? 'pause' : 'refresh', () => _toggleJob(r), size: 30, tip: 'Pause / resume'),
            ]),
            cols: [
              Col('Job', (r) => SizedBox(width: 280, child: CellTwo((r as Job).name, r.what)), text: (r) => (r as Job).name),
              Col('Schedule', (r) => Tag((r as Job).freq)),
              Col.t('Last Run', (r) => (r as Job).last),
              Col('Last Result', (r) => SizedBox(width: 240, child: Text((r as Job).result, style: const TextStyle(fontSize: 12.5)))),
              Col('Status', (r) => StatusBadge((r as Job).status, tone: r.status == 'Active' ? Tone.green : Tone.gray), status: true),
            ],
          )),
      TabDef('Automation rules', () => DataTableCard(
            id: 'rules',
            rows: S.rules,
            pageSize: 12,
            exportName: 'automation-rules',
            search: (r) => '${(r as AutoRule).trig} ${r.act}',
            filters: [
              Filt('Module', const ['CRM', 'Sales', 'Procurement', 'Inventory', 'Warehouse', 'Finance'], (r) => (r as AutoRule).mod),
              Filt('Mode', const ['AUTO', 'SEMI'], (r) => (r as AutoRule).mode),
            ],
            cols: [
              Col('Module', (r) => Tag((r as AutoRule).mod), text: (r) => (r as AutoRule).mod),
              Col('When', (r) => Text((r as AutoRule).trig, style: tsB), text: (r) => (r as AutoRule).trig),
              Col('System does', (r) => SizedBox(width: 360, child: Text((r as AutoRule).act)), text: (r) => (r as AutoRule).act),
              Col('Mode', (r) => AutoTag((r as AutoRule).mode), text: (r) => (r as AutoRule).mode),
            ],
          )),
      TabDef('Run log', () => DataTableCard(
            id: 'alog',
            rows: S.autoLog,
            pageSize: 10,
            exportName: 'automation-run-log',
            search: (r) => '${(r as AutoLog).job} ${r.result} ${r.docs}',
            cols: [
              Col('When', (r) => Text((r as AutoLog).when, style: tsB), text: (r) => (r as AutoLog).when),
              Col.t('Job', (r) => (r as AutoLog).job),
              Col('Result', (r) => SizedBox(width: 260, child: Text((r as AutoLog).result))),
              Col('Documents', (r) => SizedBox(width: 200, child: Text((r as AutoLog).docs, style: const TextStyle(fontSize: 12, color: C.faint)))),
              Col.t('Triggered By', (r) => (r as AutoLog).by),
            ],
          )),
      TabDef('Email outbox', () => DataTableCard(
            id: 'em',
            rows: S.emails,
            pageSize: 10,
            exportName: 'email-outbox',
            onRow: (r) {
              final e = r as Email;
              if (e.doc != '—') {
                openDocNav(e.doc);
              } else {
                toast('Report email · ${e.subject}');
              }
            },
            search: (r) => '${(r as Email).to} ${r.subject} ${r.doc}',
            cols: [
              Col.t('Sent', (r) => (r as Email).when),
              Col.t('To', (r) => (r as Email).to),
              Col('Subject', (r) => SizedBox(width: 300, child: Text((r as Email).subject, style: tsB))),
              Col('Attachment', (r) => Tag((r as Email).doc != '—' ? '${r.doc}.pdf' : 'report.pdf', icon: 'paperclip')),
              Col('Status', (r) => StatusBadge((r as Email).status, tone: Tone.green), status: true),
            ],
          )),
      TabDef('Report schedules', () => DataTableCard(
            id: 'rsch',
            rows: S.reportSchedules,
            exportName: 'report-schedules',
            createLabel: 'New schedule',
            onCreate: openScheduleForm,
            cols: [
              Col('Report', (r) => Text((r as ReportSchedule).report, style: tsB), text: (r) => (r as ReportSchedule).report),
              Col('Frequency', (r) => Tag((r as ReportSchedule).freq)),
              Col.t('Recipients', (r) => (r as ReportSchedule).to),
              Col.t('Format', (r) => (r as ReportSchedule).format),
              Col('Status', (r) => StatusBadge((r as ReportSchedule).status), status: true),
            ],
          )),
      TabDef('Valuation snapshots', () => DataTableCard(
            id: 'vals',
            rows: S.valuations,
            exportName: 'valuation-snapshots',
            cols: [
              Col('Period', (r) => Text((r as Valuation).month, style: tsB)),
              Col.t('Taken', (r) => (r as Valuation).when),
              Col.t('Items', (r) => '${(r as Valuation).items}', num: true),
              Col('Stock Value', (r) => Text(fmtINR((r as Valuation).value), style: tsB), num: true),
            ],
          )),
    ], storeKey: 'automation'),
  ]);
}

void _openJob(Job j) {
  recPanel(j.name, '${j.id} · Scheduled job', [
    Kv.t('What it does', j.what), Kv.t('Schedule', j.freq), Kv.t('Last run', j.last), Kv.t('Last result', j.result), Kv('Status', StatusBadge(j.status, tone: j.status == 'Active' ? Tone.green : Tone.gray)),
  ], extra: [
    TabDef('History', () {
      final h = S.autoLog.where((l) => l.job == j.name).toList();
      if (h.isEmpty) return const Empty('Not run yet');
      return Column(children: [for (final l in h) ActivityRow('check', l.result, '${l.when} · ${l.by}${l.docs != '—' ? ' · ${l.docs}' : ''}', tone: Tone.green)]);
    }),
  ], footer: (_) => [
    Btn.secondary(j.status == 'Active' ? 'Pause' : 'Resume', icon: j.status == 'Active' ? 'pause' : 'play', onTap: () {
      closeAll();
      _toggleJob(j);
    }),
    Btn('Run now', icon: 'play', onTap: () {
      closeAll();
      _runJob(j);
    }),
  ]);
}

// ================================================================ PROCESS GUIDE
class _G {
  final String t;
  final Color c;
  final List<List<String>> steps; // [label, view, note]
  const _G(this.t, this.c, this.steps);
}

const _guide = [
  _G('1 · Set up master data', C.pink, [
    ['Sites, warehouses & bins', 'warehouses', 'One site per GST state; bins drive put-away and picking'],
    ['Items & item setup', 'items', 'HSN, GST, cost, price, reorder level, minimum order qty, tracking'],
    ['Customers & groups', 'customers', 'Group decides price list, terms and credit limit'],
    ['Suppliers & groups', 'suppliers', 'Lead time and terms drive purchasing'],
    ['Pricing', 'pricing', 'Price lists and trade agreements'],
    ['Parameters', 'params', 'Approval limits, price tolerance, automatic steps'],
  ]),
  _G('2 · Win the customer (CRM)', C.red, [
    ['Lead', 'leads', 'Enquiry captured → contacted → qualified'],
    ['Opportunity', 'opps', 'Qualify creates customer + opportunity'],
    ['Quotation', 'quotes', 'Created from the opportunity with rule prices'],
  ]),
  _G('3 · Order to Cash (Sales)', C.blue600, [
    ['Sales order', 'sorders', 'Credit check, approval, stock reservation'],
    ['Picking', 'picking', 'Pick list with bin and earliest-expiry batch'],
    ['Packing', 'packing', 'Cartons and weight → delivery note'],
    ['Trip planning', 'loads', 'Deliveries grouped on a truck'],
    ['Dispatch', 'deliveries', 'Invoice, e-invoice reference, e-way bill, shipment, email'],
    ['Shipment tracking', 'shipments', 'Carrier sync until delivered'],
    ['Payment', 'cpayments', 'Receipt or bank match → order closed'],
    ['Returns', 'sreturns', 'Goods back → credit note'],
  ]),
  _G('4 · Procure to Pay (Purchasing)', C.amber, [
    ['Purchase request', 'preqs', 'Reorder job or user raises need'],
    ['RFQ & supplier quotes', 'rfqs', 'Compare prices, award best'],
    ['Purchase order', 'porders', 'Approval above limit, emailed'],
    ['Goods receipt & QC', 'grns', 'Receive, inspect, stock posted'],
    ['Bin Allocation', 'putaway', 'Move to bin by storage rule'],
    ['Purchase invoice', 'pinvoices', 'Invoice verification'],
  ]),
  _G('5 · Control the stock (Inventory & Warehouse)', C.green, [
    ['Stock on hand', 'onhand', 'On hand, reserved, available, in transit'],
    ['Stock ledger', 'ledger', 'Every movement with its document'],
    ['Transfers', 'transfers', 'Between warehouses via in-transit'],
    ['Bin movements', 'moves', 'Replenishment inside a warehouse'],
    ['Cycle counting', 'counting', 'Counts → automatic adjustments'],
    ['Batches & serials', 'batches', 'Expiry and traceability'],
  ]),
  _G('6 · Monitor and improve', C.purple, [
    ['Workspace', 'workspace', 'KPIs and alerts at a glance'],
    ['Automation Center', 'automation', 'Jobs, rules, emails, run log'],
    ['Reports', 'reports', 'Sales, purchase and inventory reports, scheduled by email'],
  ]),
];

Widget guideView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Process Guide', sub: 'How the website flows from setup to cash — tap any step to open that screen', actions: [Btn('Automation Center', icon: 'gear', onTap: () => S.go('automation'))]),
      const CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What is supply chain management?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text(
              'Supply chain management is everything a company does to get the right goods to the right customer at the right time and cost: buying from suppliers, storing and moving stock, selling and delivering to customers, and collecting the money. IMPACGO Chain connects these steps so every document creates the next one and stock, tax and money stay in sync.',
              style: TextStyle(fontSize: 13, color: C.soft, height: 1.6)),
        ]),
      ),
      const SizedBox(height: 18),
      for (final g in _guide) ...[
        CardBox(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CardHead(g.t, leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: g.c, borderRadius: BorderRadius.circular(3)))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(spacing: 8, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (var i = 0; i < g.steps.length; i++) ...[
                  SizedBox(
                    width: 180,
                    child: CardBox(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => S.go(g.steps[i][1]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(g.steps[i][0], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(g.steps[i][2], style: const TextStyle(fontSize: 11.5, color: C.faint, height: 1.35)),
                      ]),
                    ),
                  ),
                  if (i < g.steps.length - 1) const Text('→', style: TextStyle(color: C.faint)),
                ],
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
    ]);

// ================================================================ SETUP FORMS
void newCompanyProfileForm() {
  mform('Company profile', [

    const F.header('Company'),
    const F('name', 'Company Name', req: true, def: 'IMPACGO Chain Pvt Ltd'),
    const F('tax_reg', 'GSTIN', req: true, def: '37AAHCI4521K1Z6', hint: '15-character GSTIN'),
    const F('addr', 'Address', req: true, full: true, def: 'Plot 12, Industrial Estate, Autonagar, Visakhapatnam'),
    F('state', 'State', type: 'select', req: true, def: 'Andhra Pradesh', options: opts(kStates)),
    const F('phone', 'Phone', req: true, def: '+91 891 2500100'),
    const F('email', 'Email', type: 'email', req: true, def: 'info@impacgo.com'),
    const F.header('Branches & Approval'),
    F('branches', 'Branches', type: 'checks', req: true, options: S.branchNames.map((b) => Opt(b, b)).toList()),
    F('po_limit', 'PO Approval Limit (₹)', type: 'number', req: true, def: S.params.poApproval.toStringAsFixed(0), help: 'POs above this amount need manager approval'),
    const F('legal_name', 'Legal Name'),
    const F('city', 'City', def: 'Visakhapatnam'),
    const F('postal', 'Postal Code', def: '530001'),
  ], (v, _) {
    S.params.poApproval = ((v['po_limit'] ?? S.params.poApproval) as num).toDouble();
    toast('Company Profile updated');
    return false;
  }, btn: 'Save profile', size: ModalSize.wide);
}

// ================================================================ PARAMETERS
class ParamsView extends StatefulWidget {
  const ParamsView({super.key});
  @override
  State<ParamsView> createState() => _ParamsViewState();
}

class _ParamsViewState extends State<ParamsView> {
  late Map<String, TextEditingController> n;
  late Map<String, String> sel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final p = S.params;
    n = {
      'soApproval': TextEditingController(text: p.soApproval.toStringAsFixed(0)),
      'qtDiscount': TextEditingController(text: p.qtDiscount.toStringAsFixed(0)),
      'poApproval': TextEditingController(text: p.poApproval.toStringAsFixed(0)),
      'matchTolerance': TextEditingController(text: p.matchTolerance.toStringAsFixed(0)),
      'adjApproval': TextEditingController(text: p.adjApproval.toStringAsFixed(0)),
      'ewayLimit': TextEditingController(text: p.ewayLimit.toStringAsFixed(0)),
    };
    sel = {
      'creditCheck': p.creditCheck, 'autoReserve': p.autoReserve, 'autoInvoice': p.autoInvoice, 'reorderRun': p.reorderRun,
      'pickStrategy': p.pickStrategy, 'autoPutaway': p.autoPutaway, 'numbering': p.numbering, 'fy': p.fy, 'currency': p.currency,
    };
  }

  @override
  void dispose() {
    for (final c in n.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _num(String k, String label) => _field(label, TextField(controller: n[k], keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13)));

  Widget _sel(String k, String label, List<String> o) => _field(
      label,
      ProtoSelect(
        value: o.contains(sel[k]) ? sel[k]! : o.first,
        options: o.map((x) => SelOpt(x, x)).toList(),
        onChanged: (v) => setState(() => sel[k] = v),
      ));

  Widget _field(String label, Widget w) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft))),
        w,
      ]);

  Widget _sec(String t, String h, List<Widget> fields) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: CardBox(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CardHead(t, hint: isMobile(context) ? null : h),
            Padding(padding: const EdgeInsets.all(20), child: RGrid(max: 2, minTile: 260, gap: 14, children: fields)),
          ]),
        ),
      );

  void _save() {
    final p = S.params;
    double v(String k, double d) => double.tryParse(n[k]!.text.trim()) ?? d;
    p.soApproval = v('soApproval', p.soApproval);
    p.qtDiscount = v('qtDiscount', p.qtDiscount);
    p.poApproval = v('poApproval', p.poApproval);
    p.matchTolerance = v('matchTolerance', p.matchTolerance);
    p.adjApproval = v('adjApproval', p.adjApproval);
    p.ewayLimit = v('ewayLimit', p.ewayLimit);
    p.creditCheck = sel['creditCheck']!;
    p.autoReserve = sel['autoReserve']!;
    p.autoInvoice = sel['autoInvoice']!;
    p.reorderRun = sel['reorderRun']!;
    p.pickStrategy = sel['pickStrategy']!;
    p.autoPutaway = sel['autoPutaway']!;
    p.numbering = sel['numbering']!;
    S.refresh();
    toast('Parameters saved · applied to new documents');
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader('Company & Approval Limits', sub: 'Module rules that drive the automation · changes apply to new documents', actions: [
          Btn.ghost('Clear Buy records', icon: 'trash', onTap: confirmClearBuy),
          Btn.secondary('Company Profile', icon: 'store', onTap: newCompanyProfileForm),
          Btn.secondary('New Branch', icon: 'home', onTap: () => branchForm()),
          Btn.secondary('Number Series', icon: 'tag', onTap: newNumberSeriesForm),
          Btn('Save parameters', icon: 'check', onTap: _save),
        ]),
        screenCards('params'),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            Btn.ghost('+ Currency', onTap: () => currencyForm(), small: true),
            Btn.ghost('+ Payment Term', onTap: () => payTermForm(), small: true),
            Btn.ghost('+ Tax Code', onTap: () => taxCodeForm(), small: true),
            Btn.ghost('+ T&C Template', onTap: () => tcTemplateForm(), small: true),
            Btn.ghost('View all branches & lists', onTap: () => S.go('setuplists'), small: true),
          ]),
        ),
        _sec('Sales', 'Accounts receivable & sales parameters', [
          _num('soApproval', 'Sales order approval above (₹)'),
          _num('qtDiscount', 'Quotation discount approval above (% below price list)'),
          _sel('creditCheck', 'Credit check', ['Block on overdue or limit breach', 'Warn only', 'Off']),
          _sel('autoReserve', 'Reserve stock on confirmation', ['Yes', 'No']),
          _sel('autoInvoice', 'Create invoice', ['Yes — on dispatch', 'No — manual']),
        ]),
        _sec('Procurement', 'Procurement & sourcing parameters', [
          _num('poApproval', 'Purchase order approval above (₹)'),
          _num('matchTolerance', 'Invoice price tolerance (%)'),
          _sel('reorderRun', 'Reorder check schedule', ['Daily at 06:00', 'Twice daily', 'Manual only']),
        ]),
        _sec('Inventory & warehouse', 'Inventory and warehouse management parameters', [
          _num('adjApproval', 'Adjustment approval above (₹)'),
          _sel('pickStrategy', 'Batch picking strategy', ['First Expiry, First Out', 'First In, First Out']),
          _sel('autoPutaway', 'Bin allocation', ['Yes — by storage rule', 'No — user chooses']),
        ]),
        _sec('Compliance & numbering', 'GST, e-way bill and number sequences', [
          _num('ewayLimit', 'E-way bill required above (₹)'),
          _sel('numbering', 'Number sequences', ['Per type · yearly reset', 'Continuous']),
          _sel('fy', 'Financial year', ['2026-27']),
          _sel('currency', 'Currency', ['INR']),
        ]),
      ]);
}

// ================================================================ TABLE HOOKS (import · bulk actions)
/// Lists kept by a screen (not by the store) that are saved with the rest of the data.
void registerPersistence() {
  if (persistExtras.isNotEmpty) return;
  persistExtras.addAll([
    PersistExtra(
        'drivers',
        () => [for (final d in drivers) {'name': d.name, 'phone': d.phone, 'licence': d.licence, 'expiry': d.expiry, 'address': d.address, 'status': d.status}],
        (data) => drivers
          ..clear()
          ..addAll([for (final d in (data as List)) Driver(d['name'], d['phone'], d['licence'], d['expiry'], d['address'], d['status'])])),
    PersistExtra(
        'leadSources',
        () => leadSources,
        (data) => leadSources
          ..clear()
          ..addAll([for (final x in (data as List)) x as String])),
  ]);
}

/// Company Settings › Clear Buy records: removes the purchasing documents (and their stock) but keeps everything else.
void confirmClearBuy() {
  final n = S.docs.where((d) => const {'PR', 'RFQ', 'PO', 'GRN', 'PA', 'PI', 'SP', 'PRT', 'DBN'}.contains(d.type)).length;
  if (n == 0) {
    toast('There are no Buy records to clear');
    return;
  }
  openModal(
    'Clear all Buy records?',
    NoteBox(Tone.amber, 'alert', '$n purchasing document(s) will be removed.',
        'Purchase requests, orders, goods receipts, bin allocations, purchase invoices and returns. The stock they added or took out is put back, and Buy numbers start again from 0001. Suppliers, items and all Sell records stay.'),
    size: ModalSize.narrow,
    actions: (ctx) => [
      Btn.secondary('Cancel', onTap: () => Navigator.of(ctx).pop()),
      Btn.danger('Clear Buy records', icon: 'trash', onTap: () {
        Navigator.of(ctx).pop();
        final done = S.clearBuyRecords();
        S.refresh();
        toast('$done Buy document(s) removed');
      }),
    ],
  );
}

void registerTableHooks() {
  registerPersistence();
  TableHooks.toast = toast;
  TableHooks.canImport = importSpecs.containsKey;
  TableHooks.import = (ctx, id, cols, rows) => openImport(id);
  TableHooks.approve = (ctx, rows) {
    final docs = rows.whereType<Doc>().toList();
    final res = S.bulkApprove(docs);
    final skipped = [...res.skip, ...rows.where((r) => r is! Doc).map((_) => 'master record')];
    DataTableCard.clearAll();
    S.refresh();
    openModal('Bulk approval result', KvGrid([Kv.t('Approved', res.done.isEmpty ? '—' : res.done.join(', ')), Kv.t('Skipped (not waiting for approval)', skipped.isEmpty ? '—' : skipped.join(', '))]),
        size: ModalSize.narrow, actions: (c) => [Btn('Done', onTap: () => Navigator.of(c).pop())]);
  };
  TableHooks.delete = (ctx, rows) {
    final ok = rows.where((r) => (r is Doc && ScmActions.deletable.contains(r.status)) || (r is Lead && r.status == 'New')).toList();
    final kept = rows.length - ok.length;
    if (ok.isEmpty) {
      openModal(
        'Cannot delete',
        const NoteBox(Tone.amber, 'lock', 'These records are posted or in use.',
            'Only drafts and records waiting for approval can be deleted. Posted documents must be cancelled or reversed (return, credit note, adjustment) so the audit trail stays intact.'),
        size: ModalSize.narrow,
        actions: (c) => [Btn('OK', onTap: () => Navigator.of(c).pop())],
      );
      return;
    }
    confirmDelete('${ok.length} record(s)${kept > 0 ? ' ($kept posted record(s) will be kept)' : ''}', () {
      S.deleteDocs(ok.whereType<Doc>().toList());
      S.leads.removeWhere((l) => ok.contains(l));
      DataTableCard.clearAll();
      S.refresh();
      toast('${ok.length} record(s) deleted');
    });
  };
}

/// One line of the Number Series screen: the active series of a document type, or a saved one.
class SeriesRow {
  final String key, prefix;
  final int seq;
  final bool active;
  final SeriesEntry? entry;
  SeriesRow(this.key, this.prefix, this.seq, this.active, this.entry);
}

/// Delete a number series. The one a document type is using now cannot be deleted, and neither can one that
/// already numbered documents, because those documents would lose the series they came from.
void _deleteSeries(SeriesRow r) {
  final label = titleCase(S.dt[r.key]!.label);
  final used = S.docs.where((d) => d.id.startsWith(r.prefix)).length;
  removeRecord(
    'number series',
    '${r.prefix}…',
    [
      if (r.active) 'It is the series $label is using now. Make another series active first, or change this one with Edit.',
      if (!r.active && used > 0) '$used $label document(s) were numbered with this series',
    ],
    () => S.seriesList.remove(r.entry),
  );
}

Widget seriesView() {
  // every series: the one each document type is using now (Active) and the ones saved for later (Inactive)
  final rows = <SeriesRow>[
    for (final e in S.dt.entries) SeriesRow(e.key, e.value.prefix, e.value.seq, true, null),
    for (final s in S.seriesList) SeriesRow(s.key, s.prefix, s.seq, false, s),
  ]..sort((a, b) {
      final c = S.dt[a.key]!.label.compareTo(S.dt[b.key]!.label);
      return c != 0 ? c : (a.active == b.active ? 0 : (a.active ? -1 : 1));
    });
  String next(SeriesRow r) => '${r.prefix}${(r.seq + 1).toString().padLeft(4, '0')}';
  void edit(SeriesRow r) => r.active ? editNumberSeries(r.key, S.dt[r.key]!) : editSeriesEntry(r.entry!);
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Number Series', sub: 'The prefix and next number of every document · a document type uses one active series at a time'),
    DataTableCard(
      id: 'num-series',
      rows: rows,
      exportName: 'number-series',
      createLabel: 'New series',
      onCreate: newNumberSeriesForm,
      rowActions: (r) {
        final x = r as SeriesRow;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          IconBtn('edit', () => edit(x), size: 30, tip: 'Edit'),
          if (!x.active) ...[const SizedBox(width: 4), IconBtn('check', () => activateSeries(x.entry!), size: 30, color: C.blue600, tip: 'Make active')],
          const SizedBox(width: 4),
          deleteIcon(() => _deleteSeries(x)),
        ]);
      },
      onRow: (r) => edit(r as SeriesRow),
      search: (r) => '${S.dt[(r as SeriesRow).key]!.label} ${r.prefix}',
      filters: [Filt('Status', const ['Active', 'Inactive'], (r) => (r as SeriesRow).active ? 'Active' : 'Inactive')],
      cols: [
        Col('Document Type', (r) => Text(titleCase(S.dt[(r as SeriesRow).key]!.label), style: tsB), text: (r) => S.dt[(r as SeriesRow).key]!.label),
        Col.t('Prefix', (r) => (r as SeriesRow).prefix),
        Col('Next Number', (r) => Text(next(r as SeriesRow), style: tsB), text: (r) => next(r as SeriesRow)),
        Col.t('Last Used', (r) => (r as SeriesRow).seq == 0 ? '—' : '${r.prefix}${r.seq.toString().padLeft(4, '0')}'),
        Col.t('Digits', (r) => '4'),
        Col('Status', (r) => StatusBadge((r as SeriesRow).active ? 'Active' : 'Inactive', tone: r.active ? Tone.green : Tone.gray), status: true, text: (r) => (r as SeriesRow).active ? 'Active' : 'Inactive'),
      ],
    ),
  ]);
}
