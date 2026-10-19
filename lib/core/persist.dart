part of 'store.dart';

/// Optional browser-side save of the whole app state. It is SWITCHED OFF: the app has no backend, so every start begins
/// from the standard data. To switch it on again, call S.loadSaved() and set AppStore.persistOn = true in main().
///
/// This is a browser-side save, not a shared database: each browser keeps its own data. Switching to a real
/// backend later means replacing [AppStore.loadSaved] and [AppStore._save] with API calls.

const _kSaveKey = 'impacgo_chain_data_v1';

typedef _J = Map<String, dynamic>;

double _pd(Object? x) => (x as num).toDouble();
List<T> _pl<T>(Object? x, T Function(_J) f) => [for (final e in (x as List? ?? const [])) f((e as Map).cast<String, dynamic>())];
List<String> _pls(Object? x) => [for (final e in (x as List? ?? const [])) e as String];

/// State that lives outside the store (a list kept by a screen). A screen registers its list here so it is saved too.
class PersistExtra {
  final String key;
  final Object? Function() save;
  final void Function(Object? data) load;
  PersistExtra(this.key, this.save, this.load);
}

final List<PersistExtra> persistExtras = [];

// ---------------------------------------------------------------- records
_J _line(Line l) => {'item': l.item, 'qty': l.qty, 'rate': l.rate, 'recv': l.recv, 'desc': l.desc, 'bin': l.bin, 'batch': l.batch, 'from': l.from, 'sys': l.sys, 'cnt': l.cnt, 'acc': l.acc};
Line _unLine(_J j) => Line(j['item'], j['qty'], _pd(j['rate']), recv: j['recv'] ?? 0, bin: j['bin'] ?? '', batch: j['batch'] ?? '', from: j['from'] ?? '', sys: j['sys'], cnt: j['cnt'], acc: j['acc'] ?? 0)..desc = j['desc'];

/// The optional text fields of a document: name → (read, write).
final Map<String, (String? Function(Doc), void Function(Doc, String?))> _docText = {
  'party': ((d) => d.party, (d, v) => d.party = v),
  'to': ((d) => d.to, (d, v) => d.to = v),
  'ref': ((d) => d.ref, (d, v) => d.ref = v),
  'by': ((d) => d.by, (d, v) => d.by = v),
  'delivery': ((d) => d.delivery, (d, v) => d.delivery = v),
  'valid': ((d) => d.valid, (d, v) => d.valid = v),
  'need': ((d) => d.need, (d, v) => d.need = v),
  'source': ((d) => d.source, (d, v) => d.source = v),
  'due': ((d) => d.due, (d, v) => d.due = v),
  'irn': ((d) => d.irn, (d, v) => d.irn = v),
  'eway': ((d) => d.eway, (d, v) => d.eway = v),
  'supInv': ((d) => d.supInv, (d, v) => d.supInv = v),
  'challan': ((d) => d.challan, (d, v) => d.challan = v),
  'wave': ((d) => d.wave, (d, v) => d.wave = v),
  'picker': ((d) => d.picker, (d, v) => d.picker = v),
  'billTo': ((d) => d.billTo, (d, v) => d.billTo = v),
  'shipTo': ((d) => d.shipTo, (d, v) => d.shipTo = v),
  'shipState': ((d) => d.shipState, (d, v) => d.shipState = v),
  'custPo': ((d) => d.custPo, (d, v) => d.custPo = v),
  'transferredBy': ((d) => d.transferredBy, (d, v) => d.transferredBy = v),
  'receivedBy': ((d) => d.receivedBy, (d, v) => d.receivedBy = v),
  'approvedBy': ((d) => d.approvedBy, (d, v) => d.approvedBy = v),
  'purpose': ((d) => d.purpose, (d, v) => d.purpose = v),
  'requester': ((d) => d.requester, (d, v) => d.requester = v),
  'dept': ((d) => d.dept, (d, v) => d.dept = v),
  'qcBy': ((d) => d.qcBy, (d, v) => d.qcBy = v),
  'qcResult': ((d) => d.qcResult, (d, v) => d.qcResult = v),
  'qcNote': ((d) => d.qcNote, (d, v) => d.qcNote = v),
  'qcDate': ((d) => d.qcDate, (d, v) => d.qcDate = v),
  'qcSent': ((d) => d.qcSent, (d, v) => d.qcSent = v),
  'carrier': ((d) => d.carrier, (d, v) => d.carrier = v),
  'vehicle': ((d) => d.vehicle, (d, v) => d.vehicle = v),
  'awb': ((d) => d.awb, (d, v) => d.awb = v),
  'eta': ((d) => d.eta, (d, v) => d.eta = v),
  'pod': ((d) => d.pod, (d, v) => d.pod = v),
  'route': ((d) => d.route, (d, v) => d.route = v),
  'reason': ((d) => d.reason, (d, v) => d.reason = v),
  'zone': ((d) => d.zone, (d, v) => d.zone = v),
  'counter': ((d) => d.counter, (d, v) => d.counter = v),
  'mode': ((d) => d.mode, (d, v) => d.mode = v),
  'utr': ((d) => d.utr, (d, v) => d.utr = v),
  'hold': ((d) => d.hold, (d, v) => d.hold = v),
  'note': ((d) => d.note, (d, v) => d.note = v),
  'close': ((d) => d.close, (d, v) => d.close = v),
  'weight': ((d) => d.weight, (d, v) => d.weight = v),
};

