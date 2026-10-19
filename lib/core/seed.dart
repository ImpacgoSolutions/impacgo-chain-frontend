part of 'store.dart';

void _seedMasters(AppStore s) {
  s.warehouses.addAll(const [
    Warehouse('W1', 'VZG-DC', 'Vizag Distribution Centre', 'Visakhapatnam', 'Andhra Pradesh', '37AAHCI4521K1Z6', 'Srinivas Rao', 'Distribution centre', '48,000 sq ft', 6, 'Active', 'Advanced (bins, pick batches, storage rules)'),
    Warehouse('W2', 'VJA-HUB', 'Vijayawada Fulfilment Hub', 'Vijayawada', 'Andhra Pradesh', '37AAHCI4521K1Z6', 'Kiran Kumar', 'Fulfilment hub', '22,000 sq ft', 3, 'Active', 'Advanced (bins, pick batches, storage rules)'),
    Warehouse('W3', 'HYD-DC', 'Hyderabad Distribution Centre', 'Hyderabad', 'Telangana', '36AAHCI4521K1Z8', 'Farhana Begum', 'Distribution centre', '36,000 sq ft', 5, 'Active', 'Advanced (bins, pick batches, storage rules)'),
  ]);
  for (final w in s.warehouses) {
    s.bins.add(Bin(w.id, 'RCV-01', 'Receiving dock', 'Inbound staging', '40 pallets', 35));
    const a = ['A-01', 'A-02', 'A-03', 'A-04'], au = [72, 64, 81, 48];
    for (var i = 0; i < 4; i++) {
      s.bins.add(Bin(w.id, a[i], 'A · Picking Area', 'Picking', '8 pallets', au[i]));
    }
    const b = ['B-01', 'B-02', 'B-03'], bu = [58, 77, 40];
    for (var i = 0; i < 3; i++) {
      s.bins.add(Bin(w.id, b[i], 'B · Bulk storage', 'Reserve', '24 pallets', bu[i]));
    }
    s.bins.add(Bin(w.id, 'QRN-01', 'Quarantine', 'QC hold / damaged', '10 pallets', 20));
    s.bins.add(Bin(w.id, 'DSP-01', 'Dispatch bay', 'Outbound staging', '30 pallets', 28));
  }
  s.customers.addAll([
    Customer('C001', 'Sri Lakshmi Supermarkets', 'Visakhapatnam', 'Andhra Pradesh', '37AABFS2231L1Z4', 'Key Account', 30, 800000, 'Ramesh Babu', '+91 98480 22110', 'Active'),
    Customer('C002', 'Metro Mart Stores', 'Hyderabad', 'Telangana', '36AAKCM8812P1Z2', 'Key Account', 45, 1500000, 'Sanjay Reddy', '+91 99496 71120', 'Active'),
    Customer('C003', 'Kaveri Distributors', 'Chennai', 'Tamil Nadu', '33AAHFK4410Q1Z9', 'Wholesale', 30, 600000, 'M. Venkatesh', '+91 94440 38821', 'Active'),
    Customer('C004', 'Godavari Traders', 'Rajahmundry', 'Andhra Pradesh', '37AAGFG1902M1Z1', 'Wholesale', 30, 400000, 'P. Satyanarayana', '+91 98851 44390', 'Active'),
    Customer('C005', 'Deccan Hardware', 'Hyderabad', 'Telangana', '36AAEFD7781K1Z5', 'Retail', 30, 250000, 'Imran Khan', '+91 90000 51287', 'Credit Hold'),
    Customer('C006', 'Coastal FreshMart', 'Kakinada', 'Andhra Pradesh', '37AAJFC5520H1Z7', 'Retail', 15, 200000, 'Lavanya K', '+91 97012 66030', 'Active'),
    Customer('C007', 'Bengaluru Retail Hub', 'Bengaluru', 'Karnataka', '29AAICB3345R1Z3', 'Key Account', 45, 1200000, 'Arjun Shetty', '+91 98450 12093', 'Active'),
    Customer('C008', 'Nellore Agencies', 'Nellore', 'Andhra Pradesh', '37AAPFN6621D1Z8', 'Retail', 15, 150000, 'K. Mahesh', '+91 94405 70021', 'Active'),
  ]);
  s.suppliers.addAll([
    Supplier('S001', 'SafeGuard Industrial Supplies', 'Chennai', 'Tamil Nadu', '33AAFCS9021B1Z6', 30, 5, 94, 98, 4.6, 'Deepa Raman', 'Approved'),
    Supplier('S002', 'Polypack Films', 'Hyderabad', 'Telangana', '36AAGFP3310C1Z2', 30, 4, 91, 97, 4.4, 'Vikram Jain', 'Approved'),
    Supplier('S003', 'Andhra Corrugators', 'Visakhapatnam', 'Andhra Pradesh', '37AABFA7719E1Z0', 15, 2, 97, 95, 4.7, 'N. Prasad', 'Approved'),
    Supplier('S004', 'Lumina Electricals', 'Bengaluru', 'Karnataka', '29AADCL5566F1Z9', 45, 7, 86, 96, 4.1, 'Rohit Nair', 'Approved'),
    Supplier('S005', 'Tirupati Cables', 'Tirupati', 'Andhra Pradesh', '37AAECT2208G1Z4', 30, 6, 89, 99, 4.5, 'S. Chandra', 'Approved'),
    Supplier('S006', 'HydraLift Equipment', 'Pune', 'Maharashtra', '27AAFCH4471H1Z1', 45, 10, 82, 97, 4.0, 'Amol Patil', 'Approved'),
    Supplier('S007', 'CleanChem Products', 'Vijayawada', 'Andhra Pradesh', '37AAHFC8830J1Z5', 30, 3, 95, 93, 4.3, 'G. Suresh', 'Approved'),
    Supplier('S008', 'Aqua Pure Beverages', 'Visakhapatnam', 'Andhra Pradesh', '37AAJFA1127K1Z3', 15, 1, 98, 96, 4.8, 'Kavya M', 'On Probation'),
  ]);
  s.categories.addAll(['Safety & PPE', 'Packaging', 'Electricals', 'Plumbing', 'Material Handling', 'Chemicals & Cleaning', 'Consumables', 'Storage']);
  s.items.addAll([
    Item('ITM-1001', 'Industrial Safety Helmet', 'Safety & PPE', '6506', 18, 'Nos', 320, 450, 120, 50, 10, 5, 'S001', 'None', [420, 180, 260]),
    Item('ITM-1002', 'Nitrile Gloves (Box of 100)', 'Safety & PPE', '4015', 12, 'Box', 380, 520, 200, 100, 50, 5, 'S001', 'Batch', [140, 210, 300]),
    Item('ITM-1003', 'Stretch Wrap Film 500 mm', 'Packaging', '3920', 18, 'Roll', 780, 1050, 80, 40, 20, 4, 'S002', 'None', [160, 64, 120]),
    Item('ITM-1004', 'Corrugated Carton 5-Ply', 'Packaging', '4819', 12, 'Nos', 42, 65, 1500, 1000, 500, 2, 'S003', 'None', [4200, 2600, 3100]),
    Item('ITM-1005', 'LED Floodlight 100 W', 'Electricals', '9405', 18, 'Nos', 1450, 2100, 60, 25, 5, 7, 'S004', 'Serial', [95, 40, 72]),
    Item('ITM-1006', 'Copper Cable 2.5 sq mm (90 m)', 'Electricals', '8544', 18, 'Coil', 2650, 3400, 50, 20, 10, 6, 'S005', 'Batch', [130, 55, 88]),
    Item('ITM-1007', 'PVC Pipe 4 in × 6 m', 'Plumbing', '3917', 18, 'Nos', 540, 720, 100, 50, 25, 4, 'S002', 'None', [310, 150, 205]),
    Item('ITM-1008', 'Hand Pallet Truck 2.5 T', 'Material Handling', '8427', 18, 'Nos', 14500, 18900, 8, 4, 2, 10, 'S006', 'Serial', [22, 9, 34]),
    Item('ITM-1009', 'Hand Sanitiser 5 L', 'Chemicals & Cleaning', '3808', 18, 'Can', 610, 850, 90, 40, 20, 3, 'S007', 'Batch', [240, 180, 150]),
    Item('ITM-1010', 'Lubricant Oil 20 L', 'Consumables', '2710', 18, 'Drum', 3200, 4150, 30, 10, 5, 6, 'S005', 'Batch', [64, 28, 51]),
    Item('ITM-1011', 'Packaged Drinking Water 1 L × 12', 'Consumables', '2201', 18, 'Case', 110, 160, 400, 200, 100, 1, 'S008', 'Batch', [1150, 620, 900]),
    Item('ITM-1012', 'Steel Rack Shelf Unit', 'Storage', '9403', 18, 'Set', 6200, 8200, 12, 5, 5, 8, 'S006', 'None', [38, 14, 26]),
    Item('ITM-1013', 'Barcode Label Roll', 'Consumables', '4821', 12, 'Roll', 180, 260, 250, 100, 50, 3, 'S003', 'None', [780, 340, 520]),
    Item('ITM-1014', 'Cleaning Detergent 5 kg', 'Chemicals & Cleaning', '3402', 18, 'Bag', 420, 590, 120, 60, 20, 3, 'S007', 'Batch', [290, 160, 210]),
  ]);
  s.priceLists.addAll([
    PriceList('PL-STD', 'Standard', 'Retail', 0, '2026-04-01 → 2027-03-31', 'Active'),
    PriceList('PL-WHL', 'Wholesale', 'Wholesale', 8, '2026-04-01 → 2027-03-31', 'Active'),
    PriceList('PL-KEY', 'Key Account', 'Key Account', 12, '2026-04-01 → 2027-03-31', 'Active'),
  ]);
  s.tradeAgreements.addAll([
    TradeAgreement('TA-0101', 'Sales', 'C002', 'ITM-1003', 910, '2026-07-01', '2026-12-31', 50, 'Active'),
    TradeAgreement('TA-0102', 'Sales', 'C001', 'ITM-1011', 138, '2026-06-01', '2026-11-30', 100, 'Active'),
    TradeAgreement('TA-0103', 'Sales', 'C007', 'ITM-1008', 16900, '2026-08-01', '2027-01-31', 5, 'Active'),
    TradeAgreement('TA-0104', 'Purchase', 'S001', 'ITM-1002', 365, '2026-04-01', '2027-03-31', 100, 'Active'),
    TradeAgreement('TA-0105', 'Purchase', 'S002', 'ITM-1003', 760, '2026-04-01', '2027-03-31', 40, 'Active'),
  ]);
  s.carriers.addAll([
    Carrier('CR01', 'Blue Dart', 'Air / Surface express', 'Pan-India', '₹38 / kg', 96, 4, 'Active'),
    Carrier('CR02', 'Delhivery', 'Surface · part load', 'Pan-India', '₹14 / kg', 92, 6, 'Active'),
    Carrier('CR03', 'Safexpress', 'Surface · full truck', 'South & West', '₹22,500 / FTL', 94, 3, 'Active'),
    Carrier('CR04', 'Own fleet', 'Company trucks (3)', 'AP & Telangana', '₹18 / km', 98, 2, 'Active'),
  ]);
  s.vehicles.addAll(['AP 31 TX 4521 (Own · 9 T)', 'AP 16 TB 7702 (Own · 6 T)', 'TS 09 UC 3318 (Own · 9 T)', 'Carrier assigned vehicle']);
  DocType t(String l, String p, String v, String party, List<String> st, String pre, int seq) => DocType(l, p, v, party, st, pre, seq);
  s.dt.addAll({
    'QT': t('Quotation', 'Quotations', 'quotes', 'C', ['Draft', 'Sent', 'Accepted', 'Converted'], 'QT-2026-', 141),
    'SO': t('Sales order', 'Sales Orders', 'sorders', 'C', ['Pending Approval', 'Confirmed', 'Picking', 'Packed', 'Invoiced', 'Delivered', 'Closed'], 'SO-2026-', 319),
    'PK': t('Pick list', 'Picking', 'picking', 'C', ['To Pick', 'Picked'], 'PK-2026-', 412),
    'PCK': t('Packing slip', 'Packing', 'packing', 'C', ['Packing', 'Packed'], 'PCK-2026-', 209),
    'DN': t('Delivery note', 'Deliveries', 'deliveries', 'C', ['Ready to Dispatch', 'Dispatched', 'Delivered'], 'DN-2026-', 288),
    'INV': t('Sales invoice', 'Sales Invoices', 'sinvoices', 'C', ['Unpaid', 'Partially Paid', 'Paid'], 'INV/26-27/', 214),
    'CP': t('Customer payment', 'Customer Payments', 'cpayments', 'C', ['Allocated'], 'RCPT-2026-', 99),
    'SR': t('Sales return', 'Sales Returns', 'sreturns', 'C', ['Requested', 'Received', 'Credited'], 'SR-2026-', 31),
    'CN': t('Credit note', 'Credit Notes', 'sreturns', 'C', ['Issued'], 'CN-2026-', 19),
    'PR': t('Purchase request', 'Purchase Requests', 'preqs', 'S', ['Draft', 'Pending Approval', 'Approved', 'RFQ Sent', 'Ordered'], 'PR-2026-', 233),
    'RFQ': t('Request for quotation', 'RFQs', 'rfqs', 'S', ['Awaiting Quotes', 'Quotes Received', 'Awarded'], 'RFQ-2026-', 45),
    'PO': t('Purchase order', 'Purchase Orders', 'porders', 'S', ['Pending Approval', 'Sent to Supplier', 'Partially Received', 'Received'], 'PO-2026-', 422),
    'GRN': t('Goods receipt', 'Goods Receipts', 'grns', 'S', ['QC Pending', 'QC Requested', 'QC Checked', 'Bin Allocated'], 'GRN-2026-', 298),
    'PA': t('Bin allocation', 'Bin Allocation', 'putaway', 'S', ['To Do', 'Completed'], 'PA-2026-', 156),
    'PI': t('Purchase invoice', 'Purchase Invoices', 'pinvoices', 'S', ['Received from Supplier', 'Pending Approval', 'Approved', 'Paid'], 'PI-2026-', 187),
    'SP': t('Supplier payment', 'Supplier Payments', 'spayments', 'S', ['Paid'], 'PAY-2026-', 77),
    'PRT': t('Purchase return', 'Purchase Returns', 'preturns', 'S', ['Submitted', 'Approved', 'Returned'], 'PRT-2026-', 12),
    'DBN': t('Debit note', 'Debit Notes', 'preturns', 'S', ['Issued'], 'DBN-2026-', 8),
    'TR': t('Stock transfer', 'Stock Transfers', 'transfers', 'W', ['Requested', 'In Transit', 'Received'], 'TR-2026-', 65),
    'ADJ': t('Stock adjustment', 'Adjustments', 'adjust', 'W', ['Pending Approval', 'Posted'], 'ADJ-2026-', 49),
    'CC': t('Cycle count', 'Cycle Counting', 'counting', 'W', ['Counting', 'Completed'], 'CC-2026-', 31),
    'SHP': t('Shipment', 'Shipments', 'shipments', 'C', ['Booked', 'Picked Up', 'In Transit', 'Out for Delivery', 'Delivered'], 'SHP-2026-', 271),
    'LD': t('Load', 'Trip Planning', 'loads', 'W', ['Planned', 'Loading', 'Dispatched'], 'LD-2026-', 91),
  });
}

