// The in-memory "backend": master data, stock engine, documents and every
// business action. UI-only build — swap these methods for API calls later.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'auth.dart';
import 'format.dart';
import 'models.dart';
import 'persist_storage_stub.dart' if (dart.library.html) 'persist_storage_web.dart' as persistStore;

part 'seed.dart';
part 'actions.dart';
part 'automation.dart';
part 'persist.dart';

class Users {
  static const mgr = 'Srinivas Rao (SCM Manager)';
  static const sales = 'Priya Sharma (Sales Exec)';
  static const buyer = 'Harish Varma (Buyer)';
  static const wh = 'Kiran Kumar (Warehouse Executive)';
  static const fin = 'Meena Iyer (Accounts)';
  static const sys = 'System';
}

class Params {
  double soApproval = 500000, poApproval = 500000, adjApproval = 10000, ewayLimit = 50000;
  /// A quotation priced more than this % below the price list needs the SCM Manager's approval before it is sent.
  double qtDiscount = 10;
  double matchTolerance = 2;
  String creditCheck = 'Block on overdue or limit breach';
  String pickStrategy = 'First Expiry, First Out';
  String autoReserve = 'Yes';
  String autoInvoice = 'Yes — on dispatch';
  String autoPutaway = 'Yes — by storage rule';
  String reorderRun = 'Daily at 06:00';
  String numbering = 'Per type · yearly reset';
  String currency = 'INR';
  String fy = '2026-27';
}

class Calc {
  final double sub, tax, total;
  final bool inter;
  final int qty;
  Calc(this.sub, this.tax, this.total, this.inter, this.qty);
}

/// Result of an action: a message for the toast and an optional document to open.
class Res {
  final String msg;
  final String? open;
  Res(this.msg, [this.open]);
}

class AppStore extends ChangeNotifier {
  /// Saving to the browser is switched on by main() once the saved data is loaded (never in tests).
  static bool persistOn = false;
  static Timer? _saveTimer;

  @override
  void notifyListeners() {
    super.notifyListeners();
    scheduleSave();
  }

  // ---------------- UI state ----------------
  String view = 'workspace';
  late Warehouse currentWh;
  String currentCompany = 'IMPACGO Chain Pvt Ltd';
  bool sideCollapsed = false;

  /// Every account (the demo accounts to start with; the Admin adds more in Setup › Users & Roles).
  final List<AppUser> users = [...demoUsers];

  /// The website opens on the sign-in page (switched on by main(); tests start signed in as the manager).
  static bool requireLogin = false;
  late bool signedIn = !requireLogin;
  AppUser? user = demoUsers.first;

  static const _kSession = 'impacgo_chain_session';

  /// Signs in; null when it worked, otherwise why not.
  String? loginError(String email, String pass) {
    final u = users.where((x) => x.email.toLowerCase() == email.trim().toLowerCase()).firstOrNull;
    if (u == null || u.password != pass) return 'Email or password is incorrect';
    if (!u.active) return 'This account is switched off · ask your administrator';
    user = u;
    signedIn = true;
    // everyone starts on their home screen (a supplier on its orders)
    view = u.role == 'supplier' ? 'sp_po' : 'workspace';
    persistStore.writeSaved(_kSession, u.email);
    notifyListeners();
    return null;
  }

  bool login(String email, String pass) => loginError(email, pass) == null;

  /// Back to the sign-in page.
  void signOut() {
    signedIn = false;
    persistStore.clearSaved(_kSession);
    notifyListeners();
  }

  /// Forgot password: a reset link is emailed when the address belongs to an active account
  /// (the backend sends it once connected; here it is recorded in the email log).
  void requestPasswordReset(String email) {
    final u = users.where((x) => x.email.toLowerCase() == email.trim().toLowerCase() && x.active).firstOrNull;
    if (u != null) sendEmail(u.email, 'Reset your IMPACGO Chain password', '—');
  }

  /// After a reload the person who was signed in stays signed in.
  void restoreSession() {
    final email = persistStore.readSaved(_kSession);
    final u = email == null ? null : users.where((x) => x.email == email && x.active).firstOrNull;
    if (u == null) return;
    user = u;
    signedIn = true;
    view = u.role == 'supplier' ? 'sp_po' : 'workspace';
  }

