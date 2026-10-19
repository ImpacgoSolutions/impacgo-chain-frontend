# IMPACGO Chain — Flutter UI (web + mobile)

A responsive Flutter build of the IMPACGO Chain SCM prototype. The layout, colours and
flows match the HTML prototype. It runs entirely in memory with seeded data: no backend,
and no third-party packages (only the Flutter SDK).

## Run it

```bash
cd impacgo_chain
flutter create . --platforms=web,android,ios   # adds the platform folders; keeps lib/ as is
flutter pub get
flutter run -d chrome        # web
flutter run                  # a connected Android / iOS device or emulator
flutter test                 # boot test + Order-to-Cash and Procure-to-Pay flow tests
```

Needs Flutter 3.22 or newer (Dart 3.4+).

## Look and feel

- Font: **Lato 2.0** is bundled in `assets/fonts`. The HTML prototype renders in Segoe UI on Windows; Lato was measured
  against it and matches glyph widths within ±3% and x-height within 1% (Inter was 6–11% wider). It is also
  registered under Flutter's default family name, so every widget uses it.
- Tables use an HTML-style layout (not Flutter's DataTable): 10×15 / 11×15 cell padding, content-sized rows and
  browser-like column widths.
- Material 3's extra letter-spacing is removed and line height set to the prototype's value.
- After pulling this update run `flutter pub get` again and do a full restart (not hot reload) so the fonts load.

## Responsive behaviour

| Width | Layout |
|---|---|
| ≥ 1100 px (desktop) | Fixed 246 px navy sidebar (can be collapsed), full top bar, tables, 600 px side drawer |
| 760–1099 px (tablet) | Sidebar opens as a drawer; top bar and tables stay the same |
| < 760 px (mobile) | Drawer menu, compact top bar (search icon, warehouse code, bell, avatar); tables turn into cards; document drawer is full screen; forms use one column |

## Folder map

```
lib/
  main.dart                 app entry, theme, table hooks
  app_state.dart            the single store instance (S)
  core/
    models.dart             all data classes
    store.dart              store, lookups, pricing, stock engine
    seed.dart               India demo data (3 warehouses, 8 customers, 8 suppliers, 14 items, documents)
    actions.dart            every business action (O2C, P2P, inventory, logistics, CRM, bulk)
    automation.dart         scheduled jobs, bank matching, emails, run log, rules
    format.dart             ₹ Indian grouping, dates
  ui/
    tokens.dart             colours, icons, theme (same values as the prototype CSS)
    widgets.dart            buttons, badges, cards, stat cards, tabs, stepper, KV grid …
    table.dart              data table: search, filters, sort, bulk bar, pager, CSV export, mobile cards
    overlays.dart           dialogs, right-hand drawer, form engine with validation, toast
    shell.dart              sidebar, top bar, crumbs, navigation, search, notifications, profile
  screens/
    registry.dart           nav id → screen (all 50)
    common.dart             document list/drawer, action buttons + dialogs, new-document form, party/item drawers
    sales_proc.dart         Sales, Procurement, Warehouse and Transport document screens
    inventory.dart          Stock on hand, ledger, batches & serials, bin movements
    logistics.dart          Delivery schedule, vehicles, load templates, carriers, supplier quotations
    masters.dart            Customers, groups, suppliers, items, item setup, pricing, sites/warehouses/bins
    crm.dart                Leads, opportunities, contacts, sales persons, territories
    reports.dart            Sales, purchase and inventory reports (16 reports)
    settings.dart           Workspace, Automation Center, Process Guide, Parameters, import & bulk actions
```

## Connecting a real backend later

All reads and writes go through `AppStore` (`lib/core`). Replace the method bodies in
`actions.dart` / `automation.dart` with API calls and keep the same method names; the screens
do not need to change.
