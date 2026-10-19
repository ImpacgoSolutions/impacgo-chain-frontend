import 'dart:math' as math;
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
import 'remove.dart';
import 'edit_forms.dart';
import 'attachments.dart';

const _leadTone = {'New': Tone.gray, 'Contacted': Tone.blue, 'Qualified': Tone.green, 'Lost': Tone.red};
const _stageTone = {'Prospecting': Tone.gray, 'Proposal': Tone.blue, 'Negotiation': Tone.amber, 'Won': Tone.green, 'Lost': Tone.red};

// ================================================================ LEADS
/// Next-step buttons for a lead.
List<Widget> _leadActions(Lead l) => [
      // a lead can be deleted until it has become an opportunity
      if (l.opp == null) deleteBtn(() => deleteLead(l)),
      if (l.status == 'New' || l.status == 'Contacted')
        Btn.danger('Mark lost', icon: 'x', onTap: () => _markLost(l.id, (why) {
              l.lostReason = why;
              _leadSet(l, 'Lost');
            })),
      if (l.status == 'New') Btn('Mark contacted', icon: 'msg', onTap: () => _leadSet(l, 'Contacted')),
      if (l.status == 'Contacted')
        // opens the opportunity form already filled in from the lead; nothing is created until "Create opportunity"
        Btn('Convert to opportunity', icon: 'check', onTap: () {
          closeAll();
          leadToOppForm(l);
        }),
    ];

/// A created lead always opens as the form it was created with: changeable (with Save changes) until it is
/// qualified or lost, then shown as it is, not changeable. Only the next step is offered.
void openLead(Lead l) {
  editLead(l,
      record: true,
      readOnly: !canEditLead(l),
      headerActions: [AttachPin(l.id)],
      extra: (_) => _leadActions(l),
      onSaved: () {
        closeAll();
        S.refresh();
        toast('${l.id} saved');
        openLead(l);
      });
}

/// Opportunity form filled in from a qualified lead. The customer and the opportunity are created
/// only when "Create opportunity" is pressed, so every field can be checked and changed first.
void leadToOppForm(Lead l) {
  final p = S.items.where((x) => x.id == l.interest).firstOrNull;
  final qty = p == null ? 10 : math.max(10, (l.value / p.price).round());
  final people = S.salesPersons.where((s) => s.status != 'Inactive').map((s) => s.name).toList();
  if (!people.contains(l.owner)) people.insert(0, l.owner);
  mform('New opportunity · from ${l.id}', [
    const F.header('Opportunity'),
    F('opp_no', 'Opportunity No.', type: 'readonly', def: S.nextOppId()),
    F('cust', 'Customer', type: 'readonly', def: l.company),
    F('title', 'Opportunity Name', req: true, def: p == null ? 'First order' : 'First order — ${p.name}'),
    F('owner', 'Sales Person', type: 'select', req: true, def: l.owner, options: opts(people)),
    F('val', 'Estimated Value (₹)', type: 'number', req: true, def: l.value.toStringAsFixed(0)),
    F('close', 'Expected Close Date', type: 'date', req: true, def: addDays(todayStr(), 21)),
    F('stage', 'Stage', type: 'select', req: true, custom: true, def: 'Prospecting', options: opts(['Prospecting', 'Proposal', 'Negotiation'])),
    const F('prob', 'Win Probability (%)', type: 'number', def: '30'),
    F('lead_ref', 'Lead Ref.', type: 'readonly', def: l.id),
    const F.header('Line Item'),
    F('item', 'Product', type: 'select', req: true, def: l.interest, options: S.items.map((x) => Opt(x.id, '${x.name} (${x.id})')).toList()),
    F('qty', 'Qty', type: 'number', req: true, def: '$qty'),
  ], (v, _) {
    final r = S.qualifyLead(l,
        title: v['title'] as String,
        owner: v['owner'] as String,
        value: ((v['val'] ?? l.value) as num).toDouble(),
        close: v['close'] as String,
        stage: v['stage'] as String,
        prob: ((v['prob'] ?? 30) as num).toInt(),
        item: v['item'] as String,
        qty: ((v['qty'] ?? 1) as num).toInt());
    closeAll();
    S.go('opps');
    S.refresh();
    toast(r.msg);
    openOpp(S.opps.first);
    return false;
  }, btn: 'Create opportunity', icon: 'check', size: ModalSize.wide);
}

