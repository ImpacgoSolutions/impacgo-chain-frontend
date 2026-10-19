# IMPACGO Chain — demo logins

For testing only. The accounts are defined in `lib/core/auth.dart` (`demoUsers`).
On the login screen you can also tap a demo account to fill the email and password.

| Role | Email | Password | Can do |
|---|---|---|---|
| SCM Manager (Admin) | admin@impacgo.com | Admin@123 | Every screen · all approvals and rejections · Setup |
| Purchase & Sales Executive | executive@impacgo.com | Exec@123 | Purchase requests, RFQs, supplier quotations, purchase orders, purchase returns · leads, opportunities, quotations, sales orders, sales returns · customers, suppliers · sales & purchase reports |
| Store Keeper (Warehouse & QC) | store@impacgo.com | Store@123 | Raise purchase requests · receive goods (GRN) and QC · bin allocation · picking, packing · stock transfers, adjustments (manager approves big ones), stock count · warehouses & bins · inventory reports |
| Delivery Staff | delivery@impacgo.com | Delivery@123 | Vehicles & drivers · dispatch · delivery tracking · sales returns pickup · pending deliveries report |

Approve / Reject buttons (purchase requests, purchase orders, sales orders, stock adjustments, credit holds) are shown only to the SCM Manager.