Line _l(AppStore s, String item, int qty, [double? rate, int recv = 0]) => Line(item, qty, rate ?? s.item(item).price, recv: recv);
List<Line> _cp(List<Line> ls) => ls.map((l) => l.copy()).toList();

Doc _d(AppStore s, String type, String id, String date, String wh, String status, {String? party, String? to, String? ref, String? by, List<Line>? lines, List<String>? refs}) {
  final d = Doc(id: id, type: type, date: date, wh: wh, status: status, party: party, to: to, ref: ref, by: by, lines: lines);
  if (refs != null) d.refs.addAll(refs);
  return d;
}

void _seedDocs(AppStore s) {
  Doc mk(Doc d, {double? amount}) => s.mk(d, amount: amount);
  // Quotations
  mk(_d(s, 'QT', 'QT-2026-0141', '2026-09-28', 'W1', 'Draft', party: 'C006', by: Users.sales, lines: [_l(s, 'ITM-1011', 150, 160), _l(s, 'ITM-1014', 40, 590)])..valid = '2026-10-12');
  mk(_d(s, 'QT', 'QT-2026-0140', '2026-09-26', 'W3', 'Sent', party: 'C002', by: Users.sales, lines: [_l(s, 'ITM-1003', 80, 910), _l(s, 'ITM-1004', 2000, 57)])..valid = '2026-10-10');
  mk(_d(s, 'QT', 'QT-2026-0139', '2026-09-24', 'W1', 'Accepted', party: 'C001', by: Users.sales, lines: [_l(s, 'ITM-1001', 60, 396), _l(s, 'ITM-1009', 30, 748)])..valid = '2026-10-08');
  mk(_d(s, 'QT', 'QT-2026-0138', '2026-09-18', 'W2', 'Converted', party: 'C003', by: Users.sales, lines: [_l(s, 'ITM-1007', 40, 662)], refs: ['SO-2026-0316'])..valid = '2026-10-02');

  // Sales orders
  mk(_d(s, 'SO', 'SO-2026-0319', '2026-09-28', 'W3', 'Pending Approval', party: 'C002', by: Users.sales, lines: [_l(s, 'ITM-1008', 28, 16632), _l(s, 'ITM-1012', 10, 7216)])
    ..delivery = '2026-10-03'
    ..note = 'Above ₹5,00,000 approval limit');
  final so318 = mk(_d(s, 'SO', 'SO-2026-0318', '2026-09-27', 'W1', 'Picking', party: 'C001', by: Users.sales, lines: [_l(s, 'ITM-1011', 200, 138), _l(s, 'ITM-1013', 60, 229)], refs: ['PK-2026-0412'])..delivery = '2026-09-29');
  final so317 = mk(_d(s, 'SO', 'SO-2026-0317', '2026-09-26', 'W1', 'Packed', party: 'C004', by: Users.sales, lines: [_l(s, 'ITM-1004', 800, 60), _l(s, 'ITM-1003', 20, 966)], refs: ['PK-2026-0411', 'PCK-2026-0209', 'DN-2026-0288'])..delivery = '2026-09-29');
  final so316 = mk(_d(s, 'SO', 'SO-2026-0316', '2026-09-22', 'W2', 'Invoiced', party: 'C003', by: Users.sales, ref: 'QT-2026-0138', lines: [_l(s, 'ITM-1007', 40, 662)], refs: ['DN-2026-0287', 'INV/26-27/0214', 'SHP-2026-0271'])..delivery = '2026-09-30');
  final so315 = mk(_d(s, 'SO', 'SO-2026-0315', '2026-09-25', 'W3', 'Confirmed', party: 'C007', by: Users.sales, lines: [_l(s, 'ITM-1008', 6, 16900), _l(s, 'ITM-1005', 30, 1848)])..delivery = '2026-10-01');
  mk(_d(s, 'SO', 'SO-2026-0314', '2026-09-25', 'W3', 'On Hold', party: 'C005', by: Users.sales, lines: [_l(s, 'ITM-1006', 15, 3400), _l(s, 'ITM-1005', 10, 2100)])
    ..delivery = '2026-09-30'
    ..hold = 'Credit hold — INV/26-27/0186 overdue by 40 days');
  mk(_d(s, 'SO', 'SO-2026-0313', '2026-09-15', 'W1', 'Closed', party: 'C008', by: Users.sales, lines: [_l(s, 'ITM-1011', 120, 160), _l(s, 'ITM-1014', 25, 590)], refs: ['DN-2026-0285', 'INV/26-27/0212'])..delivery = '2026-09-18');
  mk(_d(s, 'SO', 'SO-2026-0312', '2026-09-12', 'W1', 'Delivered', party: 'C001', by: Users.sales, lines: [_l(s, 'ITM-1009', 40, 748), _l(s, 'ITM-1001', 50, 396)], refs: ['INV/26-27/0213', 'SHP-2026-0270'])..delivery = '2026-09-16');
  for (final so in [so318, so317, so315]) {
    s.reserveSO(so, true);
  }

  // Warehouse execution
  mk(_d(s, 'PK', 'PK-2026-0412', '2026-09-28', 'W1', 'To Pick', party: 'C001', ref: 'SO-2026-0318', lines: [
    Line('ITM-1011', 200, 138, bin: 'A-02', batch: 'B2607-WTR-03'),
    Line('ITM-1013', 60, 229, bin: 'A-04'),
  ])
    ..wave = 'WV-0918'
    ..picker = 'Ravi Teja');
  mk(_d(s, 'PK', 'PK-2026-0411', '2026-09-27', 'W1', 'Picked', party: 'C004', ref: 'SO-2026-0317', lines: [
    Line('ITM-1004', 800, 60, bin: 'B-01'),
    Line('ITM-1003', 20, 966, bin: 'A-03'),
  ])
    ..wave = 'WV-0917'
    ..picker = 'Suresh N');
  mk(_d(s, 'PCK', 'PCK-2026-0209', '2026-09-27', 'W1', 'Packed', party: 'C004', ref: 'SO-2026-0317', lines: _cp(so317.lines))
    ..cartons = 14
    ..weight = '486 kg');
  mk(_d(s, 'DN', 'DN-2026-0288', '2026-09-28', 'W1', 'Ready to Dispatch', party: 'C004', ref: 'SO-2026-0317', lines: _cp(so317.lines))
    ..cartons = 14
    ..weight = '486 kg');
  mk(_d(s, 'DN', 'DN-2026-0287', '2026-09-28', 'W2', 'Dispatched', party: 'C003', ref: 'SO-2026-0316', lines: _cp(so316.lines))
    ..carrier = 'Safexpress'
    ..vehicle = 'Carrier assigned vehicle'
    ..eway = 'EWB 3218 4471 0092');
  mk(_d(s, 'DN', 'DN-2026-0285', '2026-09-16', 'W1', 'Delivered', party: 'C008', ref: 'SO-2026-0313', lines: [_l(s, 'ITM-1011', 120, 160), _l(s, 'ITM-1014', 25, 590)])
    ..carrier = 'Own fleet'
    ..vehicle = s.vehicles[0]
    ..eway = '—');

  // Invoices & payments
  final i214 = mk(_d(s, 'INV', 'INV/26-27/0214', '2026-09-28', 'W2', 'Unpaid', party: 'C003', ref: 'SO-2026-0316', lines: _cp(so316.lines))
    ..irn = 'IRN 7c1e…a94f'
    ..eway = 'EWB 3218 4471 0092');
  i214.due = addDays(i214.date, 30);
  final i213 = mk(_d(s, 'INV', 'INV/26-27/0213', '2026-09-17', 'W1', 'Partially Paid', party: 'C001', ref: 'SO-2026-0312', lines: [_l(s, 'ITM-1009', 40, 748), _l(s, 'ITM-1001', 50, 396)])
    ..irn = 'IRN 51b0…22ce'
    ..eway = 'EWB 3211 0098 4410');
  i213.due = addDays(i213.date, 30);
  i213.paid = 25000;
  final i212 = mk(_d(s, 'INV', 'INV/26-27/0212', '2026-09-16', 'W1', 'Paid', party: 'C008', ref: 'SO-2026-0313', lines: [_l(s, 'ITM-1011', 120, 160), _l(s, 'ITM-1014', 25, 590)])
    ..irn = 'IRN 0a77…91d3'
    ..eway = '—');
  i212.due = addDays(i212.date, 15);
  i212.paid = i212.amount;
  final i186 = mk(_d(s, 'INV', 'INV/26-27/0186', '2026-07-20', 'W3', 'Unpaid', party: 'C005', ref: 'SO-2026-0271', lines: [_l(s, 'ITM-1006', 18, 3400)])
    ..irn = 'IRN 9f02…6b1a'
    ..eway = 'EWB 3196 7710 0231');
  i186.due = addDays(i186.date, 30);
  final i179 = mk(_d(s, 'INV', 'INV/26-27/0179', '2026-07-08', 'W3', 'Paid', party: 'C002', ref: 'SO-2026-0262', lines: [_l(s, 'ITM-1003', 120, 910), _l(s, 'ITM-1012', 8, 7216)])
    ..irn = 'IRN 3dd4…07aa'
    ..eway = 'EWB 3190 2201 7784');
  i179.due = addDays(i179.date, 45);
  i179.paid = i179.amount;
  mk(_d(s, 'CP', 'RCPT-2026-0098', '2026-09-24', 'W1', 'Allocated', party: 'C008', ref: 'INV/26-27/0212')
    ..mode = 'NEFT'
    ..utr = 'UTR N2672 1190', amount: i212.amount);
  mk(_d(s, 'CP', 'RCPT-2026-0099', '2026-09-26', 'W1', 'Allocated', party: 'C001', ref: 'INV/26-27/0213')
    ..mode = 'RTGS'
    ..utr = 'UTR R2692 4410', amount: 25000);
  mk(_d(s, 'CP', 'RCPT-2026-0097', '2026-08-20', 'W3', 'Allocated', party: 'C002', ref: 'INV/26-27/0179')
    ..mode = 'NEFT'
    ..utr = 'UTR N2232 0081', amount: i179.amount);
  mk(_d(s, 'SR', 'SR-2026-0031', '2026-09-27', 'W1', 'Requested', party: 'C001', ref: 'INV/26-27/0213', lines: [_l(s, 'ITM-1009', 4, 748)])..reason = 'Damaged in transit');
  mk(_d(s, 'SR', 'SR-2026-0030', '2026-09-10', 'W3', 'Credited', party: 'C002', ref: 'INV/26-27/0179', lines: [_l(s, 'ITM-1003', 5, 910)], refs: ['CN-2026-0019'])..reason = 'Wrong item shipped');
  mk(_d(s, 'CN', 'CN-2026-0019', '2026-09-12', 'W3', 'Issued', party: 'C002', ref: 'SR-2026-0030', lines: [_l(s, 'ITM-1003', 5, 910)]));

  // Shipments & loads
  mk(_d(s, 'SHP', 'SHP-2026-0271', '2026-09-28', 'W2', 'In Transit', party: 'C003', ref: 'DN-2026-0287', lines: _cp(so316.lines))
    ..carrier = 'Safexpress'
    ..awb = 'SFX 88120 44719'
    ..eta = '2026-09-30');
  mk(_d(s, 'SHP', 'SHP-2026-0270', '2026-09-17', 'W1', 'Out for Delivery', party: 'C001', ref: 'INV/26-27/0213', lines: [_l(s, 'ITM-1009', 40, 748), _l(s, 'ITM-1001', 50, 396)])
    ..carrier = 'Own fleet'
    ..awb = 'OWN-4521-0917'
    ..eta = '2026-09-28');
  mk(_d(s, 'SHP', 'SHP-2026-0269', '2026-09-16', 'W1', 'Delivered', party: 'C008', ref: 'DN-2026-0285', lines: [_l(s, 'ITM-1011', 120, 160), _l(s, 'ITM-1014', 25, 590)])
    ..carrier = 'Own fleet'
    ..awb = 'OWN-4521-0916'
    ..eta = '2026-09-17'
    ..pod = 'Signed by K. Mahesh');
  mk(_d(s, 'LD', 'LD-2026-0091', '2026-09-28', 'W1', 'Planned', lines: _cp(so317.lines))
    ..vehicle = s.vehicles[0]
    ..carrier = 'Own fleet'
    ..route = 'Vizag → Rajahmundry → Kakinada'
    ..dns = ['DN-2026-0288']
    ..util = 62);
  mk(_d(s, 'LD', 'LD-2026-0090', '2026-09-28', 'W2', 'Dispatched', lines: _cp(so316.lines))
    ..vehicle = 'Carrier assigned vehicle'
    ..carrier = 'Safexpress'
    ..route = 'Vijayawada → Chennai'
    ..dns = ['DN-2026-0287']
    ..util = 88);

  // Procurement
  mk(_d(s, 'PR', 'PR-2026-0233', '2026-09-28', 'W1', 'Pending Approval', party: 'S001', by: Users.sys, lines: [_l(s, 'ITM-1002', 150, 380)])
    ..source = 'Reorder check (auto)'
    ..need = '2026-10-03');
  mk(_d(s, 'PR', 'PR-2026-0232', '2026-09-27', 'W2', 'Approved', party: 'S002', by: Users.wh, lines: [_l(s, 'ITM-1003', 60, 780)])
    ..source = 'Manual — Kiran Kumar'
    ..need = '2026-10-05');
  mk(_d(s, 'PR', 'PR-2026-0231', '2026-09-24', 'W3', 'RFQ Sent', party: 'S004', by: Users.wh, lines: [_l(s, 'ITM-1005', 50, 1450)], refs: ['RFQ-2026-0045'])
    ..source = 'Manual — Farhana Begum'
    ..need = '2026-10-08');
  mk(_d(s, 'PR', 'PR-2026-0230', '2026-09-20', 'W1', 'Ordered', party: 'S002', by: Users.sys, lines: [_l(s, 'ITM-1003', 60, 760)], refs: ['PO-2026-0421'])
    ..source = 'Reorder check (auto)'
    ..need = '2026-09-30');
  mk(_d(s, 'RFQ', 'RFQ-2026-0045', '2026-09-24', 'W3', 'Quotes Received', party: 'S004', ref: 'PR-2026-0231', lines: [_l(s, 'ITM-1005', 50, 1450)])
    ..close = '2026-09-29'
    ..quotes = [Quote('S004', 1420, 7, '2026-10-15'), Quote('S005', 1495, 5, '2026-10-20'), Quote('S001', 1468, 6, '2026-10-12')]);
  mk(_d(s, 'PO', 'PO-2026-0422', '2026-09-28', 'W3', 'Pending Approval', party: 'S006', by: Users.buyer, lines: [_l(s, 'ITM-1008', 36, 14500)])
    ..delivery = '2026-10-08'
    ..note = 'Above ₹5,00,000 approval limit');
  mk(_d(s, 'PO', 'PO-2026-0421', '2026-09-21', 'W1', 'Sent to Supplier', party: 'S002', ref: 'PR-2026-0230', by: Users.buyer, lines: [_l(s, 'ITM-1003', 60, 760)])..delivery = '2026-09-30');
  mk(_d(s, 'PO', 'PO-2026-0420', '2026-09-19', 'W1', 'Partially Received', party: 'S001', by: Users.buyer, lines: [_l(s, 'ITM-1001', 200, 320, 120), _l(s, 'ITM-1002', 100, 365, 0)], refs: ['GRN-2026-0298'])..delivery = '2026-09-27');
  mk(_d(s, 'PO', 'PO-2026-0419', '2026-09-17', 'W1', 'Received', party: 'S003', by: Users.buyer, lines: [_l(s, 'ITM-1004', 1000, 42, 1000), _l(s, 'ITM-1013', 200, 180, 200)], refs: ['GRN-2026-0297', 'PI-2026-0187'])..delivery = '2026-09-25');
  mk(_d(s, 'PO', 'PO-2026-0418', '2026-09-15', 'W2', 'Received', party: 'S007', by: Users.buyer, lines: [_l(s, 'ITM-1009', 150, 610, 150)], refs: ['GRN-2026-0296', 'PI-2026-0186'])..delivery = '2026-09-24');
  mk(_d(s, 'PO', 'PO-2026-0417', '2026-09-08', 'W3', 'Received', party: 'S005', by: Users.buyer, lines: [_l(s, 'ITM-1006', 40, 2650, 40)], refs: ['GRN-2026-0293', 'PI-2026-0185'])..delivery = '2026-09-16');
  mk(_d(s, 'GRN', 'GRN-2026-0298', '2026-09-28', 'W1', 'QC Pending', party: 'S001', ref: 'PO-2026-0420', lines: [_l(s, 'ITM-1001', 120, 320)])..challan = 'SG/DC/8841');
  mk(_d(s, 'GRN', 'GRN-2026-0297', '2026-09-27', 'W1', 'QC Checked', party: 'S003', ref: 'PO-2026-0419', lines: [_l(s, 'ITM-1004', 1000, 42), _l(s, 'ITM-1013', 200, 180)], refs: ['PA-2026-0156'])..challan = 'AC/2209');
  mk(_d(s, 'GRN', 'GRN-2026-0296', '2026-09-26', 'W2', 'Bin Allocated', party: 'S007', ref: 'PO-2026-0418', lines: [_l(s, 'ITM-1009', 150, 610)])..challan = 'CC/5510');
  mk(_d(s, 'PA', 'PA-2026-0156', '2026-09-27', 'W1', 'To Do', party: 'S003', ref: 'GRN-2026-0297', lines: [
    Line('ITM-1004', 1000, 42, from: 'RCV-01', bin: 'B-02'),
    Line('ITM-1013', 200, 180, from: 'RCV-01', bin: 'A-04'),
  ]));
  mk(_d(s, 'PA', 'PA-2026-0155', '2026-09-26', 'W2', 'Completed', party: 'S007', ref: 'GRN-2026-0296', lines: [Line('ITM-1009', 150, 610, from: 'RCV-01', bin: 'A-01')]));
  mk(_d(s, 'PI', 'PI-2026-0187', '2026-09-28', 'W1', 'Pending Approval', party: 'S003', ref: 'PO-2026-0419', lines: [_l(s, 'ITM-1004', 1000, 44), _l(s, 'ITM-1013', 200, 180)])
    ..supInv = 'AC/INV/3391'
    ..match = MatchResult(false, 'Price difference on ITM-1004: invoiced ₹44 vs PO ₹42 (+4.8%) — exceeds the 2% price tolerance'));
  final pi186 = mk(_d(s, 'PI', 'PI-2026-0186', '2026-09-26', 'W2', 'Approved', party: 'S007', ref: 'PO-2026-0418', lines: [_l(s, 'ITM-1009', 150, 610)])
    ..supInv = 'CC/INV/7720'
    ..match = MatchResult(true, 'Invoice verified — matches the purchase order and goods receipt'));
  pi186.due = addDays(pi186.date, 30);
  final pi185 = mk(_d(s, 'PI', 'PI-2026-0185', '2026-09-17', 'W3', 'Paid', party: 'S005', ref: 'PO-2026-0417', lines: [_l(s, 'ITM-1006', 40, 2650)])
    ..supInv = 'TC/2026/1182'
    ..match = MatchResult(true, 'Invoice verified — matches the purchase order and goods receipt'));
  pi185.due = addDays(pi185.date, 30);
  pi185.paid = pi185.amount;
  mk(_d(s, 'SP', 'PAY-2026-0077', '2026-09-25', 'W3', 'Paid', party: 'S005', ref: 'PI-2026-0185')
    ..mode = 'NEFT'
    ..utr = 'UTR N2682 7719', amount: pi185.amount);
  mk(_d(s, 'PRT', 'PRT-2026-0012', '2026-09-27', 'W2', 'Approved', party: 'S007', ref: 'GRN-2026-0296', lines: [_l(s, 'ITM-1009', 6, 610)])..reason = 'Leaking cans found at bin allocation');
  mk(_d(s, 'DBN', 'DBN-2026-0008', '2026-09-05', 'W1', 'Issued', party: 'S002', ref: 'PRT-2026-0011', lines: [_l(s, 'ITM-1007', 10, 540)]));

  // Inventory
  mk(_d(s, 'TR', 'TR-2026-0064', '2026-09-27', 'W1', 'In Transit', to: 'W2', by: Users.wh, lines: [_l(s, 'ITM-1011', 200, 110)])..vehicle = s.vehicles[1]);
  s.stk('W1', 'ITM-1011').onhand -= 200;
  s.stk('W2', 'ITM-1011').transit += 200;
  mk(_d(s, 'TR', 'TR-2026-0065', '2026-09-28', 'W2', 'Requested', to: 'W3', by: Users.wh, lines: [_l(s, 'ITM-1014', 40, 420), _l(s, 'ITM-1009', 30, 610)]));
  mk(_d(s, 'ADJ', 'ADJ-2026-0049', '2026-09-28', 'W2', 'Pending Approval', by: Users.wh, lines: [_l(s, 'ITM-1009', -20, 610)])..reason = 'Damage');
  mk(_d(s, 'ADJ', 'ADJ-2026-0048', '2026-09-27', 'W2', 'Posted', by: Users.wh, lines: [_l(s, 'ITM-1014', -6, 420)])..reason = 'Damage');
  mk(_d(s, 'CC', 'CC-2026-0031', '2026-09-28', 'W1', 'Counting', lines: [
    Line('ITM-1001', 0, 320, bin: 'A-01'),
    Line('ITM-1005', 0, 1450, bin: 'A-03'),
    Line('ITM-1013', 0, 180, bin: 'A-04'),
  ])
    ..zone = 'A · Picking Area'
    ..counter = 'Suresh N');
  mk(_d(s, 'CC', 'CC-2026-0030', '2026-09-21', 'W2', 'Completed', lines: [
    Line('ITM-1007', 0, 540, bin: 'B-01', sys: 150, cnt: 150),
    Line('ITM-1014', 0, 420, bin: 'B-02', sys: 166, cnt: 160),
  ])
    ..zone = 'B · Bulk storage'
    ..counter = 'Ravi Teja');

  // Ledger history
  final hist = [
    ['2026-09-26', 'W1', 'ITM-1011', -120, 'Sales issue', 'DN-2026-0285'],
    ['2026-09-26', 'W2', 'ITM-1009', 150, 'Purchase receipt', 'GRN-2026-0296'],
    ['2026-09-27', 'W1', 'ITM-1004', 1000, 'Purchase receipt', 'GRN-2026-0297'],
    ['2026-09-27', 'W3', 'ITM-1006', -12, 'Sales issue', 'DN-2026-0286'],
    ['2026-09-27', 'W1', 'ITM-1011', -200, 'Transfer out', 'TR-2026-0064'],
    ['2026-09-27', 'W2', 'ITM-1014', -6, 'Adjustment (damage)', 'ADJ-2026-0048'],
    ['2026-09-28', 'W2', 'ITM-1007', -40, 'Sales issue', 'DN-2026-0287'],
  ];
  for (final x in hist) {
    final q = x[3] as int, w = x[1] as String, it = x[2] as String;
    s.ledger.add(LedgerEntry(x[0] as String, '—', w, it, x[4] as String, q, s.stk(w, it).onhand, x[5] as String, q > 0 ? Users.wh : Users.sys, q.abs() * s.item(it).cost));
  }

  s.batches.addAll([
    Batch('B2604-SAN-01', 'ITM-1009', 'W2', 180, '2026-04-10', '2027-04-09', 'S007', 'Released'),
    Batch('B2607-WTR-03', 'ITM-1011', 'W1', 950, '2026-07-02', '2027-01-01', 'S008', 'Released'),
    Batch('B2604-BAT-02', 'ITM-1011', 'W1', 200, '2026-04-18', '2026-10-17', 'S008', 'Expiring Soon'),
    Batch('B2605-LUB-07', 'ITM-1010', 'W1', 64, '2026-05-11', '2028-05-10', 'S005', 'Released'),
    Batch('B2608-GLV-11', 'ITM-1002', 'W1', 140, '2026-08-01', '2029-07-31', 'S001', 'Released'),
    Batch('B2603-DTG-04', 'ITM-1014', 'W2', 24, '2026-03-05', '2026-11-04', 'S007', 'Expiring Soon'),
    Batch('B2609-CBL-02', 'ITM-1006', 'W3', 88, '2026-09-02', '—', 'S005', 'Released'),
    Batch('B2606-SAN-02', 'ITM-1009', 'W2', 20, '2026-06-14', '2027-06-13', 'S007', 'Quarantine'),
  ]);
  s.serials.addAll([
    Serial('HPT25-26-00412', 'ITM-1008', 'W1', 'In stock', 'GRN-2026-0281'),
    Serial('HPT25-26-00413', 'ITM-1008', 'W1', 'In stock', 'GRN-2026-0281'),
    Serial('HPT25-26-00398', 'ITM-1008', 'W3', 'Reserved', 'SO-2026-0315'),
    Serial('LED100-9921', 'ITM-1005', 'W3', 'Reserved', 'SO-2026-0315'),
    Serial('LED100-9870', 'ITM-1005', 'W1', 'Sold', 'INV/26-27/0201'),
  ]);
}