_J _doc(Doc d) => {
      'id': d.id, 'type': d.type, 'date': d.date, 'wh': d.wh, 'status': d.status,
      'lines': [for (final l in d.lines) _line(l)],
      'refs': d.refs,
      'log': [for (final e in d.log) {'when': e.when, 'who': e.who, 'what': e.what, 'icon': e.icon}],
      'amount': d.amount, 'paid': d.paid,
      'text': {for (final e in _docText.entries) if (e.value.$1(d) != null) e.key: e.value.$1(d)},
      'extra': d.extra, 'cartons': d.cartons, 'util': d.util, 'dns': d.dns,
      'quotes': [for (final q in d.quotes) {'sup': q.sup, 'rate': q.rate, 'lead': q.lead, 'valid': q.valid}],
      'invited': d.invited,
      'match': d.match == null ? null : {'ok': d.match!.ok, 'msg': d.match!.msg},
      'reserved': d.reserved,
    };

Doc _unDoc(_J j) {
  final d = Doc(id: j['id'], type: j['type'], date: j['date'], wh: j['wh'], status: j['status'], lines: _pl(j['lines'], _unLine));
  d.refs = _pls(j['refs']);
  d.log = _pl(j['log'], (e) => LogEntry(e['when'], e['who'], e['what'], e['icon']));
  d.amount = _pd(j['amount']);
  d.paid = _pd(j['paid']);
  final text = (j['text'] as Map? ?? const {}).cast<String, dynamic>();
  for (final e in _docText.entries) {
    if (text[e.key] != null) e.value.$2(d, text[e.key] as String);
  }
  d.extra = (j['extra'] as Map? ?? const {}).cast<String, String>();
  d.cartons = j['cartons'];
  d.util = j['util'];
  d.dns = _pls(j['dns']);
  d.quotes = _pl(j['quotes'], (q) => Quote(q['sup'], _pd(q['rate']), q['lead'], q['valid']));
  d.invited = _pls(j['invited']);
  final m = j['match'] as Map?;
  d.match = m == null ? null : MatchResult(m['ok'] as bool, m['msg'] as String);
  d.reserved = j['reserved'] == true;
  return d;
}