/// Marking a lead or opportunity lost always records why.
void _markLost(String id, void Function(String why) done) {
  mform('Mark lost · $id', [
    const F.header('Lost'),
    F('why', 'Lost Reason', type: 'select', req: true, custom: true, options: opts(['Price too high', 'Bought from a competitor', 'No budget', 'Requirement cancelled', 'No response'])),
    const F('details', 'Details', type: 'textarea', full: true, show: true, hint: 'e.g. Competitor quoted 8% lower'),
  ], (v, _) {
    final d = (v['details'] as String).trim();
    done(d.isEmpty ? v['why'] as String : '${v['why']} · $d');
    return false;
  }, btn: 'Mark lost', icon: 'x');
}

void _leadSet(Lead l, String s) {
  l.status = s;
  closeAll();
  S.refresh();
  toast('${l.id} · $s');
  openLead(l);
}

void newLeadForm() {
  mform('New lead', [

    const F.header('Lead'),
    F('lead_no', 'Lead No.', type: 'readonly', def: S.nextLeadId()),
    F('date', 'Lead Date', type: 'date', req: true, def: todayStr()),
    const F('co', 'Company Name', req: true, hint: 'e.g. Kurnool Traders'),
    const F('ct', 'Contact Person', req: true),
    const F('phone', 'Mobile No.', def: '+91 ', hint: 'Mobile or Email required'),
    const F('email', 'Email', type: 'email', hint: 'Mobile or Email required'),
    F('src', 'Lead Source', type: 'select', req: true, custom: true, options: opts(leadSources)),
    F('owner', 'Sales Person', type: 'select', req: true, options: opts(S.salesPersons.where((s) => s.status != 'Inactive').map((s) => s.name).toList())),
    F('status', 'Status', type: 'select', req: true, options: opts(['New', 'Contacted', 'Qualified', 'Unqualified', 'Converted'])),
    const F('unqualified_reason', 'Unqualified Reason', help: 'Mandatory if status is Unqualified', full: true),
    const F('city', 'City', req: true, def: 'Kurnool'),
    F('st', 'State', type: 'select', req: true, def: 'Andhra Pradesh', options: opts(kStates)),
    F('item', 'Product Interest', type: 'select', req: true, options: S.items.map((p) => Opt(p.id, p.name)).toList()),
    const F('val', 'Estimated Value (₹)', type: 'number', req: true, def: '100000'),
  ], (v, _) {
    final phone = (v['phone'] as String).trim(), email = (v['email'] as String).trim();
    if ((phone.isEmpty || phone == '+91') && email.isEmpty) {
      toast('Enter a mobile number or an email');
      return false;
    }
    final id = S.nextLeadId();
    final lead = Lead(id, v['co'] as String, v['ct'] as String, (v['city'] as String).isEmpty ? 'Kurnool' : v['city'] as String, v['st'] as String, v['src'] as String, v['owner'] as String, ((v['val'] ?? 100000) as num).toDouble(), v['date'] as String, v['status'] as String, v['item'] as String)
      ..phone = phone
      ..email = email;
    S.leads.insert(0, lead);
    rememberLeadSource(lead.source);
    after(Res('Lead $id created'));
    return false;
  }, btn: 'Save lead', size: ModalSize.wide);
}

Widget leadsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Leads', sub: 'Prospects not yet buying · qualify a lead to create the customer and an opportunity'),
      DataTableCard(
        id: 'lead',
        rows: S.leads,
        bulk: true,
        exportName: 'leads',
        createLabel: 'New lead',
        onCreate: newLeadForm,
        onRow: (r) => openLead(r as Lead),
        search: (r) => '${(r as Lead).id} ${r.company} ${r.city} ${r.owner}',
        filters: [
          Filt('Status', const ['New', 'Contacted', 'Qualified', 'Lost', 'Unqualified', 'Converted'], (r) => (r as Lead).status),
          Filt('Sales Person', S.salesPersons.map((s) => s.name).toList(), (r) => (r as Lead).owner),
        ],
        cols: [
          Col('Lead No.', (r) => Text((r as Lead).id, style: tsB), sort: (r) => (r as Lead).id, text: (r) => (r as Lead).id),
          Col('Company', (r) => CellAv((r as Lead).company, r.city), text: (r) => (r as Lead).company),
          Col.t('Contact', (r) => (r as Lead).contact),
          Col('Source', (r) => Tag((r as Lead).source), text: (r) => (r as Lead).source),
          Col.t('Interested In', (r) => S.items.where((p) => p.id == (r as Lead).interest).firstOrNull?.name ?? '—'),
          Col.t('Sales Person', (r) => (r as Lead).owner),
          Col('Estimated Value', (r) => Text(fmtINR((r as Lead).value), style: tsB), num: true, sort: (r) => (r as Lead).value),
          Col.t('Lead Date', (r) => (r as Lead).date),
          Col('Status', (r) => StatusBadge((r as Lead).status, tone: _leadTone[r.status]), status: true, text: (r) => (r as Lead).status),
        ],
      ),
    ]);

