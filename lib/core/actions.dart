part of 'store.dart';

/// Every business action of the SCM flow. Each returns a [Res] with a toast
/// message and (optionally) the document the UI should open next.
extension ScmActions on AppStore {
  // ============================ CLEAR BUY RECORDS ============================
  static const _buyTypes = {'PR', 'RFQ', 'PO', 'GRN', 'PA', 'PI', 'SP', 'PRT', 'DBN'};

  /// Removes every buying record: requests, RFQs, purchase orders, goods receipts, bin allocations, purchase invoices,
  /// supplier payments, purchase returns and debit notes. The stock those documents added or took out is put back
  /// as it was, the running balances in the stock ledger are worked out again, and the buying numbers start from 0001.
  /// Masters (suppliers, items, price lists) and every sales record stay. Returns how many documents were removed.
  int clearBuyRecords() {
    final gone = {for (final d in docs) if (_buyTypes.contains(d.type)) d.id};
    if (gone.isEmpty) return 0;
    final grnLines = [for (final d in docs) if (d.type == 'GRN') ...d.lines.map((l) => (d.wh, l.item, l.batch))];

    // stock: undo what those documents posted
    for (final e in ledger.where((e) => gone.contains(e.ref))) {
      stk(e.wh, e.item).onhand -= e.qty;
    }
    ledger.removeWhere((e) => gone.contains(e.ref));
    // the ledger is newest first: the balance after each remaining entry is rebuilt from the stock now on hand
    final groups = <String, List<LedgerEntry>>{};
    for (final e in ledger.reversed) {
      (groups['${e.wh}|${e.item}'] ??= []).add(e);
    }
    for (final g in groups.values) {
      int run = stk(g.first.wh, g.first.item).onhand - g.fold<int>(0, (a, e) => a + e.qty);
      for (final e in g) {
        run += e.qty;
        e.bal = run;
      }
    }

    // batches and serial numbers that came in on those goods receipts
    for (final x in grnLines) {
      if (x.$3.isNotEmpty) batches.removeWhere((b) => b.id == x.$3 && b.item == x.$2 && b.wh == x.$1 && b.sup.isNotEmpty);
    }
    serials.removeWhere((sn) => gone.contains(sn.ref));

    docs.removeWhere((d) => gone.contains(d.id));
    for (final d in docs) {
      d.refs.removeWhere(gone.contains);
    }
    emails.removeWhere((m) => gone.contains(m.doc));
    for (final t in _buyTypes) {
      dt[t]?.seq = 0;
    }
    return gone.length;
  }

  // ============================ SALES ============================
  Res reject(String id, [String? reason]) {
    final d = doc(id)!;
    if (reason != null && reason.isNotEmpty) d.reason = reason;
    setStatus(d, 'Rejected', Users.mgr, reason != null ? 'Reason: $reason' : null);
    return Res('$id rejected${reason != null ? ' · Reason: $reason' : ''}', id);
  }

  Res qtSend(String id, [String? email]) {
    final d = doc(id)!;
    final to = email == null || email.trim().isEmpty ? emailOfCust(d.party!) : email.trim();
    sendEmail(to, 'Quotation $id from IMPACGO Chain (PDF attached)', id);
    setStatus(d, 'Sent', Users.sales, 'PDF emailed to $to');
    return Res('Quotation PDF emailed to $to', id);
  }

  /// A sales order was created (and possibly changed) on the form opened from this accepted quotation.
  Res qtOrdered(String qtId, String soId) {
    final qt = doc(qtId)!, so = doc(soId)!;
    so.ref = qtId;
    logDoc(so, 'Created from $qtId', Users.sales);
    setStatus(qt, 'Converted', Users.sales, '→ ${so.id}');
    link(qt, so);
    for (final o in opps.where((o) => o.quote == qtId && o.stage != 'Won')) {
      o.stage = 'Won';
      o.prob = 100;
    }
    return Res('${so.id} created from $qtId · ${so.status}', so.id);
  }

  Res qtAccept(String id) {
    setStatus(doc(id)!, 'Accepted', Users.sales);
    return Res('Quotation marked accepted', id);
  }

  Res qtConvert(String id) {
    final d = doc(id)!;
    final so = createSO(d.party!, d.wh, d.lines.map((l) => l.copy()).toList(), d.id);
    setStatus(d, 'Converted', Users.sales, '→ ${so.id}');
    link(d, so);
    for (final o in opps.where((o) => o.quote == d.id && o.stage != 'Won')) {
      o.stage = 'Won';
      o.prob = 100;
    }
    return Res('${d.id} converted to ${so.id} · ${so.status}', so.id);
  }

  Doc createSO(String party, String w, List<Line> lines, String? ref) {
    final so = mk(Doc(id: '', type: 'SO', date: todayStr(), wh: w, status: 'Draft', party: party, ref: ref, by: Users.sales, lines: lines)..delivery = addDays(todayStr(), 3));
    evaluateSO(so);
    return so;
  }

  void evaluateSO(Doc so) {
    final c = cust(so.party!);
    final od = overdueInv(so.party!);
    final exp = outstanding(so.party!) + so.amount;
    if (od.isNotEmpty) {
      so.hold = 'Credit hold — ${od.first.id} overdue by ${daysBetween(od.first.due!, todayStr())} days';
      setStatus(so, 'On Hold', Users.sys, 'credit check failed');
      return;
    }
    if (exp > c.limit) {
      so.hold = 'Credit limit exceeded — exposure ${fmtINR(exp)} vs limit ${fmtINR(c.limit)}';
      setStatus(so, 'On Hold', Users.sys, 'credit check failed');
      return;
    }
    logDoc(so, 'Credit check passed · exposure ${fmtINR(exp)} of ${fmtINR(c.limit)}', Users.sys, 'eye');
    approvalSO(so);
  }

  void approvalSO(Doc so) {
    if (so.amount > params.soApproval) {
      so.note = 'Order value ${fmtINR(so.amount)} is above the ${fmtINR(params.soApproval)} approval limit';
      setStatus(so, 'Pending Approval', Users.sys);
      return;
    }
    confirmSO(so, Users.sys);
  }

  void confirmSO(Doc so, String who) {
    setStatus(so, 'Confirmed', who);
    reserveSO(so, true);
    logDoc(so, 'Stock reserved at ${wh(so.wh).code}', Users.sys);
    for (final l in so.lines) {
      if (avail(so.wh, l.item) < 0) {
        final p = item(l.item);
        final short = -avail(so.wh, l.item);
        final q = math.max(p.moq, (short / p.mult).ceil() * p.mult);
        final pr = autoPR(so.wh, l.item, q, 'Shortage on ${so.id} (auto)');
        logDoc(so, 'Shortage of $short ${p.uom} ${p.name} → ${pr.id} raised', Users.sys, 'alert');
      }
    }
  }

  Res soApprove(String id) {
    final d = doc(id)!;
    d.note = null;
    confirmSO(d, Users.mgr);
    return Res('$id approved · stock reserved', id);
  }

  Res soReleaseHold(String id) {
    final d = doc(id)!;
    logDoc(d, 'Credit hold released by manager', Users.mgr, 'edit');
    d.hold = null;
    final c = cust(d.party!);
    if (c.status == 'Credit Hold') c.status = 'Active';
    approvalSO(d);
    return Res('$id released from hold · ${d.status}', id);
  }

  Res soRelease(String id) {
    final so = doc(id)!;
    final pk = mk(Doc(id: '', type: 'PK', date: todayStr(), wh: so.wh, status: 'To Pick', party: so.party, ref: so.id,
        lines: so.lines.map((l) => (Line(l.item, l.qty, l.rate, bin: suggestBin(l.item), batch: fefoBatch(so.wh, l.item))..desc = l.desc)).toList())
      ..wave = 'WV-${919 + docsOf('PK').length - 2}'
      ..picker = 'Ravi Teja');
    link(so, pk);
    setStatus(so, 'Picking', Users.mgr, 'pick list ${pk.id} in pick batch ${pk.wave}');
    return Res('Pick list ${pk.id} created · bins and batches by earliest expiry', pk.id);
  }

  Res pkConfirm(String id) {
    final pk = doc(id)!;
    setStatus(pk, 'Picked', Users.wh);
    final pc = mk(Doc(id: '', type: 'PCK', date: todayStr(), wh: pk.wh, status: 'Packing', party: pk.party, ref: pk.ref, lines: pk.lines.map((l) => l.copy()).toList()));
    final so = pk.ref == null ? null : doc(pk.ref!);
    if (so != null) {
      link(so, pc);
      logDoc(so, 'Picked · packing slip ${pc.id} created', Users.sys);
    }
    return Res('Picked · packing slip ${pc.id} created automatically', pc.id);
  }

