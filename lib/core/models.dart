// Data models for IMPACGO Chain.

class Warehouse {
  final String id, code, name, city, state, gstin, manager, type, area, status, wms;
  final int docks;
  /// The branch it belongs to and the site it stands on (chosen on the warehouse form).
  final String branch, site;
  const Warehouse(this.id, this.code, this.name, this.city, this.state, this.gstin, this.manager, this.type, this.area, this.docks, this.status, this.wms, {this.branch = '', this.site = ''});
}

class Bin {
  String wh, code, zone, type, cap;
  int use;
  String status = 'Active';
  Bin(this.wh, this.code, this.zone, this.type, this.cap, this.use);
}

class Customer {
  String id, name, city, state, gstin, group, contact, phone, status;
  /// Typed on the customer form: email, billing and shipping address, GST registration type.
  String email = '', billTo = '', shipTo = '', gstType = 'Registered';
  int terms;
  double limit;
  Customer(this.id, this.name, this.city, this.state, this.gstin, this.group, this.terms, this.limit, this.contact, this.phone, this.status);
}

class Supplier {
  String id, name, city, state, gstin, contact, status;
  /// Typed on the supplier form.
  String phone = '', email = '', address = '', gstType = 'Registered';
  int terms, lead, otd, quality;
  double rating;
  Supplier(this.id, this.name, this.city, this.state, this.gstin, this.terms, this.lead, this.otd, this.quality, this.rating, this.contact, this.status);
}

class Item {
  String id, name, cat, hsn, uom, sup, track;
  /// Goods or Service, Active or not, and the shelf life in days (batch-tracked items).
  String type = 'Goods', status = 'Active';
  int shelfLife = 0;
  int gst, reorder, moq, mult, lead;
  double cost, price;
  List<int> stock;
  Item(this.id, this.name, this.cat, this.hsn, this.gst, this.uom, this.cost, this.price, this.reorder, this.moq, this.mult, this.lead, this.sup, this.track, this.stock);
}

class PriceList {
  String id, name, group, valid, status;
  int disc;
  PriceList(this.id, this.name, this.group, this.disc, this.valid, this.status);
}

class TradeAgreement {
  String id, kind, party, item, from, to, status;
  double price;
  int minQty;
  TradeAgreement(this.id, this.kind, this.party, this.item, this.price, this.from, this.to, this.minQty, this.status);
}

class Carrier {
  String id, name, mode, lanes, rate, status;
  int otd, active;
  Carrier(this.id, this.name, this.mode, this.lanes, this.rate, this.otd, this.active, this.status);
}

class StockCell {
  int onhand, reserved, transit;
  StockCell(this.onhand, {this.reserved = 0, this.transit = 0});
  int get avail => onhand - reserved;
}

class LedgerEntry {
  String date, time, wh, item, type, ref, who;
  int qty, bal;
  double value;
  LedgerEntry(this.date, this.time, this.wh, this.item, this.type, this.qty, this.bal, this.ref, this.who, this.value);
}

class Line {
  String item;
  int qty;
  double rate;
  int recv;
  /// What the line is, as typed on the form (defaults to the item name).
  String? desc;
  String bin, batch, from;
  int? sys, cnt;
  int acc;
  Line(this.item, this.qty, this.rate, {this.recv = 0, this.bin = '', this.batch = '', this.from = '', this.sys, this.cnt, this.acc = 0});
  // the batch / serial numbers and the bin go with the line from pick list to packing slip to delivery note
  Line copy() => Line(item, qty, rate, bin: bin, batch: batch, from: from)..desc = desc;
}

class LogEntry {
  final String when, who, what, icon;
  LogEntry(this.when, this.who, this.what, this.icon);
}

class Quote {
  final String sup, valid;
  final double rate;
  final int lead;
  Quote(this.sup, this.rate, this.lead, this.valid);
}

class MatchResult {
  final bool ok;
  final String msg;
  MatchResult(this.ok, this.msg);
}

class Doc {
  String id, type, date, wh, status;
  String? party, to, ref, by;
  List<Line> lines;
  List<String> refs = [];
  List<LogEntry> log = [];
  double amount = 0, paid = 0;
  // optional attributes (only some document types use them)
  String? delivery, valid, need, source, due, irn, eway, supInv, challan, wave, picker;
  /// Customer documents: the chosen billing / shipping address and the ship-to state (decides CGST+SGST or IGST).
  String? billTo, shipTo, shipState;
  /// Sales order: the customer's own purchase order number.
  String? custPo;
  /// Stock transfer: who sent it and who received it. Stock adjustment: who approved it.
  String? transferredBy, receivedBy, approvedBy;
  /// Purchase request: why the purchase is needed, who asked, for which department.
  String? purpose, requester, dept;
  /// Goods receipt: quality check details.
  String? qcBy, qcResult, qcNote, qcDate;
  /// Date the QC team sent the QC report to the goods receipt (until then it cannot be downloaded there).
  String? qcSent;
  /// Other form fields (buyer, references, terms …) kept exactly as entered on the form.
  Map<String, String> extra = {};
  String? carrier, vehicle, awb, eta, pod, route, reason, zone, counter, mode, utr, hold, note, close, weight;
  int? cartons, util;
  List<String> dns = [];
  List<Quote> quotes = [];
  List<String> invited = [];
  MatchResult? match;
  bool reserved = false;
  Doc({required this.id, required this.type, required this.date, required this.wh, required this.status, this.party, this.to, this.ref, this.by, List<Line>? lines})
      : lines = lines ?? [];
}

