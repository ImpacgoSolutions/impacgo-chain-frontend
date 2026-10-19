# IMPACGO Chain — Flow from Buy to Sell (screen by screen)

Written from the current code. Check each step and mark what you want changed.
"Auto" = the system does it. "You" = a person clicks or fills a form.

---------------------------------------------------------------
## PART 1 — BUY
---------------------------------------------------------------

### 1. Purchase Requests  (sidebar: Buy → Purchase Requests)
What it is: an internal request to buy items.
You: click **New request**, choose item, quantity, warehouse, reason. Save as Draft, then **Submit for approval**.
Auto: the daily reorder check also raises requests for items below reorder level.
Status: Draft → Pending Approval → Approved (or Rejected, with a reason) → Ordered.
Next step: **Convert to purchase order**, or ask suppliers for prices (RFQ).

### 2. Ask Suppliers (RFQ)  (Buy → Ask Suppliers)
What it is: a price request sent to several suppliers.
You: click **New RFQ**, pick the approved request (or none), quote due date, delivery place, tick the suppliers, send.
Status: Awaiting Quotes → Quotes Received → Awarded.

### 3. Supplier Quotes  (Buy → Supplier Quotes)
What it is: the prices the suppliers sent back, side by side.
You: enter each supplier's rate, lead days and validity.
Auto: the lowest price is marked "Best price".
You: click **Award best quote** → a purchase order is created.

### 4. Purchase Orders  (Buy → Purchase Orders)
What it is: the official order to the supplier.
Auto: price comes from the purchase trade agreement. Approval is needed only above the PO limit.
You: **Approve & send** (or Reject). Draft / pending orders can be edited.
Status: Draft → Pending Approval → Sent to Supplier → Partially Received → Received → Closed.
Next step: when goods arrive, click **Goods received**.

### 5. Goods Receipts / GRN  (Buy → Goods Receipts)
What it is: the record of goods that reached the dock.
You: **New goods receipt** against a PO. Count the goods, enter quantities, batch if needed.
Status: QC Pending → QC Requested → QC Checked.
You: tick receipts and **Raise QC**. The QC team records accepted and rejected quantity.
Auto: accepted quantity is added to stock (in the receiving area RCV-01). Rejected items can be sent back (Purchase Return).

### 6. Put in Bins  (Buy → Put in Bins)
What it is: a task to move accepted goods from the receiving area to a shelf.
Auto: created after the quality check, with a suggested bin.
You: **Allocate bins** and confirm.
Status: To Do → Completed.

### 7. Supplier Bills  (Buy → Supplier Bills)
What it is: the invoice the supplier sends us.
Auto: the system matches bill ↔ PO ↔ goods received (three-way match).
You: **Verify & Post Invoice**. If price differs, a manager must **Approve difference**.
Status: Received from Supplier → Pending Approval (if difference) → Approved → Paid.
You: **Pay** → a supplier payment (NEFT) is recorded and the bill becomes Paid.

### 8. Purchase Returns  (Buy → Purchase Returns)
What it is: sending rejected or wrong goods back to the supplier.
You: create from the goods receipt (**Return to supplier**).
Status: Submitted → Approved → Dispatched / Returned.

---------------------------------------------------------------
## PART 2 — STOCK (in the middle)
---------------------------------------------------------------

Screens: Stock Overview, Batches & Serial Numbers, Stock Transfers, Stock Adjustments, Physical Stock Count.
- Stock Overview: what is in each warehouse (on hand, reserved, available).
- Batches & Serial Numbers: expiry dates and serial tracking.
- Stock Transfers: move stock between warehouses (Requested → In Transit → Received).
- Stock Adjustments: fix stock with a reason (needs approval).
- Physical Stock Count: count bins; differences become adjustments.

---------------------------------------------------------------
## PART 3 — SELL
---------------------------------------------------------------