extension Persist on AppStore {
  // ---------------------------------------------------------------- everything → JSON
  _J _snapshot() => {
        'v': 1,
        // data saved by this version has had the old Buy test records removed (see _restore)
        'buyCleaned': true,
        'currentWh': currentWh.id,
        'params': {
          'soApproval': params.soApproval, 'poApproval': params.poApproval, 'adjApproval': params.adjApproval, 'ewayLimit': params.ewayLimit, 'matchTolerance': params.matchTolerance,
          'creditCheck': params.creditCheck, 'pickStrategy': params.pickStrategy, 'autoReserve': params.autoReserve, 'autoInvoice': params.autoInvoice, 'autoPutaway': params.autoPutaway,
          'reorderRun': params.reorderRun, 'numbering': params.numbering, 'currency': params.currency, 'fy': params.fy,
        },
        'dt': {for (final e in dt.entries) e.key: {'prefix': e.value.prefix, 'seq': e.value.seq}},
        'seriesList': [for (final x in seriesList) {'key': x.key, 'prefix': x.prefix, 'seq': x.seq}],
        'warehouses': [for (final w in warehouses) {'id': w.id, 'code': w.code, 'name': w.name, 'city': w.city, 'state': w.state, 'gstin': w.gstin, 'manager': w.manager, 'type': w.type, 'area': w.area, 'docks': w.docks, 'status': w.status, 'wms': w.wms, 'branch': w.branch, 'site': w.site}],
        'bins': [for (final b in bins) {'wh': b.wh, 'code': b.code, 'zone': b.zone, 'type': b.type, 'cap': b.cap, 'use': b.use, 'status': b.status}],
        'customers': [for (final c in customers) {'id': c.id, 'name': c.name, 'city': c.city, 'state': c.state, 'gstin': c.gstin, 'group': c.group, 'terms': c.terms, 'limit': c.limit, 'contact': c.contact, 'phone': c.phone, 'status': c.status, 'email': c.email, 'billTo': c.billTo, 'shipTo': c.shipTo, 'gstType': c.gstType}],
        'addresses': {for (final e in _addresses.entries) e.key: [for (final a in e.value) {'label': a.label, 'type': a.type, 'line': a.line, 'city': a.city, 'state': a.state, 'pin': a.pin}]},
        'suppliers': [for (final s in suppliers) {'id': s.id, 'name': s.name, 'city': s.city, 'state': s.state, 'gstin': s.gstin, 'terms': s.terms, 'lead': s.lead, 'otd': s.otd, 'quality': s.quality, 'rating': s.rating, 'contact': s.contact, 'status': s.status, 'phone': s.phone, 'email': s.email, 'address': s.address, 'gstType': s.gstType}],
        'categories': categories,
        'items': [for (final p in items) {'id': p.id, 'name': p.name, 'cat': p.cat, 'hsn': p.hsn, 'gst': p.gst, 'uom': p.uom, 'cost': p.cost, 'price': p.price, 'reorder': p.reorder, 'moq': p.moq, 'mult': p.mult, 'lead': p.lead, 'sup': p.sup, 'track': p.track, 'stock': p.stock, 'type': p.type, 'status': p.status, 'shelfLife': p.shelfLife}],
        'priceLists': [for (final p in priceLists) {'id': p.id, 'name': p.name, 'group': p.group, 'disc': p.disc, 'valid': p.valid, 'status': p.status}],
        'tradeAgreements': [for (final t in tradeAgreements) {'id': t.id, 'kind': t.kind, 'party': t.party, 'item': t.item, 'price': t.price, 'from': t.from, 'to': t.to, 'minQty': t.minQty, 'status': t.status}],
        'carriers': [for (final c in carriers) {'id': c.id, 'name': c.name, 'mode': c.mode, 'lanes': c.lanes, 'rate': c.rate, 'otd': c.otd, 'active': c.active, 'status': c.status}],
        'vehicles': vehicles,
        'branches': [for (final b in branches) {'name': b.name, 'company': b.company, 'city': b.city, 'state': b.state, 'postal': b.postal, 'taxReg': b.taxReg, 'manager': b.manager, 'address': b.address, 'phone': b.phone, 'email': b.email, 'status': b.status}],
        'currencies': [for (final c in currencies) {'code': c.code, 'name': c.name, 'symbol': c.symbol, 'rate': c.rate, 'decimals': c.decimals, 'status': c.status}],
        'payTerms': [for (final t in payTerms) {'name': t.name, 'days': t.days, 'advance': t.advance, 'discDays': t.discDays, 'discPct': t.discPct, 'desc': t.desc, 'status': t.status}],
        'taxCodes': [for (final t in taxCodes) {'name': t.name, 'rate': t.rate, 'type': t.type, 'status': t.status}],
        'tcTemplates': [for (final t in tcTemplates) {'name': t.name, 'applies': t.applies, 'text': t.text, 'status': t.status}],
        'stock': {for (final w in stock.entries) w.key: {for (final i in w.value.entries) i.key: [i.value.onhand, i.value.reserved, i.value.transit]}},
        'ledger': [for (final e in ledger) {'date': e.date, 'time': e.time, 'wh': e.wh, 'item': e.item, 'type': e.type, 'qty': e.qty, 'bal': e.bal, 'ref': e.ref, 'who': e.who, 'value': e.value}],
        'docs': [for (final d in docs) _doc(d)],
        'batches': [for (final b in batches) {'id': b.id, 'item': b.item, 'wh': b.wh, 'qty': b.qty, 'mfg': b.mfg, 'exp': b.exp, 'sup': b.sup, 'status': b.status}],
        'serials': [for (final s in serials) {'id': s.id, 'item': s.item, 'wh': s.wh, 'status': s.status, 'ref': s.ref}],
        'territories': [for (final t in territories) {'id': t.id, 'name': t.name, 'states': t.states, 'cities': t.cities, 'manager': t.manager, 'wh': t.wh, 'code': t.code, 'parent': t.parent, 'country': t.country, 'status': t.status, 'targetRev': t.targetRev}],
        'terrOf': terrOf,
        'salesPersons': [for (final s in salesPersons) {'id': s.id, 'name': s.name, 'terr': s.terr, 'phone': s.phone, 'target': s.target, 'status': s.status, 'email': s.email}],
        'contacts': [for (final c in contacts) {'name': c.name, 'cust': c.cust, 'role': c.role, 'phone': c.phone, 'email': c.email, 'primary': c.primary}],
        'leads': [for (final l in leads) {'id': l.id, 'company': l.company, 'contact': l.contact, 'city': l.city, 'state': l.state, 'source': l.source, 'owner': l.owner, 'value': l.value, 'date': l.date, 'status': l.status, 'interest': l.interest, 'opp': l.opp, 'lostReason': l.lostReason, 'phone': l.phone, 'email': l.email}],
        'opps': [for (final o in opps) {'id': o.id, 'party': o.party, 'title': o.title, 'owner': o.owner, 'value': o.value, 'prob': o.prob, 'close': o.close, 'stage': o.stage, 'lines': [for (final l in o.lines) {'item': l.item, 'qty': l.qty}], 'quote': o.quote, 'lead': o.lead, 'lostReason': o.lostReason}],
        'customerGroups': [for (final g in customerGroups) {'id': g.id, 'name': g.name, 'price': g.price, 'terms': g.terms, 'credit': g.credit, 'desc': g.desc, 'parent': g.parent, 'status': g.status}],
        'supplierGroups': [for (final g in supplierGroups) {'id': g.id, 'name': g.name, 'terms': g.terms, 'members': g.members, 'desc': g.desc}],
        'uoms': [for (final u in uoms) {'code': u.code, 'name': u.name, 'type': u.type, 'base': u.base, 'factor': u.factor}],
        'trackGroups': [for (final g in trackGroups) {'id': g.id, 'name': g.name, 'batch': g.batch, 'serial': g.serial, 'expiry': g.expiry, 'desc': g.desc}],
        'storageGroups': [for (final g in storageGroups) {'id': g.id, 'name': g.name, 'site': g.site, 'wh': g.wh, 'loc': g.loc, 'desc': g.desc}],
        'sites': [for (final s in sites) {'id': s.id, 'name': s.name, 'gstin': s.gstin, 'whs': s.whs, 'address': s.address}],
        'moves': [for (final m in moves) {'id': m.id, 'date': m.date, 'wh': m.wh, 'item': m.item, 'from': m.from, 'to': m.to, 'qty': m.qty, 'reason': m.reason, 'status': m.status, 'by': m.by}],
        'fleet': [for (final v in fleet) {'id': v.id, 'name': v.name, 'type': v.type, 'wh': v.wh, 'driver': v.driver, 'cap': v.cap, 'tmpl': v.tmpl, 'status': v.status, 'own': v.own}],
        'loadTemplates': [for (final t in loadTemplates) {'id': t.id, 'name': t.name, 'weight': t.weight, 'volume': t.volume, 'pallets': t.pallets, 'use': t.use}],
        'autoLog': [for (final a in autoLog) {'when': a.when, 'job': a.job, 'result': a.result, 'docs': a.docs, 'by': a.by}],
        'emails': [for (final e in emails) {'when': e.when, 'to': e.to, 'subject': e.subject, 'doc': e.doc, 'status': e.status}],
        'reportSchedules': [for (final r in reportSchedules) {'id': r.id, 'report': r.report, 'freq': r.freq, 'to': r.to, 'format': r.format, 'status': r.status}],
        'valuations': [for (final v in valuations) {'month': v.month, 'when': v.when, 'value': v.value, 'items': v.items}],
        'jobs': {for (final j in jobs) j.id: {'status': j.status, 'last': j.last, 'result': j.result}},
        'extras': {for (final x in persistExtras) x.key: x.save()},
      };