class Batch {
  String id, item, wh, mfg, exp, sup, status;
  int qty;
  Batch(this.id, this.item, this.wh, this.qty, this.mfg, this.exp, this.sup, this.status);
}

class Serial {
  String id, item, wh, status, ref;
  Serial(this.id, this.item, this.wh, this.status, this.ref);
}

class DocType {
  final String label, plural, view, party;
  final List<String> steps;
  /// The text every document number starts with, and the last number used (editable on Number Series).
  String prefix;
  int seq;
  DocType(this.label, this.plural, this.view, this.party, this.steps, this.prefix, this.seq);
}

/// A number series that is saved but not in use. A document type numbers its documents with one active
/// series at a time (DocType.prefix and DocType.seq); the others wait here until they are made active.
class SeriesEntry {
  String key, prefix;
  int seq;
  SeriesEntry(this.key, this.prefix, this.seq);
}

// ---- CRM / extra masters ----
class Territory {
  String id, name, states, cities, manager, wh;
  String code = '', parent = '—', country = 'India', status = 'Active';
  double targetRev = 0;
  Territory(this.id, this.name, this.states, this.cities, this.manager, this.wh);
}

class SalesPerson {
  String id, name, terr, phone, status;
  String email = '';
  double target;
  SalesPerson(this.id, this.name, this.terr, this.phone, this.target, this.status);
}

class Contact {
  String name, cust, role, phone, email, primary;
  Contact(this.name, this.cust, this.role, this.phone, this.email, this.primary);
}

class Lead {
  String id, company, contact, city, state, source, owner, date, status, interest;
  double value;
  String? opp;
  /// Why the lead was marked lost.
  String? lostReason;
  /// Contact details typed when the lead was created (mobile or email is required).
  String phone = '', email = '';
  Lead(this.id, this.company, this.contact, this.city, this.state, this.source, this.owner, this.value, this.date, this.status, this.interest);
}

class OppLine {
  String item;
  int qty;
  OppLine(this.item, this.qty);
}

class Opportunity {
  String id, party, title, owner, close, stage;
  double value;
  int prob;
  List<OppLine> lines;
  String? quote, lead;
  /// Why the opportunity was marked lost.
  String? lostReason;
  Opportunity(this.id, this.party, this.title, this.owner, this.value, this.prob, this.close, this.stage, this.lines, {this.quote, this.lead});
}

class CustomerGroup {
  String id, name, price, desc;
  String parent = '', status = 'Active';
  int terms;
  double credit;
  CustomerGroup(this.id, this.name, this.price, this.terms, this.credit, this.desc);
}

class SupplierGroup {
  String id, name, desc;
  int terms;
  List<String> members;
  SupplierGroup(this.id, this.name, this.terms, this.members, this.desc);
}

class Uom {
  String code, name, type, base;
  double factor;
  Uom(this.code, this.name, this.type, this.base, this.factor);
}

class TrackGroup {
  String id, name, batch, serial, expiry, desc;
  TrackGroup(this.id, this.name, this.batch, this.serial, this.expiry, this.desc);
}

class StorageGroup {
  String id, name, site, wh, loc, desc;
  StorageGroup(this.id, this.name, this.site, this.wh, this.loc, this.desc);
}

class Site {
  String id, name, gstin, address;
  List<String> whs;
  Site(this.id, this.name, this.gstin, this.whs, this.address);
}

class BinMove {
  String id, date, wh, item, from, to, reason, status, by;
  int qty;
  BinMove(this.id, this.date, this.wh, this.item, this.from, this.to, this.qty, this.reason, this.status, this.by);
}

class Vehicle {
  String id, name, type, wh, driver, cap, tmpl;
  /// Chosen on the vehicle form: its state (Available, Under Maintenance…) and whether it is Own, Leased or a Carrier's.
  String status = 'Available', own = 'Own';
  Vehicle(this.id, this.name, this.type, this.wh, this.driver, this.cap, this.tmpl);
}

class LoadTemplate {
  String id, name, weight, volume, use;
  int pallets;
  LoadTemplate(this.id, this.name, this.weight, this.volume, this.pallets, this.use);
}

// ---- automation ----
class AutoLog {
  String when, job, result, docs, by;
  AutoLog(this.when, this.job, this.result, this.docs, this.by);
}