// ================================================================ OPPORTUNITIES
void newOppForm() {
  mform('New opportunity', [

    const F.header('Opportunity'),
    F('opp_no', 'Opportunity No.', type: 'readonly', def: S.nextOppId()),
    F('party', 'Customer', type: 'select', req: true, options: S.customers.where((c) => c.status != 'Inactive').map((c) => Opt(c.id, c.name)).toList()),
    const F('title', 'Opportunity Name', req: true, hint: 'e.g. Warehouse Racking Supply'),
    F('owner', 'Sales Person', type: 'select', req: true, options: opts(S.salesPersons.where((s) => s.status != 'Inactive').map((s) => s.name).toList())),
    const F('val', 'Estimated Value (₹)', type: 'number', def: '250000', req: true),
    F('close', 'Expected Close Date', type: 'date', def: addDays(todayStr(), 30), req: true),
    F('stage', 'Stage', type: 'select', req: true, custom: true, options: opts(['Prospecting', 'Proposal Sent', 'Negotiation', 'Won', 'Lost'])),
    const F('prob', 'Win Probability (%)', type: 'number', def: '50'),
    F('lead_ref', 'Lead Ref.', type: 'select', options: [const Opt('', '— none —'), ...S.leads.map((l) => Opt(l.id, '${l.id} · ${l.company}'))]),
    const F('lost_reason', 'Lost Reason', help: 'Mandatory if Lost', full: true),
    const F.header('Line Item'),
    F('item', 'Product', type: 'select', req: true, options: S.items.map((p) => Opt(p.id, '${p.name} (${p.id})')).toList()),
    const F('qty', 'Qty', type: 'number', def: '100', req: true),
  ], (v, _) {
    final id = S.nextOppId();
    final o = Opportunity(id, v['party'] as String, v['title'] as String, v['owner'] as String, ((v['val'] ?? 250000) as num).toDouble(), ((v['prob'] ?? 50) as num).toInt(), v['close'] as String, v['stage'] as String, [
      OppLine(v['item'] as String, ((v['qty'] ?? 1) as num).toInt()),
    ], lead: (v['lead_ref'] as String).isEmpty ? null : v['lead_ref'] as String);
    S.opps.insert(0, o);
    after(Res('Opportunity $id created'));
    return false;
  }, btn: 'Save opportunity', size: ModalSize.wide);
}

/// Next-step buttons for an open opportunity.
List<Widget> _oppActions(Opportunity o) => [
      // an opportunity can be deleted until its quotation is created
      if (o.quote == null) deleteBtn(() => deleteOpp(o)),
      if (!['Won', 'Lost'].contains(o.stage))
        Btn.danger('Mark lost', icon: 'x', onTap: () => _markLost(o.id, (why) {
              o.lostReason = why;
              _oppSet(o, 'Lost');
            })),
      // opens the quotation form filled in from the opportunity; created (as Draft) only on "Create quotation"
      if (o.quote == null && !['Won', 'Lost'].contains(o.stage))
        Btn('Create quotation', icon: 'file', onTap: () {
          closeAll();
          openFormPage('New Quotation · from ${o.id}', DocForm('QT', party: o.party, fromOppId: o.id));
        }),
      if (o.quote != null && !['Won', 'Lost'].contains(o.stage)) ...[
        Btn.secondary('Open quotation', icon: 'file', onTap: () => openDocNav(o.quote!)),
        Btn('Mark won', icon: 'check', onTap: () => _oppSet(o, 'Won')),
      ],
    ];