  Res pack(String id, int cartons, String weight) {
    final pc = doc(id)!;
    pc.cartons = cartons;
    pc.weight = weight;
    setStatus(pc, 'Packed', Users.wh, '$cartons cartons');
    final dn = mk(Doc(id: '', type: 'DN', date: todayStr(), wh: pc.wh, status: 'Ready to Dispatch', party: pc.party, ref: pc.ref, lines: pc.lines.map((l) => l.copy()).toList())
      ..cartons = cartons
      ..weight = weight);
    final so = pc.ref == null ? null : doc(pc.ref!);
    if (so != null) {
      dn.custPo = so.custPo; // the customer's PO number goes onto the delivery note
      link(so, dn);
      setStatus(so, 'Packed', Users.sys, 'delivery ${dn.id}');
    }
    Doc? ld;
    for (final l in docsOf('LD')) {
      if (l.wh == pc.wh && l.status == 'Planned') {
        ld = l;
        break;
      }
    }
    ld ??= mk(Doc(id: '', type: 'LD', date: todayStr(), wh: pc.wh, status: 'Planned')
      ..vehicle = vehicles[0]
      ..carrier = 'Own fleet'
      ..route = '${wh(pc.wh).city} → ${cust(pc.party!).city}'
      ..util = 0);
    ld.dns.add(dn.id);
    ld.lines.addAll(dn.lines.map((l) => l.copy()));
    ld.util = math.min(96, (ld.util ?? 0) + (cartons * 2.5).round());
    logDoc(ld, '${dn.id} added to load', Users.sys);
    return Res('Packed · ${dn.id} created and added to ${ld.id}', dn.id);
  }

  Doc dispatch(String id, String car, String veh, {bool fromLoad = false}) {
    final dn = doc(id)!;
    final so = dn.ref == null ? null : doc(dn.ref!);
    for (final l in dn.lines) {
      postStock(dn.wh, l.item, -l.qty, 'Sales issue', dn.id, Users.wh);
      issueTracked(dn.wh, l);
      if (so != null && so.reserved) stk(dn.wh, l.item).reserved -= l.qty;
    }
    if (so != null) so.reserved = false;
    dn.carrier = car;
    dn.vehicle = veh;
    final inv = mk(Doc(id: '', type: 'INV', date: todayStr(), wh: dn.wh, status: 'Unpaid', party: dn.party, ref: so?.id ?? dn.id, lines: dn.lines.map((l) => l.copy()).toList()));
    inv.due = addDays(inv.date, cust(dn.party!).terms);
    inv.custPo = so?.custPo ?? dn.custPo; // the customer's PO number goes onto the invoice
    inv.irn = 'IRN ${_hex4()}…${_hex4()}';
    final n = docs.length;
    // the e-way bill number typed on the dispatch form is kept; one is made up only when none was typed
    final typedEw = (dn.eway ?? '').trim();
    final ew = calc(inv).sub > params.ewayLimit
        ? (RegExp(r'^\d[\d ]{5,}$').hasMatch(typedEw) ? typedEw : 'EWB ${3220 + n} ${4400 + n} ${1000 + n}')
        : 'Not required (below ₹50,000)';
    inv.eway = ew;
    dn.eway = ew;
    logDoc(inv, 'Created automatically on dispatch of ${dn.id} · e-invoice reference generated', Users.sys);
    final shp = mk(Doc(id: '', type: 'SHP', date: todayStr(), wh: dn.wh, status: 'Booked', party: dn.party, ref: dn.id, lines: dn.lines.map((l) => l.copy()).toList())
      ..carrier = car
      ..awb = '${car.substring(0, math.min(3, car.length)).toUpperCase()} ${88200 + n} ${40000 + n}'
      ..eta = addDays(todayStr(), cust(dn.party!).state == wh(dn.wh).state ? 1 : 3));
    setStatus(dn, 'Dispatched', Users.wh, '$car · $veh');
    link(dn, inv);
    link(dn, shp);
    if (so != null) {
      link(so, inv);
      link(so, shp);
      setStatus(so, 'Invoiced', Users.sys, inv.id);
    }
    if (!fromLoad) {
      for (final ld in docsOf('LD')) {
        if (ld.dns.contains(dn.id) && ld.status != 'Dispatched') {
          ld.dns.remove(dn.id);
          logDoc(ld, '${dn.id} dispatched separately', Users.sys);
        }
      }
    }
    sendEmail(emailOfCust(inv.party!), 'Tax invoice ${inv.id} · ${fmtINR(inv.amount)}', inv.id);
    addAutoLog('Dispatch posting', 'Invoice, IRN${ew.startsWith('EWB') ? ', e-way bill' : ''} and shipment created', inv.id, 'System on dispatch');
    return inv;
  }

  String _hex4() => math.Random().nextInt(0xffff).toRadixString(16).padLeft(4, '0');

  Res dnDispatch(String id, String car, String veh) {
    final inv = dispatch(id, car, veh);
    final shp = docsOf('SHP').firstWhere((s) => s.ref == id);
    return Res('Dispatched · ${inv.id} and ${shp.id} created automatically', inv.id);
  }

  void markDelivered(String dnId, String pod) {
    final dn = doc(dnId);
    if (dn == null) return;
    if (dn.status != 'Delivered') setStatus(dn, 'Delivered', Users.sys, pod);
    for (final s in docsOf('SHP')) {
      if (s.ref == dnId && s.status != 'Delivered') {
        setStatus(s, 'Delivered', Users.sys);
        s.pod = pod;
      }
    }
    final so = dn.ref == null ? null : doc(dn.ref!);
    if (so != null && so.type == 'SO') {
      Doc? inv;
      for (final i in docsOf('INV')) {
        if (i.ref == so.id) inv = i;
      }
      setStatus(so, inv != null && inv.status == 'Paid' ? 'Closed' : 'Delivered', Users.sys);
    }
  }

  Res dnDeliver(String id) {
    markDelivered(id, 'Signed by ${cust(doc(id)!.party!).contact}');
    return Res('$id delivered · order and shipment updated', id);
  }

  bool shpAdvance(Doc s) {
    final st = dt['SHP']!.steps;
    final i = st.indexOf(s.status);
    if (i >= st.length - 1) return false;
    final n = st[i + 1];
    setStatus(s, n, '${s.carrier} API', 'tracking sync');
    if (n == 'Delivered') {
      s.pod = 'Signed by ${cust(s.party!).contact}';
      final dn = s.ref == null ? null : doc(s.ref!);
      if (dn != null && dn.type == 'DN') markDelivered(dn.id, s.pod!);
    }
    return true;
  }

  Res shpTrack(String id) {
    final s = doc(id)!;
    shpAdvance(s);
    return Res('Tracking refreshed · ${s.status}', id);
  }

  Res invPay(String id, double amount, String mode, String utr) {
    final d = doc(id)!;
    final amt = math.min(amount, d.amount - d.paid);
    if (amt <= 0) return Res('Enter an amount');
    final cp = mk(Doc(id: '', type: 'CP', date: todayStr(), wh: d.wh, status: 'Allocated', party: d.party, ref: d.id)
      ..mode = mode
      ..utr = utr, amount: amt);
    d.paid += amt;
    setStatus(d, d.paid >= d.amount - 0.5 ? 'Paid' : 'Partially Paid', Users.fin, '${fmtINR(amt)} via ${cp.id}');
    link(d, cp);
    if (d.status == 'Paid') {
      final so = d.ref == null ? null : doc(d.ref!);
      if (so != null && so.type == 'SO' && so.status == 'Delivered') setStatus(so, 'Closed', Users.sys, 'delivered and fully paid');
    }
    return Res('Payment ${cp.id} recorded · invoice ${d.status} · download the receipt here', cp.id);
  }

  Res invReturn(String id, String itemId, int qty, String reason) {
    final d = doc(id)!;
    final l = d.lines.firstWhere((x) => x.item == itemId);
    final q = math.min(qty, l.qty);
    // the return remembers the batch / serial numbers that were sold, so they can go back into stock
    final sr = mk(Doc(id: '', type: 'SR', date: todayStr(), wh: d.wh, status: 'Requested', party: d.party, ref: d.id, lines: [Line(itemId, q, l.rate, batch: l.batch)])..reason = reason);
    link(d, sr);
    return Res('Sales return ${sr.id} created', sr.id);
  }

