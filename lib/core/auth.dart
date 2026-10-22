// Demo sign-in and role-based access.
// Each role sees only its own screens, and only the people responsible for a
// step get its buttons — approvals and rejections belong to the manager only.
import 'store.dart';

class AppUser {
  final String email, password, name, role, title;
  /// Supplier logins: the supplier they belong to (they see only its orders and invoices).
  final String? party;
  const AppUser(this.email, this.password, this.name, this.role, this.title, {this.party});
}

/// Demo accounts (for testing only — replace with the real login portal later).
const demoUsers = [
  AppUser('admin@impacgo.com', 'Admin@123', 'Srinivas Rao', 'admin', 'SCM Manager · All modules'),
  AppUser('executive@impacgo.com', 'Exec@123', 'Priya Sharma', 'exec', 'Purchase & Sales Executive'),
  AppUser('store@impacgo.com', 'Store@123', 'Kiran Kumar', 'store', 'Store Keeper · Warehouse & QC'),
  AppUser('delivery@impacgo.com', 'Delivery@123', 'Suresh Naidu', 'delivery', 'Delivery Staff'),
  // a supplier's login: sees only the Supplier Portal, with its own requests for quotation, orders and invoices
  AppUser('supplier@andhracorrugators.com', 'Supplier@123', 'N. Prasad', 'supplier', 'Supplier · Andhra Corrugators', party: 'S001'),
];

/// Our own staff (not supplier logins), e.g. for "Requested By".
List<AppUser> get staffUsers => demoUsers.where((u) => u.role != 'supplier').toList();

/// The role of a person, e.g. "Store Keeper" ('' when the name is not a user).
String roleOfName(String name) {
  final u = demoUsers.where((u) => u.name == name).firstOrNull;
  return u == null ? '' : u.title.split(' · ').first;
}

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

  bool canView(String id) => isManager || (_screens[role]?.contains(id) ?? false);

  bool canCreate(String docType) => isManager || (_create[docType]?.contains(role) ?? false);

  /// Whether the signed-in person may press [label] on a document of [docType].
  bool canAct(String docType, String label) {
    if (isManager) return true;
    final l = label.toLowerCase();
    if (l.startsWith('print')) return true;
    // approvals, rejections, credit holds and money steps are the manager's
    if (l.startsWith('approve') || l == 'reject' || l.startsWith('release credit') || l.contains('credit note') || l.contains('invoice') || l.startsWith('pay') || l.startsWith('record payment')) {
      return false;
    }
    if (docType == 'PO' && l.startsWith('receive')) return role == 'store'; // goods arrive at the store
    if (docType == 'GRN' && l.startsWith('return')) return role == 'store' || role == 'exec';
    return _act[docType]?.contains(role) ?? false;
  }
}