void _seedExtras(AppStore s) {
  s.territories.addAll([
    Territory('TER-01', 'AP Coastal', 'Andhra Pradesh (north coast)', 'Visakhapatnam, Kakinada, Rajahmundry', 'Priya Sharma', 'W1'),
    Territory('TER-02', 'AP South', 'Andhra Pradesh (south)', 'Vijayawada, Nellore, Tirupati', 'Rahul Varma', 'W2'),
    Territory('TER-03', 'Telangana', 'Telangana', 'Hyderabad, Warangal', 'Ayesha Khan', 'W3'),
    Territory('TER-04', 'TN & Karnataka', 'Tamil Nadu, Karnataka', 'Chennai, Bengaluru', 'Karthik Iyer', 'W2'),
  ]);
  s.terrOf.addAll({'C001': 'TER-01', 'C004': 'TER-01', 'C006': 'TER-01', 'C008': 'TER-02', 'C002': 'TER-03', 'C005': 'TER-03', 'C003': 'TER-04', 'C007': 'TER-04'});
  s.salesPersons.addAll([
    SalesPerson('SP-01', 'Priya Sharma', 'TER-01', '+91 98490 11220', 2500000, 'Active'),
    SalesPerson('SP-02', 'Rahul Varma', 'TER-02', '+91 98491 33412', 1500000, 'Active'),
    SalesPerson('SP-03', 'Ayesha Khan', 'TER-03', '+91 99080 77451', 3000000, 'Active'),
    SalesPerson('SP-04', 'Karthik Iyer', 'TER-04', '+91 94443 20981', 2000000, 'Active'),
  ]);
  s.contacts.addAll([
    Contact('Ramesh Babu', 'C001', 'Purchase Head', '+91 98480 22110', 'ramesh@srilakshmi.in', 'Yes'),
    Contact('Sunitha Rao', 'C001', 'Accounts', '+91 98480 22111', 'accounts@srilakshmi.in', 'No'),
    Contact('Sanjay Reddy', 'C002', 'Category Manager', '+91 99496 71120', 'sanjay@metromart.in', 'Yes'),
    Contact('M. Venkatesh', 'C003', 'Proprietor', '+91 94440 38821', 'kaveri.dist@gmail.com', 'Yes'),
    Contact('P. Satyanarayana', 'C004', 'Partner', '+91 98851 44390', 'godavaritraders@gmail.com', 'Yes'),
    Contact('Imran Khan', 'C005', 'Owner', '+91 90000 51287', 'imran@deccanhw.in', 'Yes'),
    Contact('Lavanya K', 'C006', 'Store Manager', '+91 97012 66030', 'lavanya@coastalfresh.in', 'Yes'),
    Contact('Arjun Shetty', 'C007', 'Procurement Lead', '+91 98450 12093', 'arjun@blrretailhub.com', 'Yes'),
    Contact('Meghana S', 'C007', 'Warehouse In-charge', '+91 98450 12094', 'wh@blrretailhub.com', 'No'),
    Contact('K. Mahesh', 'C008', 'Proprietor', '+91 94405 70021', 'nelloreagencies@gmail.com', 'Yes'),
  ]);
  s.leads.addAll([
    Lead('LEAD-0108', 'Srikakulam Hardware Mart', 'B. Naidu', 'Srikakulam', 'Andhra Pradesh', 'Trade show', 'Priya Sharma', 180000, '2026-09-27', 'New', 'ITM-1001'),
    Lead('LEAD-0107', 'Warangal Industrial Supplies', 'R. Goud', 'Warangal', 'Telangana', 'Website enquiry', 'Ayesha Khan', 420000, '2026-09-25', 'Contacted', 'ITM-1008'),
    Lead('LEAD-0106', 'Ongole Agro Traders', 'S. Prasad', 'Ongole', 'Andhra Pradesh', 'Referral', 'Rahul Varma', 95000, '2026-09-22', 'Qualified', 'ITM-1011'),
    Lead('LEAD-0105', 'Mysuru Mega Stores', 'H. Gowda', 'Mysuru', 'Karnataka', 'Cold call', 'Karthik Iyer', 260000, '2026-09-18', 'Contacted', 'ITM-1003'),
    Lead('LEAD-0104', 'Guntur Cold Chain', 'V. Chowdary', 'Guntur', 'Andhra Pradesh', 'Website enquiry', 'Rahul Varma', 150000, '2026-09-12', 'Lost', 'ITM-1009'),
  ]);
  s.opps.addAll([
    Opportunity('OPP-0053', 'C007', 'Warehouse racking upgrade', 'Karthik Iyer', 410000, 60, '2026-10-20', 'Proposal', [OppLine('ITM-1012', 40), OppLine('ITM-1008', 4)]),
    Opportunity('OPP-0052', 'C001', 'Festive season water & PPE', 'Priya Sharma', 220000, 40, '2026-10-10', 'Prospecting', [OppLine('ITM-1011', 800), OppLine('ITM-1001', 100)]),
    Opportunity('OPP-0051', 'C002', 'Packaging annual contract', 'Ayesha Khan', 1250000, 75, '2026-10-31', 'Negotiation', [OppLine('ITM-1003', 600), OppLine('ITM-1004', 9000)]),
    Opportunity('OPP-0050', 'C003', 'Plumbing stock refill', 'Karthik Iyer', 28000, 100, '2026-09-18', 'Won', [OppLine('ITM-1007', 40)], quote: 'QT-2026-0138'),
    Opportunity('OPP-0049', 'C005', 'Electrical fit-out', 'Ayesha Khan', 190000, 0, '2026-09-10', 'Lost', [OppLine('ITM-1006', 40)]),
  ]);
  s.customerGroups.addAll([
    CustomerGroup('CG-KEY', 'Key Account', 'PL-KEY', 45, 1000000, 'Large chains with annual agreements'),
    CustomerGroup('CG-WHL', 'Wholesale', 'PL-WHL', 30, 500000, 'Distributors and traders buying in bulk'),
    CustomerGroup('CG-RTL', 'Retail', 'PL-STD', 15, 200000, 'Single stores and small businesses'),
  ]);
  s.supplierGroups.addAll([
    SupplierGroup('SG-PPE', 'Safety & PPE', 30, ['S001'], 'Helmets, gloves, protective wear'),
    SupplierGroup('SG-PKG', 'Packaging', 30, ['S002', 'S003'], 'Films, cartons, labels'),
    SupplierGroup('SG-ELE', 'Electricals', 45, ['S004', 'S005'], 'Lighting, cables, lubricants'),
    SupplierGroup('SG-EQP', 'Equipment', 45, ['S006'], 'Material handling and racking'),
    SupplierGroup('SG-CON', 'Consumables', 15, ['S007', 'S008'], 'Cleaning, chemicals, water'),
  ]);
  s.uoms.addAll([
    Uom('Nos', 'Numbers', 'Count', 'Nos', 1), Uom('Box', 'Box of 100', 'Pack', 'Nos', 100), Uom('Roll', 'Roll', 'Count', 'Roll', 1),
    Uom('Coil', 'Coil (90 m)', 'Length', 'm', 90), Uom('Can', 'Can (5 L)', 'Volume', 'L', 5), Uom('Drum', 'Drum (20 L)', 'Volume', 'L', 20),
    Uom('Case', 'Case of 12', 'Pack', 'Nos', 12), Uom('Set', 'Set', 'Count', 'Set', 1), Uom('Bag', 'Bag (5 kg)', 'Weight', 'kg', 5),
  ]);
  s.trackGroups.addAll([
    TrackGroup('TDG-NONE', 'None', 'No', 'No', 'No', 'Quantity only'),
    TrackGroup('TDG-BATCH', 'Batch', 'Yes', 'No', 'Yes', 'Batch number with manufacturing and expiry dates · earliest expiry picked first'),
    TrackGroup('TDG-SERIAL', 'Serial', 'No', 'Yes', 'No', 'One serial per unit, captured at receipt and dispatch'),
  ]);
  s.storageGroups.addAll([
    StorageGroup('SDG-WH', 'Site · Warehouse', 'Yes', 'Yes', 'No', 'Stock tracked per warehouse only'),
    StorageGroup('SDG-WMS', 'Site · Warehouse · Location', 'Yes', 'Yes', 'Yes', 'Stock tracked per bin — needed for bin allocation, batch picking and stock counts'),
  ]);
  s.sites.addAll([
    Site('SITE-AP', 'Andhra Pradesh', '37AAHCI4521K1Z6', ['W1', 'W2'], 'Visakhapatnam, Andhra Pradesh'),
    Site('SITE-TS', 'Telangana', '36AAHCI4521K1Z8', ['W3'], 'Hyderabad, Telangana'),
  ]);
  s.moves.addAll([
    BinMove('MV-2026-0024', '2026-09-28', 'W1', 'ITM-1011', 'B-02', 'A-02', 300, 'Refill picking area', 'Open', 'System (min/max)'),
    BinMove('MV-2026-0023', '2026-09-28', 'W2', 'ITM-1009', 'A-01', 'QRN-01', 20, 'Move damaged to quarantine', 'Open', 'Kiran Kumar'),
    BinMove('MV-2026-0022', '2026-09-27', 'W3', 'ITM-1008', 'RCV-01', 'B-03', 6, 'Consolidation', 'Done', 'Farhana Begum'),
    BinMove('MV-2026-0021', '2026-09-26', 'W1', 'ITM-1004', 'B-01', 'A-03', 500, 'Refill picking area', 'Done', 'System (min/max)'),
  ]);
  s.fleet.addAll([
    Vehicle('VH-01', s.vehicles[0], 'Truck 9 T', 'W1', 'Appa Rao', '9,000 kg', 'LT-9T'),
    Vehicle('VH-02', s.vehicles[1], 'Truck 6 T', 'W1', 'Suresh Babu', '6,000 kg', 'LT-6T'),
    Vehicle('VH-03', s.vehicles[2], 'Truck 9 T', 'W3', 'Mohd. Saleem', '9,000 kg', 'LT-9T'),
    Vehicle('VH-04', 'AP 39 TC 1180 (Own · 3 T)', 'Pickup 3 T', 'W2', 'Venkat', '3,000 kg', 'LT-3T'),
  ]);
  s.loadTemplates.addAll([
    LoadTemplate('LT-3T', 'Pickup 3 T', '3,000 kg', '12 m³', 4, 'City deliveries'),
    LoadTemplate('LT-6T', 'Truck 6 T (17 ft)', '6,000 kg', '28 m³', 8, 'Intra-state routes'),
    LoadTemplate('LT-9T', 'Truck 9 T (20 ft)', '9,000 kg', '38 m³', 12, 'Multi-drop regional'),
    LoadTemplate('LT-FTL', 'Carrier FTL 32 ft', '16,000 kg', '65 m³', 22, 'Inter-state full truck'),
  ]);
}