  /// Returned goods come back: the batch quantity goes up again / the serial numbers are Available again.
  void returnTracked(String w, Line l) {
    if (l.batch.isEmpty) return;
    final p = item(l.item);
    if (p.track == 'Batch') {
      final b = batchOf(w, l.item, l.batch);
      if (b != null) b.qty += l.qty;
    } else if (p.track == 'Serial') {
      for (final sn in serialList(l.batch).take(l.qty)) {
        final s = serials.where((x) => x.id == sn && x.item == l.item).firstOrNull;
        if (s != null) {
          s.status = 'Available';
          s.wh = w;
        }
      }
    }
  }

  Res srReceive(String id) {
    final d = doc(id)!;
    for (final l in d.lines) {
      postStock(d.wh, l.item, l.qty, 'Sales return', d.id, Users.wh);
      returnTracked(d.wh, l);
    }
    setStatus(d, 'Received', Users.wh, 'goods back in stock after inspection');
    return Res('Returned goods received · stock updated', id);
  }

  Res srCredit(String id) {
    final d = doc(id)!;
    final cn = mk(Doc(id: '', type: 'CN', date: todayStr(), wh: d.wh, status: 'Issued', party: d.party, ref: d.id, lines: d.lines.map((l) => l.copy()).toList()));
    setStatus(d, 'Credited', Users.fin, cn.id);
    link(d, cn);
    final inv = d.ref == null ? null : doc(d.ref!);
    if (inv != null && inv.type == 'INV') {
      final adj = math.min(cn.amount, inv.amount - inv.paid);
      inv.paid += adj;
      if (inv.paid >= inv.amount - 0.5) inv.status = 'Paid';
      logDoc(inv, 'Credit note ${cn.id} applied · ${fmtINR(adj)}', Users.sys);
    }
    return Res('Credit note ${cn.id} issued and applied to the invoice', cn.id);
  }

  // ============================ PROCUREMENT ============================
  int openQty(String w, String itemId, Map<String, List<String>> types) {
    var n = 0;
    for (final d in docs) {
      if (d.wh == w && types[d.type] != null && types[d.type]!.contains(d.status)) {
        for (final l in d.lines) {
          if (l.item == itemId) n += l.qty - l.recv;
        }
      }
    }
    return n;
  }

  Doc autoPR(String w, String itemId, int qty, String src) {
    final p = item(itemId);
    return mk(Doc(id: '', type: 'PR', date: todayStr(), wh: w, status: 'Pending Approval', party: p.sup, by: Users.sys, lines: [Line(itemId, qty, purchasePrice(p.sup, itemId, qty).rate, sup: p.sup)])
      ..source = src
      ..need = addDays(todayStr(), p.lead));
  }

  List<Doc> runReorder() {
    final made = <Doc>[];
    for (final w in warehouses) {
      for (final p in items) {
        final pipe = openQty(w.id, p.id, {
          'PR': ['Pending Approval', 'Approved', 'RFQ Sent'],
          'PO': ['Pending Approval', 'Sent to Supplier', 'Partially Received']
        });
        final proj = avail(w.id, p.id) + pipe;
        if (proj < p.reorder) {
          var q = math.max(p.moq, p.reorder * 2 - proj);
          q = (q / p.mult).ceil() * p.mult;
          made.add(autoPR(w.id, p.id, q, 'Reorder check (auto)'));
        }
      }
    }
    addAutoLog('Reorder check', made.isEmpty ? 'All items above reorder level' : '${made.length} purchase request(s) raised',
        made.isEmpty ? '—' : made.map((d) => d.id).join(', '), 'Run now · Srinivas Rao');
    return made;
  }

  /// Sends a draft purchase request to the approver. Until then it can be changed freely.
  Res prSubmit(String id) {
    final d = doc(id)!;
    setStatus(d, 'Pending Approval', Users.mgr, 'submitted for approval');
    return Res('$id submitted for approval', id);
  }

  Res prApprove(String id) {
    setStatus(doc(id)!, 'Approved', Users.mgr, 'approved by SCM Manager');
    return Res('$id approved by SCM Manager', id);
  }

  Res prReject(String id, String reason) {
    final d = doc(id)!;
    d.reason = reason;
    setStatus(d, 'Rejected', Users.mgr, 'Reason: $reason');
    return Res('$id rejected by SCM Manager · Reason: $reason', id);
  }

  Doc createPO(String supId, String w, List<Line> lines, String? ref) {
    final po = mk(Doc(id: '', type: 'PO', date: todayStr(), wh: w, status: 'Draft', party: supId, ref: ref, by: Users.buyer,
        lines: lines.map((l) => Line(l.item, l.qty, l.rate)..desc = l.desc).toList())
      ..delivery = addDays(todayStr(), sup(supId).lead));
    if (ref != null && ref.startsWith('PR-')) {
      // Created from an approved Purchase Request: sent directly to supplier
      setStatus(po, 'Sent to Supplier', Users.buyer, 'from approved request $ref · sent to supplier');
      sendEmail(emailOfSup(supId), 'Purchase order ${po.id}', po.id);
    } else if (po.amount > params.poApproval) {
      po.note = 'PO value ${fmtINR(po.amount)} is above the ${fmtINR(params.poApproval)} approval limit';
      setStatus(po, 'Pending Approval', Users.sys);
    } else {
      setStatus(po, 'Sent to Supplier', Users.sys, 'within limit · emailed to ${sup(supId).contact}');
      sendEmail(emailOfSup(supId), 'Purchase order ${po.id}', po.id);
    }
    return po;
  }

  /// The supplier a request line is bought from: the line's own supplier, else the request's, else the item's usual supplier.
  String lineSup(Doc pr, Line l) => l.sup.isNotEmpty ? l.sup : (pr.party ?? (items.any((p) => p.id == l.item) ? item(l.item).sup : ''));

  /// The suppliers named on a request's lines, e.g. "Andhra Corrugators, Sri Balaji Papers" ('' when none is chosen).
  String prSupplierNames(Doc pr) => {for (final l in pr.lines) lineSup(pr, l)}.where((x) => x.isNotEmpty && suppliers.any((s) => s.id == x)).map((x) => sup(x).name).join(', ');

  /// The request's lines by supplier, in the order the suppliers first appear (each supplier gets its own purchase order).
  Map<String, List<Line>> prBySupplier(Doc pr) {
    final m = <String, List<Line>>{};
    for (final l in pr.lines) {
      m.putIfAbsent(lineSup(pr, l), () => []).add(l);
    }
    return m;
  }

  /// Suppliers of this request that have no purchase order yet.
  List<String> prSuppliersToOrder(Doc pr) {
    // a purchase order covers the supplier group it was made for, even if the supplier was changed on its form
    final done = docsOf('PO').where((p) => p.ref == pr.id && p.status != 'Cancelled' && p.status != 'Rejected').map((p) => p.extra['pr_sup'] ?? p.party).toSet();
    return prBySupplier(pr).keys.where((s) => !done.contains(s)).toList();
  }

  /// Every supplier ordered: the request is Ordered; otherwise it stays Approved for the remaining suppliers.
  void _prAfterOrder(Doc pr, String poId) {
    final left = prSuppliersToOrder(pr);
    if (left.isEmpty) {
      setStatus(pr, 'Ordered', Users.buyer, poId);
    } else {
      logDoc(pr, '$poId created · still to order from ${left.map((x) => x.isEmpty ? 'a supplier not chosen yet' : sup(x).name).join(', ')}', Users.buyer);
    }
  }

  /// Makes the purchase orders for an approved request at once: one per supplier still to order.
  Res prPo(String id) {
    final d = doc(id)!;
    if (d.status != 'Approved') return Res('${d.id} is ${d.status}: only an approved request can be made into a purchase order');
    final groups = prBySupplier(d);
    final made = <Doc>[];
    for (final s in prSuppliersToOrder(d)) {
      final supId = s.isNotEmpty ? s : (suppliers.isNotEmpty ? suppliers.first.id : 'S001');
      final po = createPO(supId, d.wh, groups[s]!.map((l) => (Line(l.item, l.qty, l.rate > 0 ? l.rate : purchasePrice(supId, l.item, l.qty).rate)..desc = l.desc)).toList(), d.id);
      po.extra = {...po.extra, 'pr_sup': s};
      setStatus(po, 'Sent to Supplier', Users.buyer, 'from approved request $id · sent to supplier');
      link(d, po);
      made.add(po);
    }
    if (made.isEmpty) return Res('${d.id}: every supplier has a purchase order already');
    setStatus(d, 'Ordered', Users.buyer, made.map((p) => p.id).join(', '));
    return Res(made.length == 1 ? 'Purchase order ${made.first.id} created from $id · Sent to Supplier' : '${made.length} purchase orders created from $id (one per supplier): ${made.map((p) => p.id).join(', ')}', made.first.id);
  }

