import 'package:flutter/material.dart';
import '../app_state.dart';
import '../ui/widgets.dart';
import 'cards.dart';
import 'crm.dart';
import 'inventory.dart';
import 'logistics.dart';
import 'masters.dart';
import 'reports.dart';
import 'sales_proc.dart';
import 'settings.dart';
import 'setup_lists.dart';
import 'report_templates.dart';
import 'supplier_portal.dart';
import 'users.dart';
import 'fulfilment.dart';
import 'qc.dart';

/// Sidebar entries that show related screens as tabs: hub id → [(tab label, screen id)].
const hubs = <String, List<(String, String)>>{
  'h_company': [('Company & Approval Limits', 'params'), ('Number Series', 'series'), ('Branches & Lists', 'setuplists'), ('Report Templates', 'rtemplates')],
  'h_warehouses': [('Warehouses', 'warehouses'), ('Bins / Locations', 'bins')],
  'h_items': [('Items', 'items'), ('Item Categories', 'itemcategories'), ('Units of Measure', 'itemsetup'), ('Price Lists', 'pricing')],
  'h_customers': [('Customers', 'customers'), ('Contacts', 'contacts'), ('Customer Groups', 'cgroups')],
  'h_team': [('Sales Persons', 'salespersons'), ('Territories', 'territories'), ('Vehicles', 'vehicles'), ('Drivers', 'drivers')],
};

/// The hub that contains [id] as a tab, if any.
String? hubOf(String id) {
  for (final e in hubs.entries) {
    if (e.value.any((t) => t.$2 == id)) return e.key;
  }
  return null;
}

/// Links that open a single screen (dashboard cards, linked documents…) land on
/// its hub with that tab selected, so the sidebar highlight stays correct.
void resolveView() {
  // Picking, Packing, Deliveries and Delivery Tracking live on Deliveries
  final st = fulfilStages.indexWhere((x) => x.id == S.view);
  if (st >= 0) {
    FulfilmentView.stage = st;
    S.view = 'fulfil';
    return;
  }
  final h = hubOf(S.view);
  if (h == null) return;
  Tabs.memory['hub_$h'] = hubs[h]!.indexWhere((t) => t.$2 == S.view);
  S.view = h;
}

Widget buildView(String id) {
  final tabs = hubs[id];
  if (tabs == null) return _screen(id);
  final key = 'hub_$id';
  return Tabs([for (final t in tabs) TabDef(t.$1, () => _screen(t.$2))], key: ValueKey('$key:${Tabs.memory[key] ?? 0}'), storeKey: key);
}

/// The screen with its four summary cards placed right under the page title.
Widget _screen(String id) {
  final w = _screenBody(id);
  final cards = screenCards(id);
  if (cards is SizedBox || w is! Column || w.children.isEmpty) return w;
  return Column(crossAxisAlignment: w.crossAxisAlignment, children: [w.children.first, cards, ...w.children.skip(1)]);
}

