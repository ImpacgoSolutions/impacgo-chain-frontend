// Sign-in, accounts and role-based access.
// Each account has a role (what it may do) and the screens it may open (chosen when the account is created;
// the role's standard screens by default). Only the people responsible for a step get its buttons —
// approvals and rejections belong to the SCM Manager only.
import '../app_state.dart';
import 'store.dart';

class AppUser {
  String email, password, name, role, title;
  /// Supplier logins: the supplier they belong to (they see only its orders and invoices).
  String? party;
  String phone;
  /// The warehouse the person works in ('' = every warehouse).
  String wh;
  bool active;
  /// The sidebar screens this person may open; null = the role's standard screens.
  Set<String>? screens;
  AppUser(this.email, this.password, this.name, this.role, this.title, {this.party, this.phone = '', this.wh = '', this.active = true, this.screens});
}

/// The roles an account can have, with their names as shown on the website.
const roleNames = <String, String>{
  'admin': 'SCM Manager (Admin)',
  'exec': 'Purchase & Sales Executive',
  'store': 'Warehouse Executive',
  'delivery': 'Delivery Staff',
  'supplier': 'Supplier',
};

/// What a role does, in one line (shown when choosing the role for an account).
const roleHints = <String, String>{
  'admin': 'Every screen · all approvals and rejections · money steps · Setup',
  'exec': 'Buying and selling: requests, RFQs, orders, quotations, returns',
  'store': 'Warehouse: goods receipt, QC, bins, picking, packing, stock',
  'delivery': 'Dispatch, delivery tracking, return pickups',
  'supplier': 'Supplier Portal only: quotations, orders, invoices',
};

/// The title shown under a person's name, e.g. "Warehouse Executive · Stores & QC".
String roleTitle(String role, {String supplierName = ''}) => switch (role) {
      'admin' => 'SCM Manager · All modules',
      'store' => 'Warehouse Executive · Stores & QC',
      'supplier' => 'Supplier · $supplierName',
      _ => roleNames[role] ?? role,
    };

/// The demo accounts the website starts with (until the backend holds the real accounts).
final demoUsers = <AppUser>[
  AppUser('admin@impacgo.com', 'Admin@123', 'Srinivas Rao', 'admin', 'SCM Manager · All modules', phone: '+91 98480 10102'),
  AppUser('executive@impacgo.com', 'Exec@123', 'Priya Sharma', 'exec', 'Purchase & Sales Executive', phone: '+91 98480 10215', wh: 'W1'),
  AppUser('store@impacgo.com', 'Store@123', 'Kiran Kumar', 'store', 'Warehouse Executive · Stores & QC', phone: '+91 98480 10331', wh: 'W1'),
  AppUser('delivery@impacgo.com', 'Delivery@123', 'Suresh Naidu', 'delivery', 'Delivery Staff', phone: '+91 98480 10447', wh: 'W1'),
  // a supplier's login: sees only the Supplier Portal, with its own requests for quotation, orders and invoices
  AppUser('supplier@andhracorrugators.com', 'Supplier@123', 'N. Prasad', 'supplier', 'Supplier · Andhra Corrugators', party: 'S001', phone: '+91 98490 22110'),
];

/// Our own active staff (not supplier logins), e.g. for "Requested By".
List<AppUser> get staffUsers => S.users.where((u) => u.role != 'supplier' && u.active).toList();

/// The role of a person, e.g. "Warehouse Executive" ('' when the name is not a user).
String roleOfName(String name) {
  final u = S.users.where((u) => u.name == name).firstOrNull;
  return u == null ? '' : u.title.split(' · ').first;
}

/// Screens only the SCM Manager (Admin) opens: they can never be given to another account.
const adminOnlyScreens = {'h_users', 'h_company'};

/// The sidebar screens that can be given to an account (filled in from the sidebar when the app starts).
Set<String> grantableScreens = {};

/// A role's standard sidebar screens (what a new account with that role starts with).
Set<String> roleScreens(String role) => {for (final s in _screens[role] ?? const <String>{}) if (grantableScreens.isEmpty || grantableScreens.contains(s)) s};