  /// A purchase order was created (and possibly changed) on the form opened from this request.
  /// [forSup] is the request's supplier group this order was made for.
  Res prOrdered(String prId, String poId, {String? forSup}) {
    final pr = doc(prId)!, po = doc(poId)!;
    po.ref = prId;
    if (forSup != null) po.extra = {...po.extra, 'pr_sup': forSup};
    logDoc(po, 'Created from $prId', Users.buyer);
    link(pr, po);
    // Since PR was approved by SCM Manager, the PO is sent to supplier
    setStatus(po, 'Sent to Supplier', Users.buyer, 'from approved request $prId · sent to supplier');
    sendEmail(emailOfSup(po.party!), 'Purchase order ${po.id}', po.id);
    _prAfterOrder(pr, poId);
    final left = prSuppliersToOrder(pr).length;
    return Res('Purchase order $poId created from $prId · Sent to Supplier${left > 0 ? ' · $left more supplier(s) to order on this request' : ''}', poId);
  }

  Res prRfq(String id) {
    final d = doc(id)!;
    final r = mk(Doc(id: '', type: 'RFQ', date: todayStr(), wh: d.wh, status: 'Awaiting Quotes', party: d.party, ref: d.id, lines: d.lines.map((l) => l.copy()).toList())
      ..close = addDays(todayStr(), 3));
    setStatus(d, 'RFQ Sent', Users.buyer, r.id);
    link(d, r);
    return Res('RFQ ${r.id} sent to 3 suppliers', r.id);
  }

  Doc newRfq(String itemId, int qty, String w, String close, List<String> sups, {String? prRef}) {
    final p = item(itemId);
    final existing = prRef == null ? null : doc(prRef);
    final pr = existing ??
        mk(Doc(id: '', type: 'PR', date: todayStr(), wh: w, status: 'RFQ Sent', party: sups.first, by: Users.buyer, lines: [Line(itemId, qty, p.cost)])
          ..source = 'Manual — for RFQ'
          ..need = addDays(todayStr(), p.lead + 3));
    if (existing != null) setStatus(existing, 'RFQ Sent', Users.buyer);
    final r = mk(Doc(id: '', type: 'RFQ', date: todayStr(), wh: w, status: 'Awaiting Quotes', party: sups.first, ref: pr.id, lines: [Line(itemId, qty, p.cost)])
      ..close = close
      ..invited = sups);
    link(pr, r);
    for (final s in sups) {
      sendEmail(emailOfSup(s), 'Request for quotation ${r.id} · ${p.name} × $qty', r.id);
    }
    return r;
  }

  Res rfqQuotes(String id) {
    final r = doc(id)!;
    final p = item(r.lines.first.item);
    final sups = r.invited.isNotEmpty
        ? r.invited.take(5).toList()
        : [p.sup, ...suppliers.where((s) => s.id != p.sup).take(2).map((s) => s.id)];
    const f = [0.98, 1.03, 1.01, 1.05, 0.995];
    r.quotes = [for (var i = 0; i < sups.length; i++) Quote(sups[i], (p.cost * f[i]).roundToDouble(), sup(sups[i]).lead, addDays(todayStr(), 14))];
    setStatus(r, 'Quotes Received', Users.buyer, '${sups.length} quotes');
    return Res('Quotes recorded · best price highlighted', id);
  }

  Res rfqAward(String id) {
    final r = doc(id)!;
    final best = ([...r.quotes]..sort((a, b) => a.rate.compareTo(b.rate))).first;
    final po = createPO(best.sup, r.wh, r.lines.map((l) => (Line(l.item, l.qty, best.rate)..desc = l.desc)).toList(), r.id);
    setStatus(r, 'Awarded', Users.buyer, sup(best.sup).name);
    link(r, po);
    final pr = r.ref == null ? null : doc(r.ref!);
    if (pr != null) {
      setStatus(pr, 'Ordered', Users.sys, po.id);
      link(pr, po);
    }
    return Res('Awarded to ${sup(best.sup).name} · ${po.id} created', po.id);
  }

  Res poApprove(String id) {
    final d = doc(id)!;
    d.note = null;
    sendEmail(emailOfSup(d.party!), 'Purchase order $id', id);
    setStatus(d, 'Sent to Supplier', Users.mgr, 'approved · emailed to supplier');
    return Res('$id approved and sent', id);
  }

  Res poReceive(String id, List<int> qtys, String challan) {
    final d = doc(id)!;
    final lines = <Line>[];
    for (var i = 0; i < d.lines.length; i++) {
      final l = d.lines[i];
      final q = math.max(0, math.min(qtys[i], l.qty - l.recv));
      if (q > 0) {
        l.recv += q;
        lines.add((Line(l.item, q, l.rate)..desc = l.desc));
      }
    }
    if (lines.isEmpty) return Res('Nothing to receive');
    final g = mk(Doc(id: '', type: 'GRN', date: todayStr(), wh: d.wh, status: 'QC Pending', party: d.party, ref: d.id, lines: lines)..challan = challan);
    final full = d.lines.every((l) => l.recv >= l.qty);
    setStatus(d, full ? 'Received' : 'Partially Received', Users.wh, g.id);
    link(d, g);
    // an invoice that was waiting for the goods is checked now
    for (final pi in docsOf('PI').where((p) => p.ref == d.id && p.status == 'Awaiting Goods Receipt')) {
      piVerify(pi.id);
    }
    return Res('${g.id} created · goods held in RCV-01 until QC', g.id);
  }

  Res grnQc(String id, List<int> accepted) {
    final g = doc(id)!;
    final rej = <Line>[];
    for (var i = 0; i < g.lines.length; i++) {
      final l = g.lines[i];
      final a = math.max(0, math.min(accepted[i], l.qty));
      if (a < l.qty) rej.add((Line(l.item, l.qty - a, l.rate)..desc = l.desc));
      l.acc = a;
    }
    for (final l in g.lines) {
      if (l.acc > 0) postStock(g.wh, l.item, l.acc, 'Purchase receipt', g.id, Users.wh);
    }
    setStatus(g, 'QC Checked', Users.wh, rej.isNotEmpty ? 'partial rejection' : 'all units passed QC');
    // the QC report is ready the moment the QC team posts the result: it can be downloaded on the goods receipt
    g.qcSent = todayStr();
    logDoc(g, 'QC report ready · posted by ${g.qcBy ?? 'QC team'}', g.qcBy ?? Users.wh);
    // a bin allocation is only needed when some units were accepted (all rejected = nothing to put away)
    final pa = g.lines.any((l) => l.acc > 0)
        ? mk(Doc(id: '', type: 'PA', date: todayStr(), wh: g.wh, status: 'To Do', party: g.party, ref: g.id,
            lines: g.lines.where((l) => l.acc > 0).map((l) => (Line(l.item, l.acc, l.rate, from: 'RCV-01', bin: suggestBin(l.item))..desc = l.desc)).toList()))
        : null;
    if (pa != null) link(g, pa);
    for (final pi in docsOf('PI').where((p) => p.ref == g.ref && p.status == 'Awaiting Goods Receipt')) {
      piVerify(pi.id);
    }
    if (rej.isNotEmpty) {
      // QC already rejected these units, so the return is approved and ready to dispatch
      final pr = mk(Doc(id: '', type: 'PRT', date: todayStr(), wh: g.wh, status: 'Approved', party: g.party, ref: g.id, lines: rej)..reason = 'Rejected at QC');
      logDoc(pr, 'Raised automatically from the QC result', Users.sys);
      link(g, pr);
    }
    return Res(pa == null ? 'QC posted · all units rejected · return raised, nothing to put in bins' : 'QC posted · stock updated · bin allocation ${pa.id}${rej.isNotEmpty ? ' · return raised for rejects' : ''}', pa?.id ?? g.id);
  }

