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
import 'sales_proc.dart';

// ---------------------------------------------------------------- delivery schedule
class SchedRow {
  final Doc so;
  final int days;
  SchedRow(this.so, this.days);
  String get when => days < 0 ? 'Late' : days == 0 ? 'Today' : days == 1 ? 'Tomorrow' : 'Later';
  String get next => const {
        'Pending Approval': 'Approve order',
        'On Hold': 'Clear credit hold',
        'Confirmed': 'Release to warehouse',
        'Picking': 'Finish picking',
        'Packed': 'Dispatch',
        'Invoiced': 'In transit to customer',
      }[so.status] ??
      '—';
}

Widget deliveryScheduleView() {
  final rows = S.docsOf('SO').where((s) => !['Closed', 'Rejected', 'Draft', 'Delivered'].contains(s.status)).map((s) => SchedRow(s, daysBetween(todayStr(), s.delivery ?? todayStr()))).toList()
    ..sort((a, b) => (a.so.delivery ?? '').compareTo(b.so.delivery ?? ''));
  int cnt(String w) => rows.where((r) => r.when == w).length;
  const whenTone = {'Late': Tone.red, 'Today': Tone.amber, 'Tomorrow': Tone.blue, 'Later': Tone.gray};
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Delivery Schedule', sub: 'Promised delivery dates for every open order and what must happen next'),
    StatRow([
      Stat('Late', '${cnt('Late')}', 'Past promise date', 'alert', Tone.red, up: false),
      Stat('Due today', '${cnt('Today')}', 'Today', 'calendar', Tone.amber),
      Stat('Due tomorrow', '${cnt('Tomorrow')}', 'Tomorrow', 'calendar', Tone.blue),
      Stat('Later', '${cnt('Later')}', 'This week +', 'clock', Tone.green),
    ], max: 4, compact: true),
    DataTableCard(
      id: 'dsc',
      rows: rows,
      exportName: 'delivery-schedule',
      onRow: (r) => openDocNav((r as SchedRow).so.id),
      search: (r) => '${(r as SchedRow).so.id} ${S.partyName(r.so)}',
      filters: [
        Filt('Due', const ['Late', 'Today', 'Tomorrow', 'Later'], (r) => (r as SchedRow).when),
        Filt('Warehouse', S.warehouses.map((w) => w.code).toList(), (r) => S.wh((r as SchedRow).so.wh).code),
      ],
      cols: [
        Col('Delivery Date', (r) => Text((r as SchedRow).so.delivery ?? '', style: tsB), sort: (r) => (r as SchedRow).so.delivery ?? '', text: (r) => (r as SchedRow).so.delivery ?? ''),
        Col('Due', (r) => StatusBadge((r as SchedRow).when, tone: whenTone[r.when]), text: (r) => (r as SchedRow).when),
        Col('Order No.', (r) => Text((r as SchedRow).so.id, style: tsB), text: (r) => (r as SchedRow).so.id),
        Col('Customer', (r) => CellAv(S.partyName((r as SchedRow).so), S.partyCity(r.so)), text: (r) => S.partyName((r as SchedRow).so)),
        Col('From', (r) => chipWh((r as SchedRow).so.wh)),
        Col('Value', (r) => Text(fmtINR((r as SchedRow).so.amount)), num: true, sort: (r) => (r as SchedRow).so.amount),
        Col.t('Next Step', (r) => (r as SchedRow).next),
        Col('Status', (r) => StatusBadge((r as SchedRow).so.status), status: true, text: (r) => (r as SchedRow).so.status),
      ],
    ),
  ]);
}

// ---------------------------------------------------------------- vehicles
void openVehicle(Vehicle v) {
  final st = S.vehStatus(v);
  recPanel(v.name.split(' (').first, '${v.id} · ${v.type}', [
    Kv.t('Type', v.type), Kv.t('Base', S.wh(v.wh).code), Kv.t('Driver', v.driver), Kv.t('Capacity', v.cap), Kv.t('Trip template', v.tmpl), Kv.t('Status', st.s),
    if (st.ld.isNotEmpty) Kv.t('Current load', st.ld),
  ], extra: [
    TabDef('Loads', () => partyDocs((d) => d.type == 'LD' && d.vehicle == v.name)),
  ], footer: (_) => [
    Btn.secondary('Edit', icon: 'edit', onTap: () { closeAll(); editVehicle(v); }),
    deleteBtn(() => deleteVehicle(v)),
    if (st.ld.isNotEmpty)
      Btn('Open load', icon: 'layers', onTap: () => openDocNav(st.ld))
    else
      Btn('Assign to new load', icon: 'plus', onTap: () {
        closeAll();
        newLoadForm(vehicleName: v.name);
      }),
  ]);
}