  void go(String v) {
    if (v == view) return; // already on this screen — no rebuild, no flicker
    view = v;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  // ---------------- master data ----------------
  final companies = ['IMPACGO Chain Pvt Ltd', 'IMPACGO Distribution LLP'];
  final companyInfo = const {'gstin': '37AAHCI4521K1Z6', 'state': 'Andhra Pradesh', 'pan': 'AAHCI4521K'};
  /// true = start empty (no demo data). Set to false to load the demo data again.
  static const kCleanStart = true;
  /// Fresh start (open the app with ?fresh=1): no demo data at all - no transactions and no demo items,
  /// customers or suppliers. The company, warehouses, bins, tax codes, units, currencies, payment terms,
  /// number series, sales team and vehicles stay, so every form can be used. Set before the store is first used.
  static bool freshStart = false;
  /// The website starts with one set of demo data: one supplier, one customer and one item, no documents
  /// (set in main(); the automated tests keep the larger demo set).
  static bool singleDemo = false;

  final List<Warehouse> warehouses = [];
  final List<Bin> bins = [];
  final List<Customer> customers = [];
  final Map<String, List<Address>> _addresses = {};

  /// A customer's addresses. The registered address is created from the customer record;
  /// two demo customers also have a second delivery address.
  List<Address> addressesOf(String custId) => _addresses.putIfAbsent(custId, () {
        final c = cust(custId);
        return [
          Address('Registered office', 'Billing & Shipping', c.name, c.city, c.state, c.state == 'Telangana' ? '500003' : '530012'),
          // demo customers' second addresses (not in a fresh start, where C001 is a new customer)
          if (custId == 'C001' && !freshStart && !singleDemo) Address('Gajuwaka warehouse', 'Shipping only', 'Plot 7, Autonagar, Gajuwaka', 'Visakhapatnam', 'Andhra Pradesh', '530026'),
          if (custId == 'C002' && !freshStart && !singleDemo) Address('Bengaluru store', 'Shipping only', '14 Hosur Road, Electronic City', 'Bengaluru', 'Karnataka', '560100'),
        ];
      });

  /// The document (itself, or the quotation / order it came from) that holds the chosen addresses.
  Doc? addressDoc(Doc d) {
    Doc? x = d;
    for (var i = 0; i < 6 && x != null; i++) {
      if (x.shipTo != null) return x;
      x = x.ref == null ? null : doc(x.ref!);
    }
    return null;
  }
  final List<Supplier> suppliers = [];
  final List<String> categories = [];
  final List<Item> items = [];
  final List<PriceList> priceLists = [];
  final List<TradeAgreement> tradeAgreements = [];
  final List<Carrier> carriers = [];
  final List<String> vehicles = [];
  final Params params = Params();
  final Map<String, DocType> dt = {};
  /// Number series that are saved but not active (see [SeriesEntry]).
  final List<SeriesEntry> seriesList = [];

  // ---------------- setup lists (Company Settings) ----------------
  final List<Branch> branches = [];
  final List<Currency> currencies = [];
  final List<PayTerm> payTerms = [];
  final List<TaxCode> taxCodes = [];
  final List<TcTemplate> tcTemplates = [];


  /// A new id that nobody uses yet: [prefix] plus the next number after the highest one in use.
  /// (Counting the records would repeat a number after a delete.)
  String freshId(String prefix, Iterable<String> used, {int pad = 0, int start = 1}) {
    var n = start;
    for (final id in used) {
      if (!id.startsWith(prefix)) continue;
      final x = int.tryParse(id.substring(prefix.length));
      if (x != null && x >= n) n = x + 1;
    }
    return '$prefix${n.toString().padLeft(pad, '0')}';
  }

  String nextCustomerId() => freshId('C', customers.map((c) => c.id), pad: 3);
  String nextSupplierId() => freshId('S', suppliers.map((s) => s.id), pad: 3);
  String nextItemId() => freshId('ITM-', items.map((p) => p.id), start: 1001);
  String nextLeadId() => freshId('LEAD-', leads.map((l) => l.id), pad: 4, start: 101);
  String nextOppId() => freshId('OPP-', opps.map((o) => o.id), pad: 4);
  List<String> get branchNames => [for (final b in branches) if (b.status == 'Active') b.name];
  List<String> get currencyCodes => [for (final c in currencies) if (c.status == 'Active') c.code];
  List<String> get termNames => [for (final t in payTerms) if (t.status == 'Active') t.name];
  List<String> get taxNames => [for (final t in taxCodes) if (t.status == 'Active') t.name];

  /// "GST 18%" → 18. A code that is not in the list falls back to the number in its name.
  double taxRateOf(String code) {
    final t = taxCodes.where((x) => x.name == code).firstOrNull;
    if (t != null) return t.rate;
    final m = RegExp(r'\d+(\.\d+)?').firstMatch(code);
    return m == null ? 0 : double.parse(m.group(0)!);
  }

  /// The tax code name for a rate ("GST 18%" for 18, "Exempt" for 0).
  String taxNameFor(int gst) {
    final t = taxCodes.where((x) => x.rate == gst.toDouble() && x.status == 'Active').firstOrNull;
    return t?.name ?? (gst == 0 ? 'Exempt' : 'GST $gst%');
  }

  /// "Net 30 days" → 30 ("Advance" and "Immediate" → 0). A term that is in the list uses its own days.
  int termDaysOf(String name) {
    final t = payTerms.where((x) => x.name == name).firstOrNull;
    if (t != null) return t.days;
    return int.tryParse(RegExp(r'\d+').firstMatch(name)?.group(0) ?? '') ?? 0;
  }

  // ---------------- transactional ----------------
  final Map<String, Map<String, StockCell>> stock = {};
  final List<LedgerEntry> ledger = [];
  final List<Doc> docs = [];
  final List<Batch> batches = [];
  final List<Serial> serials = [];

  // ---------------- CRM & extra masters ----------------
  final List<Territory> territories = [];
  final Map<String, String> terrOf = {};
  final List<SalesPerson> salesPersons = [];
  final List<Contact> contacts = [];
  final List<Lead> leads = [];
  final List<Opportunity> opps = [];
  final List<CustomerGroup> customerGroups = [];
  final List<SupplierGroup> supplierGroups = [];
  final List<Uom> uoms = [];
  final List<TrackGroup> trackGroups = [];
  final List<StorageGroup> storageGroups = [];
  final List<Site> sites = [];
  final List<BinMove> moves = [];
  final List<Vehicle> fleet = [];
  final List<LoadTemplate> loadTemplates = [];

  // ---------------- automation ----------------
  final List<AutoLog> autoLog = [];
  final List<Email> emails = [];
  final List<ReportSchedule> reportSchedules = [];
  final List<Valuation> valuations = [];
  final List<Job> jobs = [];
  final List<AutoRule> rules = [];

  AppStore() {
    _seedMasters(this);
    _seedSetupLists(this);
    currentWh = warehouses.first;
    for (var wi = 0; wi < warehouses.length; wi++) {
      final w = warehouses[wi];
      stock[w.id] = {for (final p in items) p.id: StockCell(p.stock[wi])};
    }
    _seedDocs(this);
    _seedExtras(this);
    _seedAutomation(this);
    if (kCleanStart) {
      _cleanStart();
      _lightDemo();
    }
    if (freshStart || singleDemo) {
      _cleanStart();
      _noDemoMasters();
      if (!freshStart) _singleDemo();
    }
  }

  /// One supplier, one customer and one item - every flow can be shown with them, starting from buying.
  void _singleDemo() {
    suppliers.add(Supplier('S001', 'Andhra Corrugators', 'Visakhapatnam', 'Andhra Pradesh', '37AABFA7719E1Z0', 30, 3, 0, 0, 0, 'N. Prasad', 'Approved')
      ..phone = '+91 9848012345'
      ..address = 'Plot 21, Autonagar Industrial Area'
      ..gstType = 'Registered');
    customers.add(Customer('C001', 'Coastal Traders', 'Visakhapatnam', 'Andhra Pradesh', '37AAKFC1234M1Z5', 'Wholesale', 30, 500000, 'K. Rao', '+91 9876543210', 'Active')
      ..billTo = '12-4 Beach Road, Visakhapatnam'
      ..shipTo = 'Plot 7, Autonagar, Gajuwaka, Visakhapatnam'
      ..gstType = 'Registered');
    final sp = salesPersons.where((s) => s.name == 'Priya Sharma').firstOrNull ?? salesPersons.firstOrNull;
    if (sp != null) terrOf['C001'] = sp.terr;
    syncCustomerAddresses(customers.last);
    items.add(Item('ITM-1001', 'Corrugated Carton 5-Ply', 'Packaging', '4819', 12, 'Nos', 42, 60, 500, 100, 5, 3, 'S001', 'None', [0, 0, 0]));
    for (final w in warehouses) {
      stock[w.id] = {'ITM-1001': StockCell(0)};
    }
    _singleDemoDocs();
  }

  /// One worked example on every screen, made with the one supplier, customer and item through the normal actions.
  void _singleDemoDocs() {
    final w = warehouses.first.id;
    const it = 'ITM-1001';
    // ---- Buy: request -> order -> goods receipt -> QC (10 rejected) -> bins -> return + debit note -> supplier invoice
    final pr = saveDocForm('PR', 'S001', w, null, null, [(item: it, qty: 2000)])
      ..purpose = 'Cartons for the festive season dispatches'
      ..requester = 'Srinivas Rao'
      ..dept = 'Stores';
    prSubmit(pr.id);
    prApprove(pr.id);
    final poId = prPo(pr.id).open!;
    if (doc(poId)!.status == 'Pending Approval') poApprove(poId);
    final g = doc(poReceive(poId, [2000], 'AC/DC/2209').open!)!
      ..vehicle = 'AP 31 TX 4410'
      ..by = 'Kiran Kumar (Warehouse)';
    grnRaiseQc([g.id]);
    g
      ..qcBy = 'Lakshmi P'
      ..qcResult = 'Partially passed'
      ..qcNote = '10 cartons crushed in transit'
      ..qcDate = todayStr();
    grnQc(g.id, [1990]);
    for (final pa in docsOf('PA').where((p) => p.ref == g.id)) {
      paConfirm(pa.id);
    }
    for (final r in docsOf('PRT').where((r) => r.ref == g.id)) {
      prtDispatch(r.id);
    }
    supplierRaiseInvoice(poId, 'AND/INV/4100', todayStr(), {it: 2000}, {it: doc(poId)!.lines.first.rate});

    // ---- Sell: lead -> opportunity -> quotation -> sales order -> pick -> pack -> dispatch -> invoice -> payment -> delivered -> return -> credit note
    final lead = Lead('LEAD-0101', 'Coastal Traders', 'K. Rao', 'Visakhapatnam', 'Andhra Pradesh', 'Referral', 'Priya Sharma', 30000, todayStr(), 'Contacted', it);
    leads.add(lead);
    final oppId = qualifyLead(lead, qty: 500).open!;
    final qt = saveDocForm('QT', 'C001', w, null, null, [(item: it, qty: 500)]);
    oppQuoted(oppId, qt.id);
    qtSend(qt.id, 'orders@coastaltraders.in');
    qtAccept(qt.id);
    final so = saveDocForm('SO', 'C001', w, null, null, [(item: it, qty: 500)], rates: [qt.lines.first.rate])..custPo = 'CT/PO/2026/045';
    qtOrdered(qt.id, so.id);
    if (so.status == 'Confirmed') {
      final pc = pkConfirm(soRelease(so.id).open!).open!;
      final dn = pack(pc, 10, '300 kg').open!;
      final inv = dnDispatch(dn, 'Own fleet · Appa Rao', 'AP 31 TX 4521').open!;
      invPay(inv, doc(inv)!.amount, 'NEFT', 'UTR N2715 1015');
      dnDeliver(dn);
      final sr = invReturn(inv, it, 5, 'Damaged in transit').open!;
      srApprove(sr);
      srReceive(sr);
      srCredit(sr);
    }

    // ---- Stock: transfer to Vijayawada, a damage write-off, a physical count
    final tr = saveDocForm('TR', null, w, warehouses[1].id, null, [(item: it, qty: 300)])
      ..vehicle = 'AP 16 TB 7702 (Own · 6 T)'
      ..transferredBy = 'Kiran Kumar'
      ..receivedBy = 'Venkat (VJA-HUB)';
    trApprove(tr.id);
    trDispatch(tr.id);
    trReceive(tr.id);
    saveDocForm('ADJ', null, w, null, 'Damage', [(item: it, qty: -2)], rates: [item(it).cost]);
    final cc = newCount(w, 'B · Bulk storage', 'Kiran Kumar', picks: [it])..source = 'Spot check';
    ccCount(cc.id, [for (final l in cc.lines) countSys(w, l)]);
    // ---- Supplier Portal: an approved request sent out for quotation, waiting for the supplier's price
    final rq = saveDocForm('PR', suppliers.first.id, w, null, null, [(item: it, qty: 1000)])
      ..purpose = 'Stock for the next quarter · comparing prices first'
      ..requester = 'Srinivas Rao'
      ..dept = 'Stores';
    prSubmit(rq.id);
    prApprove(rq.id);
    newRfq(it, 1000, w, addDays(todayStr(), 3), [suppliers.first.id], prRef: rq.id);
  }

  /// Removes the demo items, customers and suppliers (and what hangs off them), for a start from nothing.
  void _noDemoMasters() {
    items.clear();
    customers.clear();
    suppliers.clear();
    _addresses.clear();
    tradeAgreements.clear();
    contacts.clear();
    terrOf.clear();
    for (final w in warehouses) {
      stock[w.id] = {};
    }
  }

  /// Start with no transactions: keep the master data (warehouses, bins, items, categories,
  /// customers, suppliers, price lists, sales persons, contacts, vehicles, drivers, tax codes,
  /// units and number series) so every form can be used straight away. All documents, stock,
  /// the stock ledger, batches, serials, leads and opportunities start empty; numbers restart at 0001.
  void _cleanStart() {
    docs.clear();
    ledger.clear();
    batches.clear();
    serials.clear();
    leads.clear();
    opps.clear();
    moves.clear();
    autoLog.clear();
    emails.clear();
    valuations.clear();
    for (final w in warehouses) {
      stock[w.id] = {for (final p in items) p.id: StockCell(0)};
    }
    for (final t in dt.values) {
      t.seq = 0;
    }
  }

  /// A small set of demo records so every main screen has an example at a
  /// different step of the flow (created through the normal business actions).
  void _lightDemo() {
    // opening stock in each warehouse
    for (var wi = 0; wi < warehouses.length; wi++) {
      stock[warehouses[wi].id] = {for (final p in items) p.id: StockCell(p.stock[wi])};
    }
    final w = warehouses.first.id;
    Line ln(String i, int q, {bool buy = false}) => Line(i, q, buy ? item(i).cost : item(i).price);

    // ---- Buy: no demo records · purchase requests, orders, goods receipts, QC, bins, returns and
    // invoices all start empty (suppliers and items stay as master data)

    // ---- Sell
    leads.addAll([
      Lead('LEAD-0101', 'Coastal Traders', 'K. Rao', 'Visakhapatnam', 'Andhra Pradesh', 'Referral', 'Priya Sharma', 120000, todayStr(), 'New', 'ITM-1001'),
      Lead('LEAD-0102', 'Godavari Retail', 'S. Varma', 'Rajahmundry', 'Andhra Pradesh', 'Website enquiry', 'Priya Sharma', 80000, todayStr(), 'Contacted', 'ITM-1004'),
      Lead('LEAD-0103', 'Vizag Safety Mart', 'R. Naidu', 'Visakhapatnam', 'Andhra Pradesh', 'Referral', 'Priya Sharma', 150000, todayStr(), 'New', 'ITM-1001')
        ..phone = '+91 98765 43210'
        ..email = 'naidu@vizagsafetymart.in',
    ]);
    opps.add(Opportunity('OPP-0001', 'C002', 'Carton supply for new stores', 'Priya Sharma', 150000, 50, addDays(todayStr(), 20), 'Proposal', [OppLine('ITM-1004', 2000)]));
    saveDocForm('QT', 'C002', w, null, null, [(item: 'ITM-1004', qty: 1500)]); // quotation in draft
    createSO('C001', w, [ln('ITM-1013', 40)], null); // confirmed, ready to release
    final so = createSO('C001', w, [ln('ITM-1001', 30)], null);
    final pk = soRelease(so.id).open!;
    final pc = pkConfirm(pk).open!;
    pack(pc, 1, '18 kg'); // delivery note ready to dispatch
    // dispatched orders, so Sales Invoices has an unpaid and a paid invoice
    void shipped(String cust, String itemId, int qty, {bool paid = false}) {
      final o = createSO(cust, w, [ln(itemId, qty)], null);
      if (o.status != 'Confirmed') return; // held for credit or approval
      final dn = pack(pkConfirm(soRelease(o.id).open!).open!, 1, '${(qty * 0.6).round()} kg').open;
      if (dn == null) return;
      final inv = dnDispatch(dn, 'Own fleet · Ravi Teja', 'AP 31 TX 4521').open;
      if (paid && inv != null) invPay(inv, doc(inv)!.amount, 'NEFT', 'UTR N2741 1027');
    }
    shipped('C004', 'ITM-1004', 400); // invoice unpaid
    shipped('C003', 'ITM-1013', 25, paid: true); // invoice paid in full

    // ---- Stock
    saveDocForm('TR', null, w, warehouses[1].id, null, [(item: 'ITM-1004', qty: 300)]); // transfer requested
  }

  // ---------------- lookups ----------------
  Warehouse wh(String id) => warehouses.firstWhere((w) => w.id == id);
  Customer cust(String id) => customers.firstWhere((c) => c.id == id);
  Supplier sup(String id) => suppliers.firstWhere((s) => s.id == id);
  Item item(String id) => items.firstWhere((p) => p.id == id);
  Doc? doc(String id) {
    for (final d in docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<Doc> docsOf(String t) => docs.where((d) => d.type == t).toList();
  StockCell stk(String w, String i) => (stock[w] ??= {}).putIfAbsent(i, () => StockCell(0));
  int avail(String w, String i) => stk(w, i).avail;
  Territory terr(String custId) => territories.firstWhere((t) => t.id == (terrOf[custId] ?? 'TER-01'), orElse: () => territories.first);

  String partyName(Doc d) {
    final p = dt[d.type]!.party;
    if (p == 'C') return d.party == null ? '—' : cust(d.party!).name;
    if (p == 'S' && d.party == null && d.type == 'PR') {
      // a request whose lines have different suppliers names them all
      final names = prSupplierNames(d);
      return names.isEmpty ? '—' : names;
    }
    if (p == 'S') return d.party == null ? '—' : sup(d.party!).name;
    return wh(d.wh).name;
  }

  String partyCity(Doc d) {
    final p = dt[d.type]!.party;
    if (p == 'C' && d.party != null) return cust(d.party!).city;
    if (p == 'S' && d.party != null) return sup(d.party!).city;
    return wh(d.wh).city;
  }

  String partyState(Doc d) {
    final p = dt[d.type]!.party;
    if (p == 'C' && d.party != null) return addressDoc(d)?.shipState ?? cust(d.party!).state; // GST follows the ship-to state
    if (p == 'S' && d.party != null) return sup(d.party!).state;
    return wh(d.wh).state;
  }

  Calc calc(Doc d) {
    double sub = 0, tax = 0;
    var qty = 0;
    for (final l in d.lines) {
      final a = l.qty * l.rate;
      sub += a;
      tax += a * item(l.item).gst / 100;
      qty += l.qty;
    }
    final inter = partyState(d) != wh(d.wh).state;
    double r2(double v) => (v * 100).round() / 100;
    return Calc(r2(sub), r2(tax), r2(sub + tax), inter, qty);
  }

  String nextId(String t) {
    final d = dt[t]!;
    d.seq++;
    return '${d.prefix}${d.seq.toString().padLeft(4, '0')}';
  }

  Doc mk(Doc d, {double? amount, bool log = true}) {
    if (d.id.isEmpty) d.id = nextId(d.type);
    d.amount = amount ?? calc(d).total;
    if (log && d.log.isEmpty) {
      d.log.add(LogEntry(d.date, d.by ?? Users.sys, '${dt[d.type]!.label} created${d.ref != null ? ' from ${d.ref}' : ''}', 'plus'));
    }
    docs.insert(0, d);
    return d;
  }

  void logDoc(Doc d, String what, [String who = Users.mgr, String icon = 'check']) {
    d.log.add(LogEntry(nowStamp(), who, what, icon));
  }

  void setStatus(Doc d, String s, [String who = Users.mgr, String? note]) {
    d.status = s;
    logDoc(d, 'Status → $s${note != null ? ' · $note' : ''}', who);
  }

  void link(Doc? a, Doc? b) {
    if (a != null && b != null && !a.refs.contains(b.id)) a.refs.add(b.id);
  }

  double outstanding(String custId) => docsOf('INV').where((i) => i.party == custId && i.status != 'Paid').fold(0.0, (a, i) => a + i.amount - i.paid);
  List<Doc> overdueInv(String custId) =>
      docsOf('INV').where((i) => i.party == custId && i.status != 'Paid' && i.due != null && daysBetween(i.due!, todayStr()) > 0).toList();

  void reserveSO(Doc so, bool on) {
    for (final l in so.lines) {
      stk(so.wh, l.item).reserved += on ? l.qty : -l.qty;
    }
    so.reserved = on;
  }

  void postStock(String w, String i, int qty, String type, String ref, [String who = Users.sys]) {
    final s = stk(w, i);
    s.onhand += qty;
    ledger.insert(0, LedgerEntry(todayStr(), nowStr(), w, i, type, qty, s.onhand, ref, who, qty.abs() * item(i).cost));
  }

  // ---------------- pricing ----------------
  ({double rate, String src}) salesPrice(String custId, String itemId, int qty) {
    final c = cust(custId), p = item(itemId);
    for (final t in tradeAgreements) {
      if (t.kind == 'Sales' && t.party == custId && t.item == itemId && t.status == 'Active' && qty >= t.minQty) {
        return (rate: t.price, src: 'Trade agreement ${t.id}');
      }
    }
    final pl = priceLists.where((l) => l.group == c.group).firstOrNull ?? priceLists.firstOrNull;
    if (pl != null && pl.disc > 0) return (rate: (p.price * (100 - pl.disc) / 100).roundToDouble(), src: '${pl.name} price list (−${pl.disc}%)');
    return (rate: p.price, src: 'Item base price');
  }

  ({double rate, String src}) purchasePrice(String supId, String itemId, int qty) {
    final p = item(itemId);
    for (final t in tradeAgreements) {
      if (t.kind == 'Purchase' && t.party == supId && t.item == itemId && t.status == 'Active' && qty >= t.minQty) {
        return (rate: t.price, src: 'Trade agreement ${t.id}');
      }
    }
    return (rate: p.cost, src: 'Item standard cost');
  }

  // ---------------- KPIs ----------------
  double stockValue([String? w]) {
    double v = 0;
    for (final p in items) {
      final q = w != null ? stk(w, p.id).onhand : warehouses.fold<int>(0, (a, x) => a + stk(x.id, p.id).onhand);
      v += q * p.cost;
    }
    return v;
  }

  int belowReorder() {
    var n = 0;
    for (final p in items) {
      for (final w in warehouses) {
        if (avail(w.id, p.id) < p.reorder) n++;
      }
    }
    return n;
  }

  String suggestBin(String itemId) {
    const m = {
      'Packaging': 'B-01', 'Material Handling': 'B-03', 'Storage': 'B-03', 'Consumables': 'A-02',
      'Safety & PPE': 'A-01', 'Electricals': 'A-03', 'Chemicals & Cleaning': 'A-01', 'Plumbing': 'B-02'
    };
    return m[item(itemId).cat] ?? 'A-04';
  }

  String fefoBatch(String w, String itemId) {
    final today = todayStr();
    // only batches that can be sold: not quarantined or expired, not empty, not past their expiry date
    final b = batches
        .where((x) => x.item == itemId && x.wh == w && x.status != 'Quarantine' && x.status != 'Expired' && x.qty > 0 && (x.exp.length < 10 || x.exp.compareTo(today) > 0))
        .toList()
      ..sort((a, b) => a.exp.compareTo(b.exp));
    return b.isEmpty ? '' : b.first.id;
  }

  double spAchieved(SalesPerson sp) => docsOf('SO').where((s) => terrOf[s.party] == sp.terr && !['Rejected', 'Draft'].contains(s.status)).fold(0.0, (a, s) => a + s.amount);

  ({String s, String ld}) vehStatus(Vehicle v) {
    for (final l in docsOf('LD')) {
      if (l.vehicle == v.name && l.status != 'Dispatched') return (s: l.status == 'Loading' ? 'Loading' : 'Assigned', ld: l.id);
    }
    for (final l in docsOf('LD')) {
      if (l.vehicle == v.name && l.status == 'Dispatched' && l.date == todayStr()) return (s: 'On Route', ld: l.id);
    }
    return (s: 'Available', ld: '');
  }

  String emailOfCust(String id) {
    for (final c in contacts) {
      if (c.cust == id && c.primary == 'Yes') return c.email;
    }
    return 'accounts@customer.in';
  }

  String emailOfSup(String id) {
    final s = sup(id);
    return '${s.contact.split(' ').first.toLowerCase()}@${s.name.split(' ').first.toLowerCase()}.in';
  }

  int _rnd(int max) => math.Random().nextInt(max);
}