  /// The bins the goods of a receipt were stored in (from its completed bin allocation): item name → bin.
  Map<String, String> binsOf(Doc g) {
    final out = <String, String>{};
    for (final pa in docsOf('PA').where((p) => p.ref == g.id && p.status == 'Completed')) {
      for (final l in pa.lines) {
        if (l.bin.isNotEmpty) out[item(l.item).name] = out.containsKey(item(l.item).name) ? '${out[item(l.item).name]}, ${l.bin}' : l.bin;
      }
    }
    return out;
  }

  Res paConfirm(String id) {
    final pa = doc(id)!;
    setStatus(pa, 'Completed', Users.wh, 'scanned into ${pa.lines.map((l) => l.bin).join(', ')}');
    final g = pa.ref == null ? null : doc(pa.ref!);
    if (g != null) setStatus(g, 'Bin Allocated', Users.sys);
    return Res('Bin allocation confirmed', id);
  }

  Res grnReturn(String id, String itemId, int qty, String reason) {
    final g = doc(id)!;
    final l = g.lines.firstWhere((x) => x.item == itemId);
    final r = mk(Doc(id: '', type: 'PRT', date: todayStr(), wh: g.wh, status: 'Submitted', party: g.party, ref: g.id, lines: [Line(itemId, qty, l.rate)])..reason = reason);
    link(g, r);
    return Res('Purchase return ${r.id} created', r.id);
  }

  /// Warehouse sends the goods receipts to the QC team for inspection.
  Res grnRaiseQc(List<String> ids) {
    final sent = <String>[];
    for (final id in ids) {
      final g = doc(id);
      if (g == null || g.status != 'QC Pending') continue;
      setStatus(g, 'QC Requested', Users.wh, 'sent to the QC team');
      sendEmail('QC team', 'Quality check request ${g.id} · ${partyName(g)}', g.id);
      sent.add(g.id);
    }
    if (sent.isEmpty) return Res('Nothing sent · only goods receipts in QC Pending can be sent for QC');
    return Res('QC request sent to the QC team · ${sent.join(', ')}', sent.length == 1 ? sent.first : null);
  }

  /// Purchase return raised from a goods receipt; it waits for approval before the goods are dispatched.
  Res prtCreate(String grnId, Map<String, int> qtys, String reason, String date, String wh, String? remarks) {
    final g = doc(grnId)!;
    final lines = [
      for (final l in g.lines)
        if ((qtys[l.item] ?? 0) > 0) (Line(l.item, qtys[l.item]!, l.rate, batch: l.batch)..desc = l.desc),
    ];
    final r = mk(Doc(id: '', type: 'PRT', date: date, wh: wh, status: 'Submitted', party: g.party, ref: g.id, by: Users.wh, lines: lines)
      ..reason = reason
      ..note = (remarks ?? '').trim().isEmpty ? null : remarks!.trim());
    logDoc(r, 'Submitted for approval', Users.wh);
    link(g, r);
    return Res('Purchase return ${r.id} submitted for approval', r.id);
  }

  Res prtApprove(String id) {
    setStatus(doc(id)!, 'Approved', Users.mgr, 'ready to dispatch');
    return Res('$id approved · ready to dispatch', id);
  }

  Res prtDispatch(String id) {
    final r = doc(id)!;
    if (r.status == 'Returned') return Res('${r.id} is already dispatched');
    // Only rejected units can be returned and they never went into stock, so no stock is taken out here.
    final dbn = mk(Doc(id: '', type: 'DBN', date: todayStr(), wh: r.wh, status: 'Issued', party: r.party, ref: r.id, lines: r.lines.map((l) => l.copy()).toList()));
    setStatus(r, 'Returned', Users.wh, 'debit note ${dbn.id}');
    link(r, dbn);
    // a supplier invoice held for this difference is checked again: the debit note now settles it
    final po = r.ref == null ? null : doc(r.ref!)?.ref;
    for (final pi in docsOf('PI').where((p) => p.ref == po && p.status == 'Pending Approval')) {
      piVerify(pi.id);
    }
    return Res('Return dispatched · debit note ${dbn.id} issued', dbn.id);
  }

  Res poInvoice(String id, String supInv, Map<String, double> rates) {
    final d = doc(id)!;
    final lines = <Line>[];
    final bad = <String>[];
    for (final l in d.lines.where((l) => l.recv > 0)) {
      final r = rates[l.item] ?? l.rate;
      lines.add((Line(l.item, l.recv, r)..desc = l.desc));
      final v = (r - l.rate) / l.rate * 100;
      if (v.abs() > params.matchTolerance) bad.add('${l.item}: invoiced ${fmtINR(r)} vs PO ${fmtINR(l.rate)} (${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}%)');
    }
    final pi = mk(Doc(id: '', type: 'PI', date: todayStr(), wh: d.wh, status: 'Draft', party: d.party, ref: d.id, lines: lines)..supInv = supInv);
    if (bad.isNotEmpty) {
      pi.match = MatchResult(false, 'Price difference — ${bad.join('; ')} — exceeds the ${params.matchTolerance.toStringAsFixed(0)}% price tolerance');
      setStatus(pi, 'Pending Approval', Users.sys, 'match failed');
    } else {
      pi.match = MatchResult(true, 'Invoice verified — matches the purchase order and goods receipt');
      setStatus(pi, 'Approved', Users.sys, 'auto-approved by match');
      pi.due = addDays(pi.date, sup(pi.party!).terms);
    }
    link(d, pi);
    return Res(pi.match!.ok ? 'Invoice verified and approved for payment' : 'Price difference found — sent for approval', pi.id);
  }

  /// Supplier portal: after sending the goods the supplier raises its tax invoice against our PO.
  /// It arrives in Buy › Purchase Invoices and is checked automatically against the PO and the goods receipt.
  Res supplierRaiseInvoice(String poId, String supInv, String invDate, Map<String, int> qtys, Map<String, double> rates) {
    final po = doc(poId)!;
    if (supplierInvoiceExists(po.party, supInv)) return Res('Supplier invoice $supInv is already recorded for this supplier');
    final s = sup(po.party!);
    final lines = [
      for (final l in po.lines)
        if ((qtys[l.item] ?? l.qty) > 0) (Line(l.item, qtys[l.item] ?? l.qty, rates[l.item] ?? l.rate)..desc = l.desc),
    ];
    final pi = mk(Doc(id: '', type: 'PI', date: invDate, wh: po.wh, status: 'Received from Supplier', party: po.party, ref: po.id, by: '${s.name} (Supplier)', lines: lines)
      ..supInv = supInv
      ..due = addDays(invDate, s.terms));
    link(po, pi);
    // checked against the purchase order and goods receipt the moment it arrives (nobody presses Verify)
    piVerify(pi.id);
    return Res('Purchase invoice ${pi.id} received from the supplier · ${pi.status}', pi.id);
  }

  /// The supplier already has an invoice with this number on file (the same invoice must not be entered twice).
  bool supplierInvoiceExists(String? supplier, String no) => docsOf('PI').any((p) => p.party == supplier && (p.supInv ?? '').trim().toLowerCase() == no.trim().toLowerCase() && p.status != 'Rejected');