void newVehicleForm() {
  mform('Add vehicle', [

    const F.header('Vehicle'),
    const F('reg', 'Vehicle No.', req: true, hint: 'e.g. AP 31 AB 1234'),
    F('type', 'Vehicle Type', type: 'select', req: true, options: S.loadTemplates.map((t) => Opt(t.id, t.name)).toList()),
    F('status', 'Status', type: 'select', req: true, options: opts(['Available', 'Assigned', 'On Route', 'Under Maintenance'])),
    F('own', 'Ownership', type: 'select', options: opts(['Own', 'Leased', 'Carrier'])),
    F('wh', 'Home Warehouse', type: 'select', def: S.currentWh.id, options: S.warehouses.map((w) => Opt(w.id, w.code)).toList()),
    F('driver', 'Assigned Driver', type: 'select', options: opts(['—', ...drivers.where((d) => d.status != 'Inactive').map((d) => d.name)])),
  ], (v, _) {
    final t = S.loadTemplates.firstWhere((x) => x.id == v['type'], orElse: () => S.loadTemplates.first);
    final id = S.freshId('VH-0', S.fleet.map((x) => x.id));
    final name = '${(v['reg'] as String).toUpperCase()} (${v['own']} · ${t.name.split(' (').first})';
    S.fleet.add(Vehicle(id, name, t.name, v['wh'] as String, v['driver'] == '—' ? 'Unassigned' : v['driver'] as String, t.weight, t.id)
      ..status = v['status'] as String
      ..own = v['own'] as String);
    S.vehicles.insert(S.vehicles.length - 1, name);
    after(Res('Vehicle $id added'));
    return false;
  }, btn: 'Save vehicle', size: ModalSize.wide);
}

Widget vehiclesView() {
  const tone = {'Available': Tone.green, 'Assigned': Tone.blue, 'Loading': Tone.amber, 'On Route': Tone.purple};
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Vehicles', sub: 'Own fleet and the load each vehicle is assigned to'),
    DataTableCard(
      id: 'veh',
      rows: S.fleet,
      exportName: 'vehicles',
      createLabel: 'Add vehicle',
      onCreate: newVehicleForm,
      onRow: (r) => openVehicle(r as Vehicle),
      filters: [
        Filt('Status', const ['Available', 'Assigned', 'Loading', 'On Route'], (r) => S.vehStatus(r as Vehicle).s),
        Filt('Warehouse', S.warehouses.map((w) => w.code).toList(), (r) => S.wh((r as Vehicle).wh).code),
      ],
      cols: [
        Col('Vehicle', (r) => CellTwo((r as Vehicle).name.split(' (').first, '${r.id} · ${r.type}'), text: (r) => (r as Vehicle).name),
        Col('Base', (r) => chipWh((r as Vehicle).wh)),
        Col.t('Driver', (r) => (r as Vehicle).driver),
        Col.t('Capacity', (r) => (r as Vehicle).cap),
        Col('Trip Template', (r) => Tag((r as Vehicle).tmpl)),
        Col('Current Load', (r) {
          final l = S.vehStatus(r as Vehicle).ld;
          return l.isEmpty ? const Text('—', style: TextStyle(color: C.faint)) : Tag(l);
        }),
        Col('Status', (r) {
          final s = S.vehStatus(r as Vehicle).s;
          return StatusBadge(s, tone: tone[s]);
        }, status: true, text: (r) => S.vehStatus(r as Vehicle).s),
      ],
    ),
  ]);
}