/// Maps a screen id to its screen.
Widget _screenBody(String id) {
  switch (id) {
    // CRM & Sales
    case 'leads':
      return leadsView();
    case 'opps':
      return oppsView();
    case 'contacts':
      return contactsView();
    case 'salespersons':
      return salesPersonsView();
    case 'territories':
      return territoriesView();
    case 'quotes':
      return quotesView();
    case 'sorders':
      return salesOrdersView();
    case 'fulfil':
      // not const: a link to a stage (e.g. Ready to dispatch) must redraw it
      // ignore: prefer_const_constructors
      return FulfilmentView();
    case 'deliveries':
      return deliveriesView();
    case 'sinvoices':
      return salesInvoicesView();
    case 'cpayments':
      return customerPaymentsView();
    case 'sreturns':
      return salesReturnsView();

    // Procurement / Purchase
    case 'preqs':
      return purchaseRequestsView();
    case 'rfqs':
      return rfqsView();
    case 'squotes':
      return supplierQuotesView();
    case 'porders':
      return purchaseOrdersView();
    case 'grns':
      return grnsView();
    case 'qc':
      return qcView();
    case 'sportal':
    case 'sp_po':
      return const SupplierPortalView(SupplierPage.orders);
    case 'h_users':
      return usersView();
    case 'sp_rfq':
      return const SupplierPortalView(SupplierPage.rfqs);
    case 'sp_inv':
      return const SupplierPortalView(SupplierPage.invoices);
    case 'pinvoices':
      return supplierInvoicesView();
    case 'preturns':
      return purchaseReturnsView();

    // Inventory
    case 'onhand':
      return onHandView();
    case 'ledger':
      return ledgerView();
    case 'transfers':
      return transfersView();
    case 'adjust':
      return adjustView();
    case 'batches':
      return batchesView();
    case 'counting':
      return countingView();

    // Warehouse & Logistics
    case 'putaway':
      return putawayView();
    case 'picking':
      return pickingView();
    case 'packing':
      return packingView();
    case 'moves':
      return movesView();
    case 'dschedule':
      return deliveryScheduleView();
    case 'loads':
      return loadsView();
    case 'shipments':
      return shipmentsView();
    case 'vehicles':
      return vehiclesView();
    case 'vallocation':
      return vehicleAllocationView();
    case 'dtracking':
      return deliveryTrackingView();
    case 'ltemplates':
      return loadTemplatesView();
    case 'carriers':
      return carriersView();

    // Master data
    case 'customers':
      return customersView();
    case 'cgroups':
      return customerGroupsView();
    case 'suppliers':
      return suppliersView();
    case 'sgroups':
      return supplierGroupsView();
    case 'items':
      return itemsView();
    case 'itemcategories':
      return itemCategoriesView();
    case 'itemsetup':
      return itemSetupView();
    case 'pricing':
      return pricingView();
    case 'warehouses':
      return warehousesView();
    case 'bins':
      return binsView();

    // Individual SCM Reports
    case 'reports':
    case 'rep_ar_ageing':
      return receivablesAgeingReportView();
    case 'rep_ap_ageing':
      return payablesAgeingReportView();
    case 'rep_so':
      return salesOrderReportView();
    case 'rep_dn':
      return deliveryReportView();
    case 'rep_sr':
      return salesReturnReportView();
    case 'rep_sales_customer':
      return salesByCustomerReportView();
    case 'rep_sales_item':
      return salesByItemReportView();

    case 'rep_po':
      return purchaseOrderReportView();
    case 'rep_grn':
      return grnReportView();
    case 'rep_pending_po':
      return pendingPoReportView();
    case 'rep_pr_ret':
      return purchaseReturnReportView();
    case 'rep_pur_supplier':
      return purchaseBySupplierReportView();
    case 'rep_pur_item':
      return purchaseByItemReportView();

    case 'rep_stock_overview':
      return stockOverviewReportView();
    case 'rep_stock_movement':
    case 'rep_stock_ledger':
      return stockMovementReportView();
    case 'rep_low_stock':
      return lowStockReportView();
    case 'rep_stock_transfer':
      return stockTransferReportView();
    case 'rep_stock_adj':
      return stockAdjustmentReportView();
    case 'rep_batch':
      return batchReportView();
    case 'rep_serial':
      return serialNumberReportView();

    case 'rep_sup_pur':
      return supplierPurchaseReportView();
    case 'rep_sup_perf':
      return supplierPerformanceReportView();

    case 'rep_cust_sales':
      return customerSalesReportView();
    case 'rep_cust_trans':
      return customerTransactionReportView();

    case 'rep_shipment':
      return shipmentReportView();
    case 'rep_dispatch':
      return dispatchReportView();
    case 'rep_pending_delivery':
      return pendingDeliveryReportView();

    // Internal fallbacks
    case 'automation':
      return automationView();
    case 'guide':
      return guideView();
    case 'params':
      return const ParamsView();
    case 'series':
      return seriesView();
    case 'setuplists':
      return setupListsView();
    case 'rtemplates':
      return const ReportTemplatesView();
    case 'drivers':
      return driversView();
    default:
      return workspaceView();
  }
}