/// A created opportunity always opens as the form it was created with: changeable (with Save changes) until its
/// quotation is created or it is won / lost, then shown as it is, not changeable. Only the next step is offered.
void openOpp(Opportunity o) {
  editOpp(o,
      record: true,
      readOnly: !canEditOpp(o),
      headerActions: [AttachPin(o.id)],
      extra: (_) => _oppActions(o),
      onSaved: () {
        closeAll();
        S.refresh();
        toast('${o.id} saved');
        openOpp(o);
      });
}

void _oppSet(Opportunity o, String s) {
  o.stage = s;
  o.prob = s == 'Won' ? 100 : s == 'Lost' ? 0 : o.prob;
  closeAll();
  S.refresh();
  toast('${o.id} · $s');
  openOpp(o);
}

Widget oppsView() {
  final open = S.opps.where((o) => !['Won', 'Lost'].contains(o.stage)).toList();
  final won = S.opps.where((o) => o.stage == 'Won').length;
  final closed = S.opps.where((o) => ['Won', 'Lost'].contains(o.stage)).length;
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    PageHeader('Opportunities', sub: 'Open deals · a proposal creates the quotation in Sales', actions: [
      Btn('New opportunity', icon: 'plus', onTap: newOppForm),
    ]),
    StatRow([
      Stat('Open pipeline', fmtINR(open.fold<double>(0, (a, o) => a + o.value)), '${open.length} deals', 'trend', Tone.blue),
      Stat('Weighted pipeline', fmtINR(open.fold<double>(0, (a, o) => a + o.value * o.prob / 100)), 'By probability', 'percent', Tone.purple),
      Stat('Won deals', '$won', 'Closed won', 'check', Tone.green),
      Stat('Win rate', '${(won / math.max(1, closed) * 100).round()}%', 'Closed deals', 'percent', Tone.amber),
    ], max: 4, compact: true),
    DataTableCard(
      id: 'opp',
      rows: S.opps,
      bulk: true,
      exportName: 'opportunities',
      onRow: (r) => openOpp(r as Opportunity),
      search: (r) => '${(r as Opportunity).id} ${r.title} ${r.owner}',
      filters: [
        Filt('Stage', const ['Prospecting', 'Proposal Sent', 'Negotiation', 'Won', 'Lost'], (r) => (r as Opportunity).stage),
        Filt('Sales Person', S.salesPersons.map((s) => s.name).toList(), (r) => (r as Opportunity).owner),
      ],
      cols: [
        Col('Opportunity', (r) => Text((r as Opportunity).id, style: tsB), text: (r) => (r as Opportunity).id, sort: (r) => (r as Opportunity).id),
        Col('Customer', (r) => CellAv(S.cust((r as Opportunity).party).name, r.title), text: (r) => S.cust((r as Opportunity).party).name),
        Col.t('Sales Person', (r) => (r as Opportunity).owner),
        Col('Estimated Value', (r) => Text(fmtINR((r as Opportunity).value), style: tsB), num: true, sort: (r) => (r as Opportunity).value),
        Col('Probability', (r) => BarPct((r as Opportunity).prob.toDouble()), sort: (r) => (r as Opportunity).prob),
        Col.t('Close Date', (r) => (r as Opportunity).close),
        Col('Stage', (r) => StatusBadge((r as Opportunity).stage, tone: _stageTone[r.stage]), status: true, text: (r) => (r as Opportunity).stage),
      ],
    ),
  ]);
}

// ================================================================ CONTACTS
void newContactForm() {
  mform('New contact', [

    const F.header('Contact'),
    F('cust', 'Customer', type: 'select', req: true, options: S.customers.where((c) => c.status != 'Inactive').map((c) => Opt(c.id, c.name)).toList()),
    const F('name', 'Contact Name', req: true),
    const F('phone', 'Mobile No.', def: '+91 ', req: true),
    const F('desig', 'Designation', hint: 'e.g. Purchase Manager'),
    const F('email', 'Email', type: 'email', req: false),
    F('primary', 'Primary Contact', type: 'select', options: opts(['No', 'Yes'])),
  ], (v, _) {
    if (v['primary'] == 'Yes') {
      for (final c in S.contacts) {
        if (c.cust == v['cust']) c.primary = 'No';
      }
    }
    S.contacts.add(Contact(v['name'] as String, v['cust'] as String, (v['desig'] as String).isEmpty ? 'Contact' : v['desig'] as String, v['phone'] as String, v['email'] as String, v['primary'] as String));
    after(Res('Contact ${v['name']} added to ${S.cust(v['cust'] as String).name}'));
    return false;
  }, btn: 'Save contact');
}

