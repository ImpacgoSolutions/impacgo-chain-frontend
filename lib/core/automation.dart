part of 'store.dart';

class BankLine {
  final String ref, narr, conf;
  final double amount;
  final String? inv;
  BankLine(this.ref, this.narr, this.amount, this.inv, this.conf);
}

extension ScmAutomation on AppStore {
  void sendEmail(String to, String subject, String docId) => emails.insert(0, Email(nowStamp(), to, subject, docId, 'Sent'));

  void addAutoLog(String job, String result, String docsTxt, [String by = 'Run now · Srinivas Rao']) =>
      autoLog.insert(0, AutoLog(nowStamp(), job, result, docsTxt.isEmpty ? '—' : docsTxt, by));

  // ---------------- bank statement matching ----------------
  List<BankLine> bankLines() {
    final open = docsOf('INV').where((i) => i.status != 'Paid').toList()..sort((a, b) => b.date.compareTo(a.date));
    final out = <BankLine>[];
    for (var k = 0; k < open.length && k < 2; k++) {
      final i = open[k];
      final c = cust(i.party!);
      final nm = c.name.toUpperCase();
      out.add(BankLine('UTR N${2931 + k} ${5501 + k * 7}', 'NEFT CR ${nm.substring(0, math.min(22, nm.length))}', ((i.amount - i.paid) * 100).round() / 100, i.id, 'Exact amount + name'));
    }
    out.add(BankLine('UTR R2934 0012', 'RTGS CR UNKNOWN REMITTER', 12500, null, 'No match — needs review'));
    return out;
  }

  void postBankLine(BankLine l) {
    final d = l.inv == null ? null : doc(l.inv!);
    if (d == null || d.status == 'Paid') return;
    final amt = math.min(l.amount, d.amount - d.paid);
    final cp = mk(Doc(id: '', type: 'CP', date: todayStr(), wh: d.wh, status: 'Allocated', party: d.party, ref: d.id)
      ..mode = 'NEFT'
      ..utr = l.ref, amount: amt);
    logDoc(cp, 'Matched from bank statement: ${l.narr}', Users.sys, 'eye');
    d.paid += amt;
    setStatus(d, d.paid >= d.amount - 0.5 ? 'Paid' : 'Partially Paid', Users.sys, 'bank match ${cp.id}');
    link(d, cp);
    if (d.status == 'Paid') {
      final so = d.ref == null ? null : doc(d.ref!);
      if (so != null && so.type == 'SO' && so.status == 'Delivered') setStatus(so, 'Closed', Users.sys, 'delivered and fully paid');
    }
  }

  int postBank(List<BankLine> lines) {
    final m = lines.where((l) => l.inv != null).toList();
    for (final l in m) {
      postBankLine(l);
    }
    addAutoLog('Bank statement matching', '${m.length} receipt(s) matched and posted · ${lines.length - m.length} left for review', m.map((l) => l.inv).join(', '));
    return m.length;
  }

  // ---------------- scheduled jobs ----------------
  String runJob(Job j, [String by = 'Run now · Srinivas Rao']) {
    if (j.status != 'Active') return '${j.name} is paused — resume it first';
    final r = j.run();
    j.last = nowStamp();
    j.result = r[0];
    addAutoLog(j.name, r[0], r.length > 1 ? r[1] : '—', by);
    return '${j.name} · ${r[0]}';
  }

  int runAllJobs() {
    var n = 0;
    for (final j in jobs) {
      if (j.status == 'Active') {
        runJob(j, 'Run all · Srinivas Rao');
        n++;
      }
    }
    return n;
  }

  void _reorderQuiet() {
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
          autoPR(w.id, p.id, q, 'Reorder check (auto)');
        }
      }
    }
  }
}

