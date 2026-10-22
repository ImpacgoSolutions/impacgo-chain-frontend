# IMPACGO Chain — demo logins

For testing only. The website opens on the sign-in page: enter one of the emails and passwords below ("Forgot password?" sends a reset link once the backend is connected).
The accounts are defined in `lib/core/auth.dart` (`demoUsers`). The Admin can add more in **Setup › Users & Roles**
(name, email, mobile, password, role, warehouse / supplier, and the screens the person may open — their sidebar shows exactly those).
Without a backend, accounts added there last until the page is reloaded; the person signed in stays signed in after a reload.

| Role | Email | Password | Can do |
|---|---|---|---|
| SCM Manager (Admin) | admin@impacgo.com | Admin@123 | Every screen · all approvals and rejections · Setup |
| Purchase & Sales Executive | executive@impacgo.com | Exec@123 | Purchase requests, RFQs, supplier quotations, purchase orders, purchase returns · leads, opportunities, quotations, sales orders, sales returns · customers, suppliers · sales & purchase reports |
| Warehouse Executive (Stores & QC) | store@impacgo.com | Store@123 | Raise purchase requests · receive goods (GRN) and QC · bin allocation · picking, packing · stock transfers, adjustments (manager approves big ones), stock count · warehouses & bins · inventory reports |
| Delivery Staff | delivery@impacgo.com | Delivery@123 | Vehicles & drivers · dispatch · delivery tracking · sales returns pickup · pending deliveries report |
| Supplier (Andhra Corrugators) | supplier@andhracorrugators.com | Supplier@123 | Supplier Portal only: RFQs & Quotations (send / update a quotation, or decline) · Purchase Orders (accept with a delivery date, or reject with a reason) · Invoices (send the invoice, follow it until paid) |

Approve / Reject buttons are shown only to the SCM Manager. What needs approval:

- Purchase requests: always
- Purchase orders: always, unless made from an approved purchase request (also above the PO limit)
- Quotations: when priced more than the discount limit (10 % by default) below the price list
- Sales orders: above the SO limit, or a credit problem
- Sales returns: always (then the goods are inspected; only good goods go back into stock and are credited)
- Purchase returns: always
- Stock transfers: always, before the stock leaves
- Stock adjustments and count differences: above the adjustment limit
- Supplier invoices: when they do not match the order and goods receipt

The limits are set in Setup › Company Settings.

**Profile:** click your name (top right) to see your details, **Edit profile** (name, email, mobile, password) and **Sign out**.
Users & Roles and Company Settings can only ever be opened by the SCM Manager (Admin).