  // ---------------------------------------------------------------- JSON → everything
  void _restore(_J j) {
    final p = (j['params'] as Map).cast<String, dynamic>();
    params
      ..soApproval = _pd(p['soApproval'])
      ..poApproval = _pd(p['poApproval'])
      ..adjApproval = _pd(p['adjApproval'])
      ..ewayLimit = _pd(p['ewayLimit'])
      ..matchTolerance = _pd(p['matchTolerance'])
      ..creditCheck = p['creditCheck']
      ..pickStrategy = p['pickStrategy']
      ..autoReserve = p['autoReserve']
      ..autoInvoice = p['autoInvoice']
      ..autoPutaway = p['autoPutaway']
      ..reorderRun = p['reorderRun']
      ..numbering = p['numbering']
      ..currency = p['currency']
      ..fy = p['fy'];
    for (final e in (j['dt'] as Map).entries) {
      final t = dt[e.key];
      if (t != null) {
        t.prefix = e.value['prefix'];
        t.seq = e.value['seq'];
      }
    }
    void fill<T>(List<T> list, String key, T Function(_J) f) => list
      ..clear()
      ..addAll(_pl(j[key], f));

    fill(seriesList, 'seriesList', (x) => SeriesEntry(x['key'], x['prefix'], x['seq']));
    fill(warehouses, 'warehouses', (w) => Warehouse(w['id'], w['code'], w['name'], w['city'], w['state'], w['gstin'], w['manager'], w['type'], w['area'], w['docks'], w['status'], w['wms'], branch: w['branch'] ?? '', site: w['site'] ?? ''));
    fill(bins, 'bins', (b) => Bin(b['wh'], b['code'], b['zone'], b['type'], b['cap'], b['use'])..status = b['status'] ?? 'Active');
    fill(customers, 'customers', (c) => Customer(c['id'], c['name'], c['city'], c['state'], c['gstin'], c['group'], c['terms'], _pd(c['limit']), c['contact'], c['phone'], c['status'])
      ..email = c['email'] ?? ''
      ..billTo = c['billTo'] ?? ''
      ..shipTo = c['shipTo'] ?? ''
      ..gstType = c['gstType'] ?? 'Registered');
    _addresses
      ..clear()
      ..addAll({
        for (final e in (j['addresses'] as Map).entries) e.key as String: _pl(e.value, (a) => Address(a['label'], a['type'], a['line'], a['city'], a['state'], a['pin']))
      });
    fill(suppliers, 'suppliers', (s) => Supplier(s['id'], s['name'], s['city'], s['state'], s['gstin'], s['terms'], s['lead'], s['otd'], s['quality'], _pd(s['rating']), s['contact'], s['status'])
      ..phone = s['phone'] ?? ''
      ..email = s['email'] ?? ''
      ..address = s['address'] ?? ''
      ..gstType = s['gstType'] ?? 'Registered');
    categories
      ..clear()
      ..addAll(_pls(j['categories']));
    fill(items, 'items', (p) => Item(p['id'], p['name'], p['cat'], p['hsn'], p['gst'], p['uom'], _pd(p['cost']), _pd(p['price']), p['reorder'], p['moq'], p['mult'], p['lead'], p['sup'], p['track'], [for (final x in p['stock'] as List) x as int])
      ..type = p['type'] ?? 'Goods'
      ..status = p['status'] ?? 'Active'
      ..shelfLife = p['shelfLife'] ?? 0);
    fill(priceLists, 'priceLists', (p) => PriceList(p['id'], p['name'], p['group'], p['disc'], p['valid'], p['status']));
    fill(tradeAgreements, 'tradeAgreements', (t) => TradeAgreement(t['id'], t['kind'], t['party'], t['item'], _pd(t['price']), t['from'], t['to'], t['minQty'], t['status']));
    fill(carriers, 'carriers', (c) => Carrier(c['id'], c['name'], c['mode'], c['lanes'], c['rate'], c['otd'], c['active'], c['status']));
    vehicles
      ..clear()
      ..addAll(_pls(j['vehicles']));
    fill(branches, 'branches', (b) => Branch(b['name'], company: b['company'], city: b['city'], state: b['state'], postal: b['postal'], taxReg: b['taxReg'], manager: b['manager'], address: b['address'], phone: b['phone'], email: b['email'], status: b['status']));
    fill(currencies, 'currencies', (c) => Currency(c['code'], c['name'], c['symbol'], _pd(c['rate']), decimals: c['decimals'], status: c['status']));
    fill(payTerms, 'payTerms', (t) => PayTerm(t['name'], t['days'], advance: t['advance'], discDays: t['discDays'], discPct: _pd(t['discPct']), desc: t['desc'], status: t['status']));
    fill(taxCodes, 'taxCodes', (t) => TaxCode(t['name'], _pd(t['rate']), type: t['type'], status: t['status']));
    fill(tcTemplates, 'tcTemplates', (t) => TcTemplate(t['name'], t['applies'], t['text'], status: t['status']));
    stock
      ..clear()
      ..addAll({
        for (final w in (j['stock'] as Map).entries)
          w.key as String: {for (final i in (w.value as Map).entries) i.key as String: StockCell((i.value as List)[0], reserved: (i.value as List)[1], transit: (i.value as List)[2])}
      });
    fill(ledger, 'ledger', (e) => LedgerEntry(e['date'], e['time'], e['wh'], e['item'], e['type'], e['qty'], e['bal'], e['ref'], e['who'], _pd(e['value'])));
    fill(docs, 'docs', _unDoc);
    fill(batches, 'batches', (b) => Batch(b['id'], b['item'], b['wh'], b['qty'], b['mfg'], b['exp'], b['sup'], b['status']));
    fill(serials, 'serials', (s) => Serial(s['id'], s['item'], s['wh'], s['status'], s['ref']));
    fill(territories, 'territories', (t) => Territory(t['id'], t['name'], t['states'], t['cities'], t['manager'], t['wh'])
      ..code = t['code'] ?? ''
      ..parent = t['parent'] ?? '—'
      ..country = t['country'] ?? 'India'
      ..status = t['status'] ?? 'Active'
      ..targetRev = _pd(t['targetRev'] ?? 0));
    terrOf
      ..clear()
      ..addAll((j['terrOf'] as Map).cast<String, String>());
    fill(salesPersons, 'salesPersons', (s) => SalesPerson(s['id'], s['name'], s['terr'], s['phone'], _pd(s['target']), s['status'])..email = s['email'] ?? '');
    fill(contacts, 'contacts', (c) => Contact(c['name'], c['cust'], c['role'], c['phone'], c['email'], c['primary']));
    fill(leads, 'leads', (l) => Lead(l['id'], l['company'], l['contact'], l['city'], l['state'], l['source'], l['owner'], _pd(l['value']), l['date'], l['status'], l['interest'])
      ..opp = l['opp']
      ..lostReason = l['lostReason']
      ..phone = l['phone'] ?? ''
      ..email = l['email'] ?? '');
    fill(opps, 'opps', (o) => Opportunity(o['id'], o['party'], o['title'], o['owner'], _pd(o['value']), o['prob'], o['close'], o['stage'], _pl(o['lines'], (l) => OppLine(l['item'], l['qty'])), quote: o['quote'], lead: o['lead'])..lostReason = o['lostReason']);
    fill(customerGroups, 'customerGroups', (g) => CustomerGroup(g['id'], g['name'], g['price'], g['terms'], _pd(g['credit']), g['desc'])
      ..parent = g['parent'] ?? ''
      ..status = g['status'] ?? 'Active');
    fill(supplierGroups, 'supplierGroups', (g) => SupplierGroup(g['id'], g['name'], g['terms'], _pls(g['members']), g['desc']));
    fill(uoms, 'uoms', (u) => Uom(u['code'], u['name'], u['type'], u['base'], _pd(u['factor'])));
    fill(trackGroups, 'trackGroups', (g) => TrackGroup(g['id'], g['name'], g['batch'], g['serial'], g['expiry'], g['desc']));
    fill(storageGroups, 'storageGroups', (g) => StorageGroup(g['id'], g['name'], g['site'], g['wh'], g['loc'], g['desc']));
    fill(sites, 'sites', (s) => Site(s['id'], s['name'], s['gstin'], _pls(s['whs']), s['address']));
    fill(moves, 'moves', (m) => BinMove(m['id'], m['date'], m['wh'], m['item'], m['from'], m['to'], m['qty'], m['reason'], m['status'], m['by']));
    fill(fleet, 'fleet', (v) => Vehicle(v['id'], v['name'], v['type'], v['wh'], v['driver'], v['cap'], v['tmpl'])
      ..status = v['status'] ?? 'Available'
      ..own = v['own'] ?? 'Own');
    fill(loadTemplates, 'loadTemplates', (t) => LoadTemplate(t['id'], t['name'], t['weight'], t['volume'], t['pallets'], t['use']));
    fill(autoLog, 'autoLog', (a) => AutoLog(a['when'], a['job'], a['result'], a['docs'], a['by']));
    fill(emails, 'emails', (e) => Email(e['when'], e['to'], e['subject'], e['doc'], e['status']));
    fill(reportSchedules, 'reportSchedules', (r) => ReportSchedule(r['id'], r['report'], r['freq'], r['to'], r['format'], r['status']));
    fill(valuations, 'valuations', (v) => Valuation(v['month'], v['when'], _pd(v['value']), v['items']));
    final js = (j['jobs'] as Map).cast<String, dynamic>();
    for (final job in jobs) {
      final s = js[job.id] as Map?;
      if (s != null) {
        job.status = s['status'];
        job.last = s['last'];
        job.result = s['result'];
      }
    }
    final ex = (j['extras'] as Map? ?? const {}).cast<String, dynamic>();
    for (final x in persistExtras) {
      if (ex.containsKey(x.key)) x.load(ex[x.key]);
    }
    currentWh = warehouses.firstWhere((w) => w.id == j['currentWh'], orElse: () => warehouses.first);
    // data saved by an older version: the Buy records in it are old test records, removed once so Buy starts empty
    if (j['buyCleaned'] != true) clearBuyRecords();
  }