/// Screens each role can open (the manager can open everything).
const _screens = <String, Set<String>>{
  'exec': {
    'workspace', 'h_items', 'items', 'h_customers', 'customers', 'contacts', 'suppliers',
    'preqs', 'rfqs', 'squotes', 'porders', 'grns', 'qc', 'preturns',
    'leads', 'opps', 'quotes', 'sorders', 'fulfil', 'dtracking', 'sinvoices', 'sreturns',
    'onhand',
    'rep_so', 'rep_ar_ageing', 'rep_ap_ageing', 'rep_sales_customer', 'rep_sales_item', 'rep_pending_delivery',
    'rep_po', 'rep_pending_po', 'rep_grn', 'rep_sup_perf', 'rep_low_stock',
  },
  'store': {
    'workspace', 'h_warehouses', 'warehouses', 'bins', 'h_items', 'items',
    'preqs', 'grns', 'qc', 'putaway', 'preturns',
    'fulfil', 'picking', 'packing', 'sreturns',
    'onhand', 'ledger', 'batches', 'transfers', 'adjust', 'counting',
    'rep_grn', 'rep_stock_overview', 'rep_stock_movement', 'rep_low_stock', 'rep_batch',
  },
  // suppliers see only their portal: requests for quotation, purchase orders received and invoices sent
  'supplier': {'sp_rfq', 'sp_po', 'sp_inv'},
  'delivery': {
    'workspace', 'h_team', 'vehicles', 'drivers',
    'fulfil', 'packing', 'deliveries', 'dtracking', 'sreturns',
    'rep_pending_delivery',
  },
};

/// Who may create each document type (besides the manager).
const _create = <String, Set<String>>{
  'PR': {'exec', 'store'}, 'RFQ': {'exec'}, 'PO': {'exec'}, 'GRN': {'store'}, 'PRT': {'store', 'exec'},
  'QT': {'exec'}, 'SO': {'exec'}, 'SR': {'exec', 'store', 'delivery'},
  'TR': {'store'}, 'ADJ': {'store'}, 'CC': {'store'},
};

/// Who works each document's next step (besides the manager).
const _act = <String, Set<String>>{
  'PR': {'exec'}, 'RFQ': {'exec'}, 'PO': {'exec'}, 'GRN': {'store'}, 'PA': {'store'}, 'PRT': {'store'},
  'QT': {'exec'}, 'SO': {'exec'}, 'PK': {'store'}, 'PCK': {'store'}, 'DN': {'delivery'}, 'SHP': {'delivery'},
  'SR': {'store'}, 'TR': {'store'}, 'ADJ': {'store'}, 'CC': {'store'},
};

extension Access on AppStore {
  String get role => user?.role ?? '';
  bool get isManager => role == 'admin';
  bool get isSupplier => role == 'supplier';

  /// A sidebar screen: the ones chosen for this account (the role's standard ones by default);
  /// anything opened from inside a screen (tabs, records) follows the role.
  bool canView(String id) {
    if (isManager) return true;
    if (adminOnlyScreens.contains(id)) return false;
    final u = user;
    if (u == null) return false;
    final standard = _screens[role]?.contains(id) ?? false;
    if (u.screens == null || !grantableScreens.contains(id)) return standard;
    return u.screens!.contains(id);
  }

  bool canCreate(String docType) => isManager || (_create[docType]?.contains(role) ?? false);

  /// Whether the signed-in person may press [label] on a document of [docType].
  bool canAct(String docType, String label) {
    if (isManager) return true;
    final l = label.toLowerCase();
    if (l.startsWith('print') || l.startsWith('download') || l.startsWith('view')) return true;
    // approvals, rejections, credit holds and money steps are the manager's
    if (l.startsWith('approve') || l == 'reject' || l.startsWith('release credit') || l.contains('credit note') || l.contains('invoice') || l.startsWith('pay') || l.startsWith('record payment')) {
      return false;
    }
    if (docType == 'PO' && (l.startsWith('receive') || l.startsWith('goods received'))) return role == 'store'; // goods arrive at the store
    // whoever may raise a document may submit it for approval
    if (l.startsWith('submit')) return canCreate(docType);
    if (docType == 'GRN' && l.startsWith('return')) return role == 'store' || role == 'exec';
    return _act[docType]?.contains(role) ?? false;
  }
}