/// The lists on Company Settings: branches (one per warehouse city), currencies, payment terms, tax codes and T&C templates.
void _seedSetupLists(AppStore s) {
  for (final w in s.warehouses) {
    final name = w.branch.isEmpty ? '${w.city} Branch' : w.branch;
    if (s.branches.every((b) => b.name != name)) {
      s.branches.add(Branch(name, city: w.city, state: w.state, manager: w.manager));
    }
  }
  s.currencies.addAll([
    Currency('INR', 'Indian Rupee', '₹', 1),
    Currency('USD', 'US Dollar', '\$', 83.5),
    Currency('EUR', 'Euro', '€', 90.2),
  ]);
  s.payTerms.addAll([
    PayTerm('Net 15 days', 15),
    PayTerm('Net 30 days', 30),
    PayTerm('Net 45 days', 45),
    PayTerm('Net 60 days', 60),
    PayTerm('Advance', 0, advance: 100),
    PayTerm('Immediate', 0),
  ]);
  s.taxCodes.addAll([
    TaxCode('GST 18%', 18),
    TaxCode('GST 12%', 12),
    TaxCode('GST 5%', 5),
    TaxCode('GST 28%', 28),
    TaxCode('Exempt', 0, type: 'Exempt'),
  ]);
  s.tcTemplates.addAll([
    TcTemplate('Standard sales terms', 'Sales',
        '1. Prices are ex-warehouse unless stated otherwise.\n'
        '2. Payment as per agreed terms; interest at 18% p.a. on overdue amounts.\n'
        '3. Transit damage must be reported within 48 hours of delivery.\n'
        '4. Subject to Visakhapatnam jurisdiction.'),
    TcTemplate('Advance payment terms', 'Sales',
        '1. 50% advance with the order, balance before dispatch.\n'
        '2. Delivery period starts from receipt of the advance.\n'
        '3. Subject to Visakhapatnam jurisdiction.'),
    TcTemplate('Standard purchase terms', 'Purchase',
        '1. Goods must match the PO description, quantity and rate.\n'
        '2. Delivery on or before the expected delivery date to the warehouse named on the PO.\n'
        '3. Goods are accepted only after quality check; rejected goods are returned at the supplier\'s cost.\n'
        '4. Payment as per agreed terms from the date of goods receipt.\n'
        '5. Subject to Visakhapatnam jurisdiction.'),
  ]);
}