### 1. Leads  (Sell → Leads)
What it is: a possible buyer who has not bought yet.
You: **New lead** (company, contact, source, sales person). Mark contacted, or **Mark lost** (reason).
Status: New → Contacted → Qualified / Lost.
Next step: **Qualify & convert** → the system creates the customer and an opportunity.

### 2. Opportunities  (Sell → Opportunities)
What it is: the deal with that customer.
Stages: Prospecting → Proposal → Negotiation → Won / Lost.
You: edit, **Mark lost** (reason), or **Create quotation**.

### 3. Quotations  (Sell → Quotations)
What it is: the price offer sent to the customer.
Auto: price from trade agreement → price list → item price.
You: **Send to customer**, then **Mark accepted** or **Mark lost** (reason).
Status: Draft → Sent → Accepted.
Next step: **Convert to sales order**.

### 4. Sales Orders  (Sell → Sales Orders)
What it is: the customer's confirmed order.
Auto: credit check. If the customer has overdue invoices → On Hold. If value is above the limit → Pending Approval. Stock is reserved when confirmed.
You: **Approve** / **Reject** (reason) / **Release credit hold**.
Status: Pending Approval / On Hold → Confirmed → Picking → Packed → Invoiced → Delivered → Closed.
Next step: **Release to warehouse** → a pick list is created.

### 5. Deliveries  (Sell → Deliveries — one screen with 3 steps)
- **Pick**: pick list (To Pick → Picked). You: **Confirm picked**.
- **Pack**: packing task (Packing → Packed). You: **Confirm packed** (cartons, weight). Auto: delivery note is made.
- **Dispatch**: delivery note (Ready to Dispatch → Dispatched → Delivered).
  You: **Dispatch** (carrier, vehicle). Auto: stock goes out, invoice is raised, e-way bill and shipment are created.
  You: **Update delivery status** with proof of delivery.

### 6. Sales Invoices  (Sell → Sales Invoices)
What it is: the GST invoice to the customer. Made automatically at dispatch — nobody creates it by hand.
Status: Unpaid → Partially Paid → Paid.
You: download, **Record payment**, or **Create return**.

### 7. Customer Payments  (Sell → Customer Payments)
What it is: money received from customers.
You: **New receipt** (pick invoice, amount, mode, bank reference) or **Import bank statement** (system suggests matches, you post them).
Auto: when the invoice is fully paid, the invoice and the order close.

### 8. Sales Returns  (Sell → Sales Returns)
What it is: goods coming back from a customer.
You: create against a delivered delivery. Status: Requested → Received → Credited.
You: **Receive returned goods** (stock goes back), then **Issue credit note**.
Tabs: Returns, Credit notes.

---------------------------------------------------------------
## REPORTS (read-only)
---------------------------------------------------------------
Sales: Sales Order Register, Pending Deliveries.
Purchase: Purchase Order Register, Pending Purchase Orders, Goods Receipt Register.
Inventory: Stock Summary, Stock Ledger, Reorder Level Report.

---------------------------------------------------------------
## WHICH SCREENS LOOK LIKE WHAT
---------------------------------------------------------------
Form-style page (labels + boxes, like the Lead page):
  Purchase Requests, RFQs, Supplier Quotes, Purchase Orders, Goods Receipts, Put in Bins, Purchase Returns,
  Leads, Opportunities, Quotations, Sales Orders, Pick lists, Packing, Deliveries, Sales Returns.
Invoice / receipt layout (kept on purpose): Supplier Bills, Sales Invoices, Customer Payments (receipts), Credit notes.
Report layout: everything under Reports.

---------------------------------------------------------------
## THINGS TO DECIDE (tell me what you want)
---------------------------------------------------------------
1. Stock is added at the quality check (into RCV-01). "Put in bins" only moves it to a shelf. Do you want stock added only after bins?
2. Buy has no separate "Supplier Payments" screen — payment is a button on the Supplier Bill. Add a screen?
3. Quotation → Sales Order and Request → PO are buttons, not automatic. Keep?
4. Any screen that should be added, removed or renamed?