void _seedAutomation(AppStore s) {
  s.autoLog.addAll([
    AutoLog('2026-09-28 06:00', 'Reorder check', '1 purchase request raised', 'PR-2026-0233', 'Scheduler'),
    AutoLog('2026-09-28 07:00', 'Expiry check', '2 batches flagged Expiring Soon', 'B2604-BAT-02, B2603-DTG-04', 'Scheduler'),
    AutoLog('2026-09-28 08:00', 'Report emails', 'Receivables ageing sent to 2 people', '—', 'Scheduler'),
    AutoLog('2026-09-28 08:30', 'Credit hold review', '1 order stays on hold (overdue not cleared)', 'SO-2026-0314', 'Scheduler'),
    AutoLog('2026-09-28 09:00', 'Overdue reminders', '1 reminder emailed', 'INV/26-27/0186', 'Scheduler'),
    AutoLog('2026-09-28 10:00', 'Carrier tracking sync', '2 shipments updated', 'SHP-2026-0271, SHP-2026-0270', 'Scheduler'),
  ]);
  s.emails.addAll([
    Email('2026-09-28 09:00', 'imran@deccanhw.in', 'Payment reminder · INV/26-27/0186 overdue 40 days', 'INV/26-27/0186', 'Sent'),
    Email('2026-09-28 08:00', 'srinivas@impacgo.com, meena@impacgo.com', 'Daily report · Receivables ageing', '—', 'Sent'),
    Email('2026-09-27 16:20', 'sanjay@metromart.in', 'Quotation QT-2026-0140 from IMPACGO Chain', 'QT-2026-0140', 'Sent'),
    Email('2026-09-21 11:05', 'vikram@polypack.in', 'Purchase order PO-2026-0421', 'PO-2026-0421', 'Sent'),
  ]);
  s.reportSchedules.addAll([
    ReportSchedule('RS-01', 'Receivables ageing', 'Daily 08:00', 'srinivas@impacgo.com, meena@impacgo.com', 'PDF + CSV', 'Active'),
    ReportSchedule('RS-02', 'Delivery schedule', 'Daily 07:30', 'kiran@impacgo.com, farhana@impacgo.com', 'PDF', 'Active'),
    ReportSchedule('RS-03', 'Stock valuation', 'Monthly · last day 23:00', 'meena@impacgo.com', 'CSV', 'Active'),
    ReportSchedule('RS-04', 'Supplier performance', 'Monthly · 1st 09:00', 'harish@impacgo.com', 'PDF', 'Active'),
  ]);
  s.valuations.add(Valuation('Aug 2026', '2026-08-31 23:00', 15480220, 14));

  s.jobs.addAll([
    Job('JOB-01', 'Reorder check', 'Raises purchase requests for items whose available + on-order stock is below reorder level', 'Daily 06:00', () {
      final n = s.docsOf('PR').length;
      s._reorderQuiet();
      final made = s.docsOf('PR').take(s.docsOf('PR').length - n).map((d) => d.id).toList();
      return [made.isEmpty ? 'All items above reorder level' : '${made.length} purchase request(s) raised', made.join(', ')];
    }),
    Job('JOB-02', 'Expiry check', 'Flags batches expiring within 30 days so they are picked first', 'Daily 07:00', () {
      var fresh = 0;
      for (final b in s.batches) {
        if (b.exp != '—' && b.status == 'Released' && daysBetween(todayStr(), b.exp) <= 30) {
          b.status = 'Expiring Soon';
          fresh++;
        }
      }
      final all = s.batches.where((b) => b.status == 'Expiring Soon').map((b) => b.id).toList();
      return ['${all.length} batch(es) expiring within 30 days${fresh > 0 ? ' · $fresh newly flagged' : ''}', all.join(', ')];
    }),
    Job('JOB-03', 'Credit hold review', 'Releases orders on hold once the customer has no overdue invoice and is within limit', 'Daily 08:30', () {
      final rel = <String>[], stay = <String>[];
      for (final so in s.docsOf('SO').where((x) => x.status == 'On Hold')) {
        final c = s.cust(so.party!);
        if (s.overdueInv(so.party!).isEmpty && s.outstanding(so.party!) + so.amount <= c.limit) {
          s.logDoc(so, 'Hold cleared by credit review job', Users.sys, 'eye');
          so.hold = null;
          s.approvalSO(so);
          rel.add(so.id);
        } else {
          stay.add(so.id);
        }
      }
      return ['${rel.length} released · ${stay.length} still on hold', [...rel, ...stay].join(', ')];
    }),
    Job('JOB-04', 'Overdue reminders', 'Emails customers whose invoices are past the due date', 'Daily 09:00', () {
      final od = s.docsOf('INV').where((i) => i.status != 'Paid' && i.due != null && daysBetween(i.due!, todayStr()) > 0).toList();
      for (final i in od) {
        s.sendEmail(s.emailOfCust(i.party!), 'Payment reminder · ${i.id} overdue ${daysBetween(i.due!, todayStr())} days · balance ${fmtINR(i.amount - i.paid)}', i.id);
        s.logDoc(i, 'Overdue reminder emailed', Users.sys, 'alert');
      }
      return ['${od.length} reminder(s) emailed', od.map((i) => i.id).join(', ')];
    }),
    Job('JOB-05', 'Carrier tracking sync', 'Pulls the latest status of every open shipment from the carrier', 'Every 2 hours', () {
      final u = s.docsOf('SHP').where((x) => x.status != 'Delivered').where((x) => s.shpAdvance(x)).toList();
      return ['${u.length} shipment(s) updated', u.map((x) => '${x.id} → ${x.status}').join(', ')];
    }),
    Job('JOB-06', 'Bank statement matching', 'Imports the day’s bank statement and matches receipts to open invoices', 'Daily 18:00', () {
      final m = s.bankLines().where((l) => l.inv != null).toList();
      for (final l in m) {
        s.postBankLine(l);
      }
      return ['${m.length} receipt(s) matched and posted', m.map((l) => l.inv).join(', ')];
    }),
    Job('JOB-07', 'Payment proposal', 'Lists approved supplier invoices due in the next 7 days for the weekly payment run', 'Weekly · Fri 10:00', () {
      final due = s.docsOf('PI').where((p) => p.status == 'Approved').toList();
      final tot = due.fold<double>(0, (a, p) => a + p.amount - p.paid);
      return ['${due.length} invoice(s) ready · ${fmtINR(tot)} · waiting for approval', due.map((p) => p.id).join(', ')];
    }),
    Job('JOB-08', 'Month-end stock valuation', 'Saves the stock value snapshot for accounts', 'Monthly · last day 23:00', () {
      final v = s.stockValue();
      s.valuations.insert(0, Valuation('Sep 2026', nowStamp(), v, s.items.length));
      return ['Snapshot saved · ${fmtINR(v)}', 'Sep 2026'];
    }),
    Job('JOB-09', 'Report emails', 'Sends every active report schedule to its recipients', 'As per schedule', () {
      final a = s.reportSchedules.where((r) => r.status == 'Active').toList();
      for (final r in a) {
        s.sendEmail(r.to, 'Scheduled report · ${r.report} (${r.format})', '—');
      }
      return ['${a.length} report(s) emailed', a.map((r) => r.report).join(', ')];
    }),
  ]);
  for (final j in s.jobs) {
    AutoLog? l;
    for (final x in s.autoLog) {
      if (x.job == j.name) {
        l = x;
        break;
      }
    }
    j.last = l?.when ?? '2026-09-26 10:00';
    j.result = l?.result ?? 'Completed';
  }

  s.rules.addAll(const [
    AutoRule('Sales', 'Quotation / order saved', 'Price from trade agreement → price list → base price', 'AUTO'),
    AutoRule('Sales', 'Order saved', 'Credit check · hold if overdue or over limit', 'AUTO'),
    AutoRule('Sales', 'Order above approval limit', 'Route to SCM manager for approval', 'AUTO'),
    AutoRule('Sales', 'Order confirmed', 'Reserve stock · raise PR if short', 'AUTO'),
    AutoRule('Sales', 'Order released', 'Pick list with bin and earliest-expiry batch', 'SEMI'),
    AutoRule('Sales', 'Picking confirmed', 'Packing slip created', 'AUTO'),
    AutoRule('Sales', 'Packing confirmed', 'Delivery note · added to planned load', 'AUTO'),
    AutoRule('Sales', 'Delivery dispatched', 'Stock issue, invoice, e-invoice reference, e-way bill, shipment, invoice email', 'AUTO'),
    AutoRule('Sales', 'Shipment delivered', 'Delivery note and order marked delivered', 'AUTO'),
    AutoRule('Sales', 'Invoice fully paid', 'Order closed', 'AUTO'),
    AutoRule('Sales', 'Return received', 'Credit note applied to invoice', 'SEMI'),
    AutoRule('CRM', 'Lead qualified', 'Customer and opportunity created', 'SEMI'),
    AutoRule('CRM', 'Opportunity proposal', 'Quotation created with rule-based prices', 'SEMI'),
    AutoRule('Procurement', 'Stock below reorder', 'Purchase request (minimum order quantity applied)', 'AUTO'),
    AutoRule('Procurement', 'RFQ awarded', 'PO to lowest-price supplier', 'SEMI'),
    AutoRule('Procurement', 'PO within limit', 'Sent to supplier and emailed', 'AUTO'),
    AutoRule('Procurement', 'QC recorded', 'Stock posted · put-away task · return for rejects', 'AUTO'),
    AutoRule('Procurement', 'Supplier invoice entered', 'Verified against PO and goods receipt · approved automatically within price tolerance', 'AUTO'),
    AutoRule('Procurement', 'Return dispatched', 'Debit note issued', 'AUTO'),
    AutoRule('Inventory', 'Count submitted', 'Adjustments · small ones posted, large ones to approval', 'AUTO'),
    AutoRule('Inventory', 'Adjustment above limit', 'Route to approval', 'AUTO'),
    AutoRule('Warehouse', 'Picking area below minimum', 'Replenishment bin movement', 'AUTO'),
    AutoRule('Finance', 'Document date', 'Due date from payment terms', 'AUTO'),
    AutoRule('Finance', 'Place of supply', 'CGST+SGST or IGST', 'AUTO'),
  ]);
}