// ---------------------------------------------------------------- load templates
void newTemplateForm() {
  mform('New load template', [
    const F.header('General'),
    const F('name', 'Template Name', req: true, hint: 'Truck 12 T (24 ft)'),
    const F('weight', 'Max Weight (kg)', type: 'number', def: '12000', req: true),
    const F('volume', 'Max Volume (m3)', type: 'number', def: '48', req: true),
    F('veh_type', 'Vehicle Type', type: 'select', options: opts(['12 T Heavy', '16 T Heavy', '3.5 T Container', 'Tractor Trailer'])),
    const F('pallets', 'Max Pallets', type: 'number', def: '16'),
    const F('dims', 'Internal Dimensions (L x W x H)', hint: '7.2 x 2.4 x 2.4 m'),
    const F('use', 'Description', def: 'Regional multi-drop'),
  ], (v, _) {
    final id = 'LT-${10 + S.loadTemplates.length}T';
    S.loadTemplates.add(LoadTemplate(id, v['name'] as String, '${fmtNum(v['weight'] as num)} kg', '${v['volume']} m³', ((v['pallets'] ?? 16) as num).toInt(), (v['use'] as String).isEmpty ? 'General' : v['use'] as String));
    after(Res('Template $id saved'));
    return false;
  });
}

Widget loadTemplatesView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Trip Templates', sub: 'Vehicle capacity limits used when building loads'),
      DataTableCard(
        id: 'lt',
        rows: S.loadTemplates,
        exportName: 'load-templates',
        createLabel: 'New template',
        onCreate: newTemplateForm,
        onRow: (r) {
          final t = r as LoadTemplate;
          recPanel(t.name, '${t.id} · Trip template', [
            Kv.t('Max weight', t.weight), Kv.t('Max volume', t.volume), Kv.t('Pallet positions', '${t.pallets}'), Kv.t('Typical use', t.use),
            Kv.t('Vehicles using it', S.fleet.where((v) => v.tmpl == t.id).map((v) => v.id).join(', ').isEmpty ? 'Carrier vehicles' : S.fleet.where((v) => v.tmpl == t.id).map((v) => v.id).join(', ')),
          ]);
        },
        cols: [
          Col('Template', (r) => Text((r as LoadTemplate).id, style: tsB), text: (r) => (r as LoadTemplate).id),
          Col.t('Name', (r) => (r as LoadTemplate).name),
          Col.t('Max Weight', (r) => (r as LoadTemplate).weight),
          Col.t('Max Volume', (r) => (r as LoadTemplate).volume),
          Col.t('Pallets', (r) => '${(r as LoadTemplate).pallets}', num: true),
          Col.t('Typical Use', (r) => (r as LoadTemplate).use),
        ],
      ),
    ]);

// ---------------------------------------------------------------- carriers
void newCarrierForm() {
  mform('Add carrier', [
    const F.header('General'),
    const F('name', 'Carrier Name', req: true, hint: 'e.g. Gati KWE'),
    F('mode', 'Transport Mode', type: 'select', req: true, options: opts(['Surface · part load', 'Surface · full truck', 'Air / Surface express', 'Company trucks'])),
    const F('contact', 'Contact Person'),
    const F('phone', 'Phone'),
    const F('email', 'Email', type: 'email'),
    const F('acct', 'Our Account No.'),
    const F('url', 'Tracking URL', hint: 'https://tracking.carrier.com?awb='),
    const F('lanes', 'Lanes Served', def: 'AP & Telangana'),
    const F('rate', 'Rate Card', hint: '₹16 / kg'),
    F('status', 'Status', type: 'select', req: true, options: opts(['Active', 'Inactive'])),
  ], (v, _) {
    S.carriers.add(Carrier(S.freshId('CR0', S.carriers.map((x) => x.id)), v['name'] as String, v['mode'] as String, (v['lanes'] as String).isEmpty ? 'Pan India' : v['lanes'] as String, (v['rate'] as String).isEmpty ? 'Standard' : v['rate'] as String, 0, 0, v['status'] as String));
    after(Res('Carrier ${v['name']} added'));
    return false;
  });
}