Widget contactsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Contacts', sub: 'People we deal with at each customer'),
      DataTableCard(
        id: 'ct',
        rowActions: (r) => deleteIcon(() => deleteContact(r as Contact)),
        rows: S.contacts,
        exportName: 'contacts',
        createLabel: 'New contact',
        onCreate: newContactForm,
        onRow: (r) => editContact(r as Contact),
        search: (r) => '${(r as Contact).name} ${r.role} ${r.email}',
        filters: [Filt('Customer', S.customers.map((c) => c.name).toList(), (r) => S.cust((r as Contact).cust).name)],
        cols: [
          Col('Name', (r) => CellAv((r as Contact).name, r.role), text: (r) => (r as Contact).name, sort: (r) => (r as Contact).name),
          Col.t('Customer', (r) => S.cust((r as Contact).cust).name),
          Col.t('Phone', (r) => (r as Contact).phone),
          Col.t('Email', (r) => (r as Contact).email),
          Col('Primary', (r) => (r as Contact).primary == 'Yes' ? const StatusBadge('Primary', tone: Tone.green) : const Text('—', style: TextStyle(color: C.faint))),
        ],
      ),
    ]);

// ================================================================ SALES PERSONS
void openSalesPerson(SalesPerson s) {
  final t = S.territories.firstWhere((x) => x.id == s.terr);
  recPanel(s.name, '${s.id} · Sales person', [
    Kv.t('Territory', t.name), Kv.t('Cities', t.cities), Kv.t('Phone', s.phone), Kv.t('Quarter target', fmtINR(s.target)), Kv.t('Achieved', fmtINR(S.spAchieved(s))), Kv('Status', StatusBadge(s.status)),
  ], extra: [
    TabDef('Orders', () => partyDocs((d) => d.type == 'SO' && S.terrOf[d.party] == s.terr)),
    TabDef('Customers', () => Column(children: [
          for (final c in S.customers.where((c) => S.terrOf[c.id] == s.terr)) ActivityRow('users', c.name, '${c.city} · ${c.group}', onTap: () => openCustomerPanel(c.id)),
        ])),
  ], footer: (_) => [Btn.secondary('Edit', icon: 'edit', onTap: () { closeAll(); editSalesPerson(s); }),deleteBtn(() => deleteSalesPerson(s)),]);
}

void newSalesPersonForm() {
  mform('New sales person', [

    const F.header('Sales Person'),
    const F('name', 'Name', req: true),
    const F('phone', 'Mobile No.', def: '+91 ', req: true),
    const F('email', 'Email', type: 'email', req: false, hint: 'name@impacgo.com'),
    F('terr', 'Territory', type: 'select', options: S.territories.map((t) => Opt(t.id, t.name)).toList()),
    const F('target', 'Quarterly Target (₹)', type: 'number', def: '1500000'),
    F('status', 'Status', type: 'select', options: opts(['Active', 'Inactive'])),
  ], (v, _) {
    final id = S.freshId('SP-0', S.salesPersons.map((x) => x.id));
    S.salesPersons.add(SalesPerson(id, (v['name'] as String).trim(), v['terr'] as String, v['phone'] as String, ((v['target'] ?? 0) as num).toDouble(), v['status'] as String)..email = (v['email'] as String).trim());
    after(Res('${v['name']} added · $id'));
    return false;
  }, btn: 'Save sales person');
}