  /// A supplier invoice is checked against the PO price and the quantity actually received (GRN). Runs by itself when the invoice arrives.
  Res piVerify(String id) {
    final pi = doc(id)!;
    final po = doc(pi.ref!)!;
    // we pay only for goods that passed QC: compare with the quantity accepted on the goods receipts
    final grns = docsOf('GRN').where((g) => g.ref == po.id).toList();
    final checked = grns.where(qcDone).toList();
    if (checked.isEmpty) {
      final received = grns.isNotEmpty;
      pi.match = MatchResult(false, received ? 'Goods received, waiting for the QC result. Checked automatically once QC is posted.' : 'Goods not received yet. Checked automatically after the goods receipt and QC.');
      setStatus(pi, 'Awaiting Goods Receipt', Users.fin, received ? 'waiting for QC' : 'goods not received yet');
      return Res('${pi.id} waits for the goods receipt and QC', id);
    }
    int accepted(String it) => checked.fold(0, (a, g) => a + g.lines.where((l) => l.item == it).fold(0, (b, l) => b + l.acc));
    int received(String it) => checked.fold(0, (a, g) => a + g.lines.where((l) => l.item == it).fold(0, (b, l) => b + l.qty));
    // rejected units already returned to the supplier (the return is dispatched and a debit note issued)
    final returns = docsOf('PRT').where((r) => r.status == 'Returned' && checked.any((g) => g.id == r.ref)).toList();
    int returned(String it) => returns.fold(0, (a, r) => a + r.lines.where((l) => l.item == it).fold(0, (b, l) => b + l.qty));
    final bad = <String>[];
    for (final l in pi.lines) {
      final pl = po.lines.where((x) => x.item == l.item).firstOrNull;
      if (pl == null) {
        bad.add('${item(l.item).name}: not on the purchase order');
        continue;
      }
      final acc = accepted(l.item), rej = received(l.item) - acc, back = returned(l.item);
      // rejects already sent back on a debit note are settled by that note, so they do not count as a difference
      if (l.qty > acc + back) bad.add('${item(l.item).name}: billed ${l.qty} but only $acc accepted at QC${rej > back ? ' (${rej - back} rejected, not yet returned on a debit note)' : ''}');
      final v = (l.rate - pl.rate) / pl.rate * 100;
      if (v.abs() > params.matchTolerance) bad.add('${item(l.item).name}: rate ${fmtINR(l.rate)} vs PO ${fmtINR(pl.rate)} (${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}%)');
    }
    if (bad.isNotEmpty) {
      pi.match = MatchResult(false, 'Difference found: ${bad.join('; ')}');
      setStatus(pi, 'Pending Approval', Users.fin, 'difference found');
      return Res('Difference found · ${pi.id} sent for approval', id);
    }
    final notes = [for (final r in returns) ...r.refs.where((x) => x.startsWith('DBN'))];
    pi.match = MatchResult(true, notes.isEmpty ? 'Invoice verified: matches the purchase order and goods receipt' : 'Invoice verified: matches the purchase order and goods receipt · rejected units settled by debit note ${notes.join(', ')}');
    setStatus(pi, 'Approved', Users.fin, 'verified');
    return Res('${pi.id} verified and approved for payment', id);
  }

  Res piApprove(String id) {
    final d = doc(id)!;
    d.due = addDays(todayStr(), sup(d.party!).terms);
    setStatus(d, 'Approved', Users.mgr, 'price difference approved');
    return Res('$id approved for payment', id);
  }

  Res piPay(String id) {
    final d = doc(id)!;
    final n = docs.length;
    final sp = mk(Doc(id: '', type: 'SP', date: todayStr(), wh: d.wh, status: 'Paid', party: d.party, ref: d.id)
      ..mode = 'NEFT'
      ..utr = 'UTR N${2800 + n} ${3000 + n}', amount: d.amount - d.paid);
    d.paid = d.amount;
    setStatus(d, 'Paid', Users.fin, sp.id);
    link(d, sp);
    return Res('Supplier paid · ${sp.id}', sp.id);
  }

  int payAllApproved() {
    final due = docsOf('PI').where((p) => p.status == 'Approved').toList();
    for (final p in due) {
      piPay(p.id);
    }
    return due.length;
  }

  // ============================ INVENTORY & LOGISTICS ============================
  Res trDispatch(String id) {
    final d = doc(id)!;
    for (final l in d.lines) {
      postStock(d.wh, l.item, -l.qty, 'Transfer out', d.id, Users.wh);
      issueTracked(d.wh, l, serialStatus: 'In Transit');
      stk(d.to!, l.item).transit += l.qty;
    }
    d.vehicle ??= vehicles[1];
    setStatus(d, 'In Transit', Users.wh, d.vehicle);
    return Res('Transfer dispatched · stock in transit', id);
  }

  /// [received] is the quantity that really arrived for each line (in order); by default everything that was sent.
  /// A shortage is not added to stock: it was lost or damaged on the way, and is written in the history.
  Res trReceive(String id, [List<int>? received]) {
    final d = doc(id)!;
    var short = 0;
    for (var i = 0; i < d.lines.length; i++) {
      final l = d.lines[i];
      final rq = (received != null && i < received.length ? received[i] : l.qty).clamp(0, l.qty);
      if (rq > 0) postStock(d.to!, l.item, rq, 'Transfer in', d.id, Users.wh);
      stk(d.to!, l.item).transit -= l.qty;
      if (rq < l.qty) {
        short++;
        logDoc(d, 'Short receipt: ${item(l.item).name} · sent ${l.qty}, received $rq (${l.qty - rq} lost or damaged in transit)', Users.wh, 'alert');
      }
      // the batch arrives in the destination (created there if it is new), the serial numbers become Available again
      if (l.batch.isNotEmpty && rq > 0) {
        final p = item(l.item);
        if (p.track == 'Batch') {
          final dst = batchOf(d.to!, l.item, l.batch);
          if (dst != null) {
            dst.qty += rq;
          } else {
            final src = batchOf(d.wh, l.item, l.batch);
            batches.add(Batch(l.batch.trim(), l.item, d.to!, rq, src?.mfg ?? todayStr(), src?.exp ?? '—', src?.sup ?? '', src?.status ?? 'Released'));
          }
        } else if (p.track == 'Serial') {
          for (final sn in serialList(l.batch).take(rq)) {
            final s = serials.where((x) => x.id == sn && x.item == l.item).firstOrNull;
            if (s != null) {
              s.wh = d.to!;
              s.status = 'Available';
            }
          }
        }
      }
    }
    setStatus(d, 'Received', Users.wh, short == 0 ? 'at ${wh(d.to!).code}' : 'at ${wh(d.to!).code} · $short line(s) short');
    return Res('Transfer received at ${wh(d.to!).code}${short == 0 ? '' : ' · $short line(s) received short'}', id);
  }

  void postAdj(Doc d) {
    for (final l in d.lines) {
      postStock(d.wh, l.item, l.qty, 'Adjustment (${(d.reason ?? '').toLowerCase()})', d.id, Users.wh);
      // an adjustment on a batch line also corrects that batch's quantity
      final b = l.batch.isEmpty ? null : batches.where((x) => x.id == l.batch && x.item == l.item && x.wh == d.wh).firstOrNull;
      if (b != null) b.qty += l.qty;
    }
  }

  /// Keeps the customer's address list in step with the Billing and Shipping Address typed on the customer form.
  void syncCustomerAddresses(Customer c) {
    final list = addressesOf(c.id);
    if (list.isEmpty) return;
    list.first
      ..city = c.city
      ..state = c.state;
    if (c.billTo.trim().isNotEmpty) list.first.line = c.billTo.trim();
    final ship = c.shipTo.trim(), bill = c.billTo.trim();
    final i = list.indexWhere((a) => a.label == 'Delivery address');
    if (ship.isNotEmpty && ship != bill) {
      if (i >= 0) {
        list[i]
          ..line = ship
          ..city = c.city
          ..state = c.state;
      } else {
        list.add(Address('Delivery address', 'Shipping only', ship, c.city, c.state, list.first.pin));
      }
    } else if (i >= 0) {
      list.removeAt(i);
    }
  }

  // ---------------- batch and serial tracking ----------------
  Batch? batchOf(String w, String itemId, String id) => batches.where((b) => b.id == id.trim() && b.item == itemId && b.wh == w).firstOrNull;

  /// Serial numbers typed as a list ("SN-1, SN-2" or one per line).
  List<String> serialList(String s) => {for (final x in s.split(RegExp(r'[,;\s]+'))) if (x.trim().isNotEmpty) x.trim()}.toList();

  /// Why the batch / serial numbers typed for [qty] units of an item cannot be used from warehouse [w]; null when they are fine.
  String? pickProblem(String w, String itemId, int qty, String typed) {
    final p = item(itemId);
    final code = wh(w).code;
    if (p.track == 'Batch') {
      final b = batchOf(w, itemId, typed);
      if (b == null) return '${p.name}: batch "${typed.trim()}" does not exist in $code';
      if (b.status == 'Quarantine' || b.status == 'Expired') return '${p.name}: batch ${b.id} is ${b.status} and cannot be sent';
      if (b.exp.length >= 10 && b.exp.compareTo(todayStr()) <= 0) return '${p.name}: batch ${b.id} expired on ${b.exp}';
      if (b.qty < qty) return '${p.name}: batch ${b.id} has only ${b.qty} in $code (you picked $qty)';
    } else if (p.track == 'Serial') {
      final sns = serialList(typed);
      if (sns.length != qty) return '${p.name}: enter exactly $qty serial number(s) (you entered ${sns.length})';
      for (final sn in sns) {
        final s = serials.where((x) => x.id == sn && x.item == itemId && x.wh == w).firstOrNull;
        if (s == null) return '${p.name}: serial $sn is not in $code';
        if (s.status != 'Available' && s.status != 'Allocated') return '${p.name}: serial $sn is ${s.status}';
      }
    }
    return null;
  }