class Email {
  String when, to, subject, doc, status;
  Email(this.when, this.to, this.subject, this.doc, this.status);
}

class ReportSchedule {
  String id, report, freq, to, format, status;
  ReportSchedule(this.id, this.report, this.freq, this.to, this.format, this.status);
}

class Valuation {
  String month, when;
  double value;
  int items;
  Valuation(this.month, this.when, this.value, this.items);
}

class Job {
  final String id, name, what, freq;
  String status, last, result;
  final List<String> Function() run; // returns [result, docs]
  Job(this.id, this.name, this.what, this.freq, this.run, {this.status = 'Active', this.last = '', this.result = ''});
}

class AutoRule {
  final String mod, trig, act, mode;
  const AutoRule(this.mod, this.trig, this.act, this.mode);
}


/// One address of a customer. A customer can have several (head office, branches, warehouses).
class Address {
  String label, type, line, city, state, pin;
  Address(this.label, this.type, this.line, this.city, this.state, this.pin);
  bool get billing => type != 'Shipping only';
  bool get shipping => type != 'Billing only';
  String get text => '$line, $city, $state - $pin';
  String get full => '$label · $text';
}

const addressTypes = ['Billing & Shipping', 'Billing only', 'Shipping only'];

/// GST state codes (first two digits of a GSTIN), used for the place of supply.
const kStateCodes = {
  'Andaman and Nicobar Islands': '35', 'Andhra Pradesh': '37', 'Arunachal Pradesh': '12', 'Assam': '18', 'Bihar': '10', 'Chandigarh': '04',
  'Chhattisgarh': '22', 'Dadra and Nagar Haveli and Daman and Diu': '26', 'Delhi': '07', 'Goa': '30', 'Gujarat': '24', 'Haryana': '06',
  'Himachal Pradesh': '02', 'Jammu and Kashmir': '01', 'Jharkhand': '20', 'Karnataka': '29', 'Kerala': '32', 'Ladakh': '38', 'Lakshadweep': '31',
  'Madhya Pradesh': '23', 'Maharashtra': '27', 'Manipur': '14', 'Meghalaya': '17', 'Mizoram': '15', 'Nagaland': '13', 'Odisha': '21',
  'Puducherry': '34', 'Punjab': '03', 'Rajasthan': '08', 'Sikkim': '11', 'Tamil Nadu': '33', 'Telangana': '36', 'Tripura': '16',
  'Uttar Pradesh': '09', 'Uttarakhand': '05', 'West Bengal': '19',
};

/// Every Indian state and union territory, A–Z, for state dropdowns.
final List<String> kStates = kStateCodes.keys.toList();

/// Quality check is finished for a goods receipt (not waiting and not with the QC team).
/// What the QC report says under "Rejection reason": the reason when units were rejected, otherwise that everything passed.
String qcRejectionText(Doc g) {
  final rej = g.lines.fold<int>(0, (a, l) => a + (l.qty > l.acc ? l.qty - l.acc : 0));
  if (rej <= 0) return 'Nil — all passed in quality check';
  return (g.qcNote ?? '').isNotEmpty ? g.qcNote! : '$rej unit(s) rejected during quality inspection';
}

/// Rejected units of a goods receipt that are not on a purchase return yet (what can still be returned).
int returnableQty(Doc g, Line l, Iterable<Doc> returns) {
  final rejected = l.qty > l.acc ? l.qty - l.acc : 0;
  final returned = returns.where((r) => r.ref == g.id && r.status != 'Rejected').fold<int>(0, (a, r) => a + r.lines.where((x) => x.item == l.item).fold<int>(0, (b, x) => b + x.qty));
  return rejected > returned ? rejected - returned : 0;
}

bool qcDone(Doc g) => !const ['QC Pending', 'QC Requested'].contains(g.status);

// ---- Setup lists (Company Settings) ----
class Branch {
  String name, company, city, state, postal, taxReg, manager, address, phone, email, status;
  Branch(this.name, {this.company = 'IMPACGO Logistics Pvt Ltd', this.city = '', this.state = '', this.postal = '', this.taxReg = '', this.manager = '', this.address = '', this.phone = '', this.email = '', this.status = 'Active'});
}

class Currency {
  String code, name, symbol, status;
  double rate;
  int decimals;
  Currency(this.code, this.name, this.symbol, this.rate, {this.decimals = 2, this.status = 'Active'});
}

class PayTerm {
  String name, desc, status;
  int days, advance, discDays;
  double discPct;
  PayTerm(this.name, this.days, {this.advance = 0, this.discDays = 0, this.discPct = 0, this.desc = '', this.status = 'Active'});
}

class TaxCode {
  String name, type, status;
  double rate;
  TaxCode(this.name, this.rate, {this.type = 'GST', this.status = 'Active'});
}

class TcTemplate {
  String name, applies, text, status;
  TcTemplate(this.name, this.applies, this.text, {this.status = 'Active'});
}