Widget carriersView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Carriers', sub: 'Transport partners, lanes and rate cards'),
      DataTableCard(
        id: 'car',
        rows: S.carriers,
        exportName: 'carriers',
        createLabel: 'Add carrier',
        onCreate: newCarrierForm,
        onRow: (r) {
          final c = r as Carrier;
          recPanel(c.name, 'Carrier · ${c.mode}', [
            Kv.t('Mode', c.mode), Kv.t('Lanes', c.lanes), Kv.t('Rate card', c.rate), Kv.t('On-time delivery', '${c.otd}%'), Kv.t('Active shipments', '${c.active}'), Kv('Status', StatusBadge(c.status)),
          ], top: Padding(padding: const EdgeInsets.only(bottom: 14), child: Bar(c.otd.toDouble(), color: C.green)), extra: [
            TabDef('Shipments', () => partyDocs((d) => d.type == 'SHP' && d.carrier == c.name)),
          ]);
        },
        cols: [
          Col('Carrier', (r) => CellAv((r as Carrier).name, r.id), text: (r) => (r as Carrier).name),
          Col.t('Mode', (r) => (r as Carrier).mode),
          Col.t('Lanes', (r) => (r as Carrier).lanes),
          Col.t('Rate Card', (r) => (r as Carrier).rate),
          Col.t('On-Time %', (r) => '${(r as Carrier).otd}%', num: true),
          Col.t('Active', (r) => '${(r as Carrier).active}', num: true),
          Col('Status', (r) => StatusBadge((r as Carrier).status), status: true),
        ],
      ),
    ]);

// ---------------------------------------------------------------- supplier quotations
class SqRow {
  final Doc rfq;
  final Quote q;
  final int i;
  final bool best;
  SqRow(this.rfq, this.q, this.i, this.best);
  String get status => rfq.status == 'Awarded' ? (best ? 'Awarded' : 'Not selected') : 'Under review';
}

Widget supplierQuotesView() {
  final rows = <SqRow>[];
  for (final r in S.docsOf('RFQ')) {
    if (r.quotes.isEmpty) continue;
    final best = ([...r.quotes]..sort((a, b) => a.rate.compareTo(b.rate))).first;
    for (var i = 0; i < r.quotes.length; i++) {
      rows.add(SqRow(r, r.quotes[i], i, identical(r.quotes[i], best)));
    }
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Supplier Quotes', sub: 'Prices received against each RFQ, compared side by side'),
    DataTableCard(
      id: 'sq',
      createLabel: 'New supplier quotation',
      onCreate: newSupplierQuoteForm,
      rows: rows,
      exportName: 'supplier-quotations',
      onRow: (r) => openDocNav((r as SqRow).rfq.id),
      filters: [Filt('Status', const ['Under review', 'Awarded', 'Not selected'], (r) => (r as SqRow).status)],
      cols: [
        Col('Quote No.', (r) => Text('${(r as SqRow).rfq.id.replaceAll('RFQ', 'SQ')}-${r.i + 1}', style: tsB)),
        Col('RFQ', (r) => Tag((r as SqRow).rfq.id), text: (r) => (r as SqRow).rfq.id),
        Col('Supplier', (r) => CellAv(S.sup((r as SqRow).q.sup).name, S.sup(r.q.sup).city), text: (r) => S.sup((r as SqRow).q.sup).name),
        Col.t('Item', (r) => S.item((r as SqRow).rfq.lines.first.item).name),
        Col.t('Qty', (r) => '${(r as SqRow).rfq.lines.first.qty}', num: true),
        Col('Rate', (r) => Text(fmtINR((r as SqRow).q.rate), style: tsB), num: true, sort: (r) => (r as SqRow).q.rate),
        Col.t('Lead Time', (r) => '${(r as SqRow).q.lead} d', num: true),
        Col('Score', (r) => (r as SqRow).best ? const StatusBadge('Best price', tone: Tone.green) : const Text('—', style: TextStyle(color: C.faint))),
        Col('Status', (r) => StatusBadge((r as SqRow).status, tone: r.status == 'Under review' ? Tone.amber : r.status == 'Awarded' ? Tone.green : Tone.gray), status: true, text: (r) => (r as SqRow).status),
      ],
    ),
  ]);
}

Widget vehicleAllocationView() => vehiclesView();

Widget deliveryTrackingView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Delivery Tracking', sub: 'Real-time transit tracking status for outbound deliveries'),
      deliveryTrackingTable(),
    ]);