  /// Goods with a batch or serial numbers leave: the batch quantity goes down / the serial numbers become Dispatched.
  void issueTracked(String w, Line l, {String serialStatus = 'Dispatched'}) {
    if (l.batch.isEmpty) return;
    final p = item(l.item);
    if (p.track == 'Batch') {
      final b = batchOf(w, l.item, l.batch);
      if (b != null) b.qty = math.max(0, b.qty - l.qty);
    } else if (p.track == 'Serial') {
      for (final sn in serialList(l.batch)) {
        final s = serials.where((x) => x.id == sn && x.item == l.item).firstOrNull;
        if (s != null) s.status = serialStatus;
      }
    }
  }

  /// What the system expects for a count line: the batch quantity for a batch line, otherwise the item's on-hand.
  int countSys(String w, Line l) {
    if (l.batch.isNotEmpty) {
      final b = batches.where((x) => x.id == l.batch && x.item == l.item && x.wh == w).firstOrNull;
      if (b != null) return b.qty;
    }
    return stk(w, l.item).onhand;
  }

  Res adjApprove(String id) {
    final d = doc(id)!;
    postAdj(d);
    setStatus(d, 'Posted');
    return Res('Adjustment approved and posted to ledger', id);
  }

  Res ccCount(String id, List<int> counts) {
    final d = doc(id)!;
    final adjs = <Doc>[];
    for (var i = 0; i < d.lines.length; i++) {
      final l = d.lines[i];
      l.sys = countSys(d.wh, l);
      l.cnt = counts[i];
      if (l.cnt != l.sys) {
        final a = mk(Doc(id: '', type: 'ADJ', date: todayStr(), wh: d.wh, status: 'Draft', ref: d.id, by: Users.sys, lines: [Line(l.item, l.cnt! - l.sys!, item(l.item).cost, batch: l.batch)])..reason = 'Count difference');
        if (calc(a).sub.abs() > params.adjApproval) {
          setStatus(a, 'Pending Approval', Users.sys, 'value above limit');
        } else {
          postAdj(a);
          setStatus(a, 'Posted', Users.sys, 'auto-posted (within limit)');
        }
        adjs.add(a);
        link(d, a);
      }
    }
    setStatus(d, 'Completed', Users.wh, '${adjs.length} difference(s)');
    return Res('Count completed · ${adjs.isEmpty ? 'no differences' : '${adjs.length} adjustment(s) created'}', id);
  }

  Res ldLoad(String id) {
    setStatus(doc(id)!, 'Loading', Users.wh, 'dock 2');
    return Res('Loading started at dock 2', id);
  }

  Res ldDispatch(String id) {
    final d = doc(id)!;
    var n = 0;
    for (final x in [...d.dns]) {
      final dn = doc(x);
      if (dn != null && dn.status == 'Ready to Dispatch') {
        dispatch(x, d.carrier ?? 'Own fleet', d.vehicle ?? vehicles[0], fromLoad: true);
        n++;
      }
    }
    setStatus(d, 'Dispatched', Users.wh, '$n delivery(ies) invoiced');
    return Res('Trip dispatched · $n invoice(s) and shipment(s) created', id);
  }

  Doc newLoad(String w, String vehicle, String carrier, String route, List<String> dnIds) {
    final lines = <Line>[];
    var ctn = 0;
    for (final x in dnIds) {
      final dn = doc(x)!;
      lines.addAll(dn.lines.map((l) => l.copy()));
      ctn += dn.cartons ?? 4;
    }
    return mk(Doc(id: '', type: 'LD', date: todayStr(), wh: w, status: 'Planned', lines: lines)
      ..vehicle = vehicle
      ..carrier = carrier
      ..route = route
      ..dns = [...dnIds]
      ..util = math.min(96, (ctn * 2.5).round()));
  }

  // ============================ NEW DOCUMENT FORM ============================
  /// Saves changes to a document that is still open (before approval / posting).
  /// A purchase line typed as a description only (no item chosen) is kept as a non-stock item,
  /// so the purchase order, goods receipt and invoice can carry it like any other line.
  String nonStockItem(String desc, String hsn, String uom, int gst, double rate, String? supplier) {
    final same = items.where((p) => p.cat == 'Non-stock' && p.name.toLowerCase() == desc.toLowerCase()).firstOrNull;
    if (same != null) return same.id;
    if (!categories.contains('Non-stock')) categories.add('Non-stock');
    final id = freshId('NS-', items.map((p) => p.id), pad: 4);
    items.add(Item(id, desc, 'Non-stock', hsn.isEmpty ? '9997' : hsn, gst, uom, rate, rate, 0, 1, 1, 7,
        supplier ?? suppliers.first.id, 'None', List.filled(warehouses.length, 0)));
    return id;
  }

  Res updateDocForm(String id, String? party, String w, String? to, String? reason, List<({String item, int qty})> rows, {List<double>? rates, List<String>? batchNos}) {
    final d = doc(id)!;
    final t = d.type;
    final wasReserved = t == 'SO' && d.reserved;
    if (wasReserved) reserveSO(d, false); // release the old quantities first
    d.party = party == null ? d.party : (party.isEmpty ? null : party);
    d.wh = w;
    if (to != null) d.to = to;
    if (reason != null) d.reason = reason;
    var n = 0;
    d.lines = rows.map((r) {
      final idx = n;
      final given = rates != null && n < rates.length ? rates[n] : 0.0;
      n++;
      final rate = given > 0
          ? given
          : (t == 'QT' || t == 'SO')
          ? salesPrice(d.party!, r.item, r.qty.abs()).rate
          : (t == 'PR' || t == 'PO')
              ? (d.party == null ? item(r.item).cost : purchasePrice(d.party!, r.item, r.qty.abs()).rate)
              : item(r.item).cost;
      // the batch / serial numbers typed for a transfer or adjustment stay on the line
      return Line(r.item, r.qty, rate, batch: batchNos != null && idx < batchNos.length ? batchNos[idx] : '');
    }).toList();
    d.amount = calc(d).total;
    if (wasReserved) reserveSO(d, true);
    logDoc(d, 'Edited · ${d.lines.length} line(s) · ${fmtINR(d.amount)}', Users.mgr, 'edit');
    return Res('${d.id} updated', id);
  }

  Doc saveDocForm(String t, String? party, String w, String? to, String? reason, List<({String item, int qty})> rows, {List<double>? rates, List<String>? batchNos}) {
    if (party != null && party.isEmpty) party = null; // purchase request without a supplier
    var n = 0;
    final lines = rows.map((r) {
      // the rate typed on the form wins; otherwise price list / trade agreement / item price
      final idx = n;
      final given = rates != null && n < rates.length ? rates[n] : 0.0;
      n++;
      final rate = given > 0
          ? given
          : (t == 'QT' || t == 'SO')
          ? salesPrice(party!, r.item, r.qty).rate
          : (t == 'PR' || t == 'PO') && party != null
              ? purchasePrice(party, r.item, r.qty).rate
              : item(r.item).cost;
      return Line(r.item, r.qty, rate, batch: batchNos != null && idx < batchNos.length ? batchNos[idx] : '');
    }).toList();
    switch (t) {
      case 'QT':
        return mk(Doc(id: '', type: 'QT', date: todayStr(), wh: w, status: 'Draft', party: party, by: Users.sales, lines: lines)..valid = addDays(todayStr(), 14));
      case 'SO':
        return createSO(party!, w, lines, null);
      case 'PR':
        // a supplier given for the whole request goes on every line (each line can have its own)
        if (party != null) {
          for (final l in lines) {
            l.sup = party;
          }
        }
        return mk(Doc(id: '', type: 'PR', date: todayStr(), wh: w, status: 'Draft', party: party, by: Users.mgr, lines: lines)
          ..source = 'Manual — Srinivas Rao'
          ..need = addDays(todayStr(), 7));
      case 'PO':
        return createPO(party!, w, lines, null);
      case 'TR':
        return mk(Doc(id: '', type: 'TR', date: todayStr(), wh: w, to: to, status: 'Requested', by: Users.mgr, lines: lines));
      default: // ADJ
        final d = mk(Doc(id: '', type: 'ADJ', date: todayStr(), wh: w, status: 'Draft', by: Users.mgr, lines: lines)..reason = reason);
        if (calc(d).sub.abs() > params.adjApproval) {
          setStatus(d, 'Pending Approval', Users.sys, 'value above limit');
        } else {
          postAdj(d);
          setStatus(d, 'Posted', Users.sys, 'within limit');
        }
        return d;
    }
  }