  // ---------------------------------------------------------------- saving and loading
  /// The whole app state as text (used by the save, and by tests to check a save → load round trip).
  String snapshotText() => jsonEncode(_snapshot());

  /// Loads a state produced by [snapshotText].
  void restoreFromText(String text) => _restore((jsonDecode(text) as Map).cast<String, dynamic>());

  /// Loads the state saved in this browser, if there is one. Called once when the app starts.
  void loadSaved() {
    final text = persistStore.readSaved(_kSaveKey);
    if (text == null || text.isEmpty) return;
    try {
      _restore((jsonDecode(text) as Map).cast<String, dynamic>());
    } catch (e) {
      // the save does not fit this version of the app: forget it and start from the standard data
      debugPrint('Saved data could not be loaded ($e) — starting fresh');
      persistStore.clearSaved(_kSaveKey);
      persistStore.reloadApp();
    }
  }

  /// Saves a moment after the last change (many changes in a row make one save).
  void scheduleSave() {
    if (!AppStore.persistOn) return;
    AppStore._saveTimer?.cancel();
    AppStore._saveTimer = Timer(const Duration(milliseconds: 600), saveNow);
  }

  void saveNow() {
    try {
      persistStore.writeSaved(_kSaveKey, snapshotText());
    } catch (e) {
      debugPrint('Could not save data: $e');
    }
  }

  /// Starts the app over, like pressing F5: the page reloads, so every screen, form and list is as freshly opened and the app
  /// lands on the SCM Workspace. (An editor's restart button cannot do this for a release build: it leaves the page as it is.)
  void restartApp() {
    view = 'workspace';
    persistStore.reloadApp();
    notifyListeners();
  }

  /// Removes whatever was saved in this browser. Saving is switched off (AppStore.persistOn stays false), so the app
  /// starts from the standard data every time; this also clears data saved by an earlier version.
  void forgetSaved() => persistStore.clearSaved(_kSaveKey);

  /// Forgets everything saved in this browser and starts again from the standard data.
  void resetData() {
    AppStore._saveTimer?.cancel();
    AppStore.persistOn = false;
    persistStore.clearSaved(_kSaveKey);
    persistStore.reloadApp();
  }
}