/// Shipments on their way and delivered (also used on Deliveries).
Widget deliveryTrackingTable() {
  final shipments = S.docsOf('SHP');
  return DataTableCard(
      id: 'dtracking-table',
      rows: shipments,
      exportName: 'delivery-tracking',
      onRow: (r) => openDocNav((r as Doc).id),
      cols: [
        Col('Shipment No.', (r) => Text((r as Doc).id, style: tsB), text: (r) => (r as Doc).id),
        Col('Customer', (r) => Text(S.partyName(r as Doc)), text: (r) => S.partyName(r as Doc)),
        Col.t('Carrier / Vehicle', (r) => '${(r as Doc).carrier ?? "Own fleet"} / ${(r as Doc).vehicle ?? "AP 31 TX 4521"}'),
        Col.t('Dispatch Date', (r) => (r as Doc).date),
        Col.t('Expected Delivery', (r) => (r as Doc).eta ?? (r as Doc).date),
        Col('Status', (r) => StatusBadge((r as Doc).status, tone: (r as Doc).status == 'Delivered' ? Tone.green : Tone.blue), status: true),
      ],
  );
}

// ---------------------------------------------------------------- drivers
class Driver {
  String name, phone, licence, expiry, address, status;
  Driver(this.name, this.phone, this.licence, this.expiry, this.address, this.status);
}

/// Seeded from the drivers already named on the fleet.
final List<Driver> drivers = [
  for (var i = 0; i < S.fleet.length; i++)
    if (S.fleet[i].driver.trim().isNotEmpty && S.fleet[i].driver != '—')
      Driver(S.fleet[i].driver, '+91 98480 ${(21450 + i * 137).toString().padLeft(5, '0')}', 'AP${31 + i}20${18 + i}000${4521 + i}', addDays(todayStr(), 400 + i * 150), S.wh(S.fleet[i].wh).city, 'Active'),
];

void newDriverForm() {
  mform('New driver', [

    const F.header('Driver'),
    const F('name', 'Driver Name', req: true),
    const F('phone', 'Mobile No.', def: '+91 ', req: true),
    const F('licence', 'Licence No.', req: true, hint: 'e.g. AP3120190004521'),
    F('expiry', 'Licence Expiry', type: 'date', def: addDays(todayStr(), 365)),
    const F('address', 'Address', full: true),
    F('status', 'Status', type: 'select', options: opts(['Active', 'On Leave', 'Inactive'])),
  ], (v, _) {
    if ((v['expiry'] as String).compareTo(todayStr()) < 0) {
      toast('Licence has already expired');
      return false;
    }
    drivers.add(Driver(v['name'] as String, v['phone'] as String, v['licence'] as String, v['expiry'] as String, v['address'] as String, v['status'] as String));
    after(Res('Driver ${v['name']} added'));
    return false;
  }, btn: 'Save driver');
}

void openDriver(Driver d) {
  final vehicle = S.fleet.where((f) => f.driver == d.name).map((f) => f.name).join(', ');
  recPanel(d.name, 'Driver', [
    Kv.t('Phone', d.phone),
    Kv.t('Licence No.', d.licence),
    Kv.t('Licence Expiry', d.expiry),
    Kv.t('Address', d.address.isEmpty ? '—' : d.address),
    Kv.t('Vehicle', vehicle.isEmpty ? 'Not assigned' : vehicle),
    Kv.t('Status', d.status),
  ], footer: (_) => [Btn.secondary('Edit', icon: 'edit', onTap: () { closeAll(); editDriver(d); }),deleteBtn(() => deleteDriver(d)),]);
}

Widget driversView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Drivers', sub: 'Drivers, licences and expiry dates'),
      DataTableCard(
        id: 'drv',
        rows: drivers,
        exportName: 'drivers',
        createLabel: 'New driver',
        onCreate: newDriverForm,
        onRow: (r) => openDriver(r as Driver),
        cols: [
          Col('Driver', (r) => CellAv((r as Driver).name, r.phone), text: (r) => (r as Driver).name),
          Col.t('Licence No.', (r) => (r as Driver).licence),
          Col('Licence Expiry', (r) {
            final d = r as Driver;
            final soon = daysBetween(todayStr(), d.expiry) <= 30;
            return Text(d.expiry, style: TextStyle(color: soon ? C.red : C.text, fontWeight: soon ? FontWeight.w700 : FontWeight.w400));
          }, text: (r) => (r as Driver).expiry),
          Col.t('Vehicle', (r) => S.fleet.where((f) => f.driver == (r as Driver).name).map((f) => f.name.split(' (').first).join(', ')),
          Col('Status', (r) => StatusBadge((r as Driver).status, tone: (r as Driver).status == 'Active' ? Tone.green : Tone.gray), status: true),
        ],
      ),
    ]);