  /// Everything that can be counted in a warehouse, one entry per item (per batch for batch-tracked items):
  /// key 'itemId|batchId', a readable label, and whether the system suggests it (the 3 highest-value items).
  List<({String key, String label, bool checked})> countOptions(String w) {
    final its = [...items]..sort((a, b) => (b.cost * stk(w, b.id).onhand).compareTo(a.cost * stk(w, a.id).onhand));
    final out = <({String key, String label, bool checked})>[];
    var n = 0;
    for (final p in its) {
      final top = n < 3;
      n++;
      final bs = p.track == 'Batch' ? batches.where((b) => b.item == p.id && b.wh == w && b.qty > 0).toList() : <Batch>[];
      final bin = suggestBin(p.id);
      if (bs.isEmpty) {
        out.add((key: '${p.id}|', label: '${p.name} · no batch · bin ${bin.isEmpty ? 'A-01' : bin}', checked: top));
      } else {
        for (final b in bs) {
          out.add((key: '${p.id}|${b.id}', label: '${p.name} · batch ${b.id} · bin ${bin.isEmpty ? 'A-01' : bin}', checked: top));
        }
      }
    }
    return out;
  }

  Doc newCount(String w, String zone, String counter, {List<String>? picks}) {
    if (picks != null) {
      // the lines ticked on the form
      final ls = <Line>[
        for (final k in picks)
          Line(k.split('|').first, 0, item(k.split('|').first).cost, bin: suggestBin(k.split('|').first), batch: k.contains('|') ? k.split('|').last : ''),
      ];
      return mk(Doc(id: '', type: 'CC', date: todayStr(), wh: w, status: 'Counting', lines: ls)
        ..zone = zone
        ..counter = counter);
    }
    final its = [...items]..sort((a, b) => (b.cost * stk(w, b.id).onhand).compareTo(a.cost * stk(w, a.id).onhand));
    final lines = <Line>[];
    for (final p in its.take(3)) {
      // a batch-tracked item is counted batch by batch, so it is clear exactly which batch was counted
      final bs = p.track == 'Batch' ? batches.where((b) => b.item == p.id && b.wh == w && b.qty > 0).toList() : <Batch>[];
      if (bs.isEmpty) {
        lines.add(Line(p.id, 0, p.cost, bin: suggestBin(p.id)));
      } else {
        for (final b in bs) {
          lines.add(Line(p.id, 0, p.cost, bin: suggestBin(p.id), batch: b.id));
        }
      }
    }
    return mk(Doc(id: '', type: 'CC', date: todayStr(), wh: w, status: 'Counting', lines: lines)
      ..zone = zone
      ..counter = counter);
  }

  // ============================ BULK ============================
  ({List<String> done, List<String> skip}) bulkApprove(List<Doc> rows) {
    final done = <String>[], skip = <String>[];
    for (final d in rows) {
      if (d.status != 'Pending Approval') {
        skip.add(d.id);
        continue;
      }
      switch (d.type) {
        case 'SO':
          d.note = null;
          confirmSO(d, Users.mgr);
          break;
        case 'PO':
          d.note = null;
          setStatus(d, 'Sent to Supplier', Users.mgr, 'bulk approved');
          break;
        case 'PR':
          setStatus(d, 'Approved', Users.mgr, 'bulk approved');
          break;
        case 'ADJ':
          postAdj(d);
          setStatus(d, 'Posted', Users.mgr, 'bulk approved');
          break;
        case 'PI':
          d.due = addDays(todayStr(), sup(d.party!).terms);
          setStatus(d, 'Approved', Users.mgr, 'bulk approved');
          break;
        default:
          skip.add(d.id);
          continue;
      }
      done.add(d.id);
    }
    return (done: done, skip: skip);
  }

  static const deletable = ['Draft', 'Pending Approval', 'Requested', 'Awaiting Quotes', 'New', 'Planned'];

  /// Documents that are already in progress but not yet acted on can be cancelled
  /// (kept with status Cancelled and the reason, so the history stays).
  static const cancellable = <String, List<String>>{
    'SO': ['Pending Approval', 'On Hold', 'Confirmed'],
    'PO': ['Sent to Supplier'],
    'QT': ['Sent'],
    'PR': ['Approved'],
    'RFQ': ['RFQ Sent', 'Awaiting Quotes', 'Quotes Received'],
  };

  Res cancelDoc(String id, String reason) {
    final d = doc(id)!;
    if (d.type == 'PO' && (d.lines.any((l) => l.recv > 0) || docsOf('GRN').any((g) => g.ref == d.id))) return Res('${d.id} cannot be cancelled: goods have already been received against it');
    if (d.type == 'SO' && d.reserved) reserveSO(d, false); // give the reserved stock back
    d.note = reason;
    setStatus(d, 'Cancelled', Users.mgr, 'cancelled · $reason');
    return Res('${d.id} cancelled', id);
  }

  void deleteDocs(List<Doc> rows) {
    for (final d in rows) {
      if (d.type == 'SO' && d.reserved) reserveSO(d, false);
      docs.remove(d);
    }
  }

  // ============================ CRM ============================
  /// Number the next opportunity created from a lead will get (shown on the form before it is saved).

  /// Creates the customer and the opportunity for a lead, using what was entered on the opportunity form.
  Res qualifyLead(Lead l, {String? title, String? owner, double? value, String? close, String? stage, int? prob, String? item, int? qty}) {
    // a company that is already a customer is linked, not created a second time
    final existing = customers.where((c) => c.name.trim().toLowerCase() == l.company.trim().toLowerCase()).firstOrNull;
    final cid = existing?.id ?? nextCustomerId();
    if (existing == null) {
      customers.add(Customer(cid, l.company, l.city, l.state, 'Unregistered', 'Retail', 15, 200000, l.contact, l.phone.isEmpty ? '—' : l.phone, 'Active')
        ..email = l.email
        ..gstType = 'Unregistered');
    }
    final who = owner ?? l.owner;
    final sp = salesPersons.where((s) => s.name == who).firstOrNull ?? salesPersons.firstOrNull;
    if (sp != null && existing == null) terrOf[cid] = sp.terr;
    final itemId = item ?? l.interest;
    final p = items.where((x) => x.id == itemId).firstOrNull;
    final o = Opportunity(nextOppId(), cid, title ?? (p == null ? 'First order' : 'First order — ${p.name}'), who, value ?? l.value, prob ?? 30, close ?? addDays(todayStr(), 21), stage ?? 'Prospecting',
        [if (p != null) OppLine(itemId, qty ?? math.max(10, (l.value / p.price).round()))],
        lead: l.id);
    opps.insert(0, o);
    l.status = 'Qualified';
    l.opp = o.id;
    return Res(existing != null ? '${o.id} created from ${l.id} · linked to existing customer $cid' : 'Customer $cid and ${o.id} created from ${l.id}', o.id);
  }

  /// A quotation was created (and possibly changed) on the form opened from this opportunity.
  Res oppQuoted(String oppId, String qtId) {
    final o = opps.firstWhere((x) => x.id == oppId), q = doc(qtId)!;
    q.ref = o.id;
    q.by = '${o.owner} (Sales)';
    logDoc(q, 'Created from ${o.id}', Users.sales);
    o.quote = q.id;
    o.stage = 'Proposal';
    o.prob = math.max(o.prob, 50);
    o.value = q.amount.roundToDouble();
    return Res('Quotation ${q.id} created from ${o.id} · Draft, ready to review and send', q.id);
  }

  Res oppQuote(Opportunity o) {
    final q = mk(Doc(id: '', type: 'QT', date: todayStr(), wh: terr(o.party).wh, status: 'Draft', party: o.party, ref: o.id, by: '${o.owner} (Sales)',
        lines: o.lines.map((l) => Line(l.item, l.qty, salesPrice(o.party, l.item, l.qty).rate)).toList())
      ..valid = addDays(todayStr(), 14));
    o.quote = q.id;
    o.stage = 'Proposal';
    o.prob = math.max(o.prob, 50);
    o.value = q.amount.roundToDouble();
    return Res('Quotation ${q.id} created from ${o.id} · prices from pricing rules', q.id);
  }
}