Widget salesPersonsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Sales Persons', sub: 'Targets and achievement from confirmed sales orders in each territory'),
      DataTableCard(
        id: 'spn',
        rows: S.salesPersons,
        exportName: 'sales-persons',
        createLabel: 'New sales person',
        onCreate: newSalesPersonForm,
        onRow: (r) => openSalesPerson(r as SalesPerson),
        cols: [
          Col('Sales Person', (r) => CellAv((r as SalesPerson).name, r.id), text: (r) => (r as SalesPerson).name),
          Col('Territory', (r) => Tag(S.territories.firstWhere((t) => t.id == (r as SalesPerson).terr).name)),
          Col.t('Phone', (r) => (r as SalesPerson).phone),
          Col('Quarter Target', (r) => Text(fmtINR((r as SalesPerson).target)), num: true),
          Col('Achieved', (r) => Text(fmtINR(S.spAchieved(r as SalesPerson)), style: tsB), num: true, sort: (r) => S.spAchieved(r as SalesPerson)),
          Col('Progress', (r) {
            final p = S.spAchieved(r as SalesPerson) / r.target * 100;
            return BarPct(p, color: p >= 60 ? C.green : C.amber);
          }),
          Col('Status', (r) => StatusBadge((r as SalesPerson).status), status: true),
        ],
      ),
    ]);

// ================================================================ TERRITORIES
void newTerritoryForm() {
  mform('New territory', [
    const F.header('General'),
    const F('name', 'Territory Name', req: true, hint: 'e.g. Odisha'),
    const F('code', 'Territory Code', hint: 'e.g. TER-05'),
    F('parent', 'Parent Territory', type: 'select', options: opts(['—', ...S.territories.map((t) => t.name)])),
    const F('country', 'Country', def: 'India'),
    const F('states', 'States Covered', req: true),
    const F('cities', 'Key Cities', req: true, full: true),
    F('mgr', 'Territory Manager', type: 'select', options: opts(S.salesPersons.where((s) => s.status != 'Inactive').map((s) => s.name).toList())),
    F('wh', 'Dispatch Warehouse', type: 'select', options: S.warehouses.map((w) => Opt(w.id, w.code)).toList()),
    const F('target_rev', 'Target Revenue (₹)', type: 'number'),
    const F.header('Status'),
    F('status', 'Status', type: 'select', options: opts(['Active', 'Inactive'])),
  ], (v, _) {
    final id = S.freshId('TER-0', S.territories.map((x) => x.id));
    S.territories.add(Territory(id, (v['name'] as String).trim(), v['states'] as String, v['cities'] as String, v['mgr'] as String, v['wh'] as String)
      ..code = (v['code'] as String).trim()
      ..parent = v['parent'] as String
      ..country = (v['country'] as String).trim().isEmpty ? 'India' : (v['country'] as String).trim()
      ..targetRev = ((v['target_rev'] ?? 0) as num).toDouble()
      ..status = v['status'] as String);
    after(Res('Territory ${v['name']} created'));
    return false;
  }, btn: 'Save territory');
}

Widget territoriesView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Territories', sub: 'Sales regions · decide the sales person and the default shipping warehouse'),
      DataTableCard(
        id: 'ter',
        rows: S.territories,
        rowActions: (r) => Row(mainAxisSize: MainAxisSize.min, children: [
          IconBtn('edit', () => editTerritory(r as Territory), size: 30, tip: 'Edit'),
          const SizedBox(width: 4),
          deleteIcon(() => deleteTerritory(r as Territory)),
        ]),
        exportName: 'territories',
        createLabel: 'New territory',
        onCreate: newTerritoryForm,
        onRow: (r) {
          final t = r as Territory;
          SalesPerson? sp;
          for (final s in S.salesPersons) {
            if (s.terr == t.id) sp = s;
          }
          if (sp != null) {
            openSalesPerson(sp);
          } else {
            recPanel(t.name, t.id, [Kv.t('States', t.states), Kv.t('Cities', t.cities), Kv.t('Manager', t.manager), Kv.t('Ships from', S.wh(t.wh).code)]);
          }
        },
        cols: [
          Col('Territory', (r) => CellTwo((r as Territory).name, r.id), text: (r) => (r as Territory).name),
          Col.t('States', (r) => (r as Territory).states),
          Col.t('Cities', (r) => (r as Territory).cities),
          Col.t('Sales Person', (r) => (r as Territory).manager),
          Col('Ships From', (r) => chipWh((r as Territory).wh)),
          Col.t('Customers', (r) => '${S.customers.where((c) => S.terrOf[c.id] == (r as Territory).id).length}', num: true),
        ],
      ),
    ]);
