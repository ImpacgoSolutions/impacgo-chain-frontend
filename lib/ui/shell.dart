import 'package:flutter/material.dart';
import 'select.dart';
import '../app_state.dart';
import '../core/store.dart';
import '../core/auth.dart';
import '../core/format.dart';
import '../core/models.dart' show qcDone;
import '../screens/registry.dart';
import '../screens/common.dart';
import 'overlays.dart';
import 'tokens.dart';
import 'widgets.dart';

class NavCategory {
  final String label, icon;
  final List<NavItem> items;
  const NavCategory(this.label, this.icon, this.items);
}

class NavItem {
  final String id, label, icon;
  final int Function()? count;
  final NavCategory? category;
  const NavItem(this.id, this.label, this.icon, [this.count]) : category = null;
  NavItem.category(this.label, this.icon, List<NavItem> subItems)
      : id = '',
        count = null,
        category = NavCategory(label, icon, subItems);
}

class NavGroup {
  final String? group;
  final List<NavItem> items;
  final bool collapsible;
  // Section titles are plain labels — no collapse arrow.
  const NavGroup(this.group, this.items, {this.collapsible = false});
}

int _open(String t, List<String> st) => S.docsOf(t).where((d) => st.contains(d.status)).length;

/// Sidebar in the order the daily work happens: buy → sell → stock → reports, with Setup last.
/// Each entry opens one screen (Vehicles & Drivers shows both as tabs).
final List<NavGroup> nav = [
  const NavGroup(null, [NavItem('workspace', 'SCM Workspace', 'grid')]),
  NavGroup('Buy', [
    NavItem('preqs', 'Purchase Requests', 'clipboard', () => _open('PR', ['Pending Approval'])),
    const NavItem('porders', 'Purchase Orders', 'bag'),
    NavItem('grns', 'Goods Receipts (GRN)', 'inbox', () => _open('GRN', ['QC Pending'])),
    // inspection of received goods: waiting for QC or with the QC team
    NavItem('qc', 'Quality Check', 'checksq', () => _open('GRN', ['QC Pending', 'QC Requested'])),
    // after QC: accepted goods go into storage bins
    NavItem('putaway', 'Bin Allocation', 'package', () => _open('PA', ['To Do'])),
    const NavItem('preturns', 'Purchase Returns', 'refund'),
    NavItem('pinvoices', 'Purchase Invoices', 'file', () => S.docsOf('PI').where((d) => d.status == 'Pending Approval').length),
  ]),
  // Supplier Portal (screen 'sportal', supplier login) is hidden for now — to be added back with the supplier screens
  NavGroup('Sell', [
    NavItem('leads', 'Leads', 'target', () => S.leads.where((l) => l.status == 'New').length),
    const NavItem('opps', 'Opportunities', 'target'),
    const NavItem('quotes', 'Quotations', 'file'),
    NavItem('sorders', 'Sales Orders', 'cart', () => _open('SO', ['Pending Approval', 'On Hold', 'Confirmed'])),
    // picking, packing, dispatch and delivery tracking on one screen
    NavItem('fulfil', 'Deliveries', 'truck', () => _open('PK', ['To Pick']) + _open('PCK', ['Packing']) + _open('DN', ['Ready to Dispatch'])),
    NavItem('sinvoices', 'Sales Invoices', 'receipt', () => S.docsOf('INV').where((d) => d.status != 'Paid').length),
    const NavItem('sreturns', 'Sales Returns', 'refund'),
  ]),
  NavGroup('Stock', [
    const NavItem('onhand', 'Stock Overview', 'box'),
    const NavItem('ledger', 'Stock Ledger', 'history'),
    const NavItem('batches', 'Batches & Serial Numbers', 'clipboard'),
    const NavItem('transfers', 'Stock Transfers', 'swap'),
    NavItem('adjust', 'Stock Adjustments', 'sliders', () => _open('ADJ', ['Pending Approval'])),
    const NavItem('counting', 'Physical Stock Count', 'clipboard'),
  ]),
  NavGroup('Reports', [
    NavItem.category('Sales Reports', 'bars', const [
      NavItem('rep_so', 'Sales Order Register', 'file'),
      NavItem('rep_pending_delivery', 'Pending Deliveries', 'file'),
    ]),
    NavItem.category('Purchase Reports', 'bars', const [
      NavItem('rep_po', 'Purchase Order Register', 'file'),
      NavItem('rep_pending_po', 'Pending Purchase Orders', 'file'),
      NavItem('rep_grn', 'Goods Receipt Register', 'file'),
    ]),
    NavItem.category('Inventory Reports', 'bars', const [
      NavItem('rep_stock_overview', 'Stock Summary', 'file'),
      NavItem('rep_stock_movement', 'Stock Ledger', 'file'),
      NavItem('rep_low_stock', 'Reorder Level Report', 'file'),
    ]),
  ]),
  const NavGroup('Setup', [
    NavItem('h_company', 'Company Settings', 'gear'),
    NavItem('h_warehouses', 'Warehouses', 'home'),
    NavItem('h_items', 'Items', 'box'),
    NavItem('h_customers', 'Customers', 'users'),
    NavItem('suppliers', 'Suppliers', 'store'),
    NavItem('h_team', 'Sales & Delivery Team', 'truck'),
  ]),
];

/// Sidebar entries the signed-in person may open.
bool navItemVisible(NavItem it) => it.category != null ? it.category!.items.any((x) => S.canView(x.id)) : S.canView(it.id);
bool navGroupVisible(NavGroup g) => g.items.any(navItemVisible);

/// The first screen the signed-in person may open (where they land if a screen is not theirs).
String firstAllowedView() {
  for (final g in nav) {
    for (final it in g.items) {
      if (it.category == null && S.canView(it.id)) return it.id;
      for (final sub in it.category?.items ?? const <NavItem>[]) {
        if (S.canView(sub.id)) return sub.id;
      }
    }
  }
  return 'workspace';
}

List<String> crumbsFor(String id) {
  for (final g in nav) {
    for (final it in g.items) {
      final group = g.group?.replaceFirst(RegExp(r'^\d+ · '), '');
      if (it.id == id) return [if (group != null) group, it.label];
      for (final sub in it.category?.items ?? const <NavItem>[]) {
        if (sub.id == id) return [if (group != null) group, it.label, sub.label];
      }
    }
  }
  return ['SCM Workspace'];
}

// ================================================================ ROOT SHELL
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: S,
      builder: (ctx, _) {
        final desktop = isDesktop(ctx);
        resolveView();
        // a screen this person may not open (e.g. a supplier) goes to their first allowed screen
        if (!S.canView(S.view)) S.view = firstAllowedView();
        final content = _Content(view: S.view);
        if (desktop) {
          return Scaffold(
            body: Row(children: [
              if (!S.sideCollapsed) SizedBox(width: 246, child: RepaintBoundary(child: Sidebar())),
              Expanded(child: Column(children: [RepaintBoundary(child: TopBar(onMenu: () => S.sideCollapsed = !S.sideCollapsed, desktop: true)), Expanded(child: content)])),
            ]),
          );
        }
        return Scaffold(
          key: _scaffold,
          drawer: Drawer(width: 270, backgroundColor: C.navy950, child: Sidebar(onPicked: () => _scaffold.currentState?.closeDrawer())),
          body: SafeArea(child: Column(children: [TopBar(onMenu: () => _scaffold.currentState?.openDrawer(), desktop: false), Expanded(child: content)])),
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  final String view;
  const _Content({required this.view});
  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final crumbs = crumbsFor(view);
    return SingleChildScrollView(
      key: PageStorageKey('page-$view'),
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 24, mobile ? 14 : 20, mobile ? 14 : 24, 60),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1420),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Text('IMPACGO Chain', style: TextStyle(fontSize: 12, color: C.faint)),
                for (var i = 0; i < crumbs.length; i++) ...[
                  const Text('›', style: TextStyle(fontSize: 12, color: C.faint)),
                  Text(crumbs[i], style: TextStyle(fontSize: 12, color: i == crumbs.length - 1 ? C.soft : C.faint, fontWeight: i == crumbs.length - 1 ? FontWeight.w600 : FontWeight.w400)),
                ],
                const Text('›', style: TextStyle(fontSize: 12, color: C.faint)),
                Text(S.currentWh.code, style: const TextStyle(fontSize: 12, color: C.faint)),
              ]),
            ),
            buildView(view),
          ]),
        ),
      ),
    );
  }
}

// ================================================================ SIDEBAR
class Sidebar extends StatefulWidget {
  final VoidCallback? onPicked;
  const Sidebar({super.key, this.onPicked});
  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final Map<String, bool> _collapsed = {};
  final Map<String, bool> _openCat = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.navy900, C.navy950])),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), gradient: const LinearGradient(colors: [C.blue600, Color(0xFF6A5CF7)])),
                child: const Text('IC', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              const Flexible(child: Text('IMPACGO Chain', maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x14FFFFFF))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(S.currentCompany, style: const TextStyle(color: C.sideStrong, fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${S.warehouses.length} warehouses · SCM Edition', style: const TextStyle(color: Color(0xFF9AA3BA), fontSize: 12)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
              for (final g in nav.where(navGroupVisible)) ...[
                if (g.group != null)
                  if (!g.collapsible)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 8, 6),
                      child: Text(
                        g.group!.toUpperCase(),
                        style: const TextStyle(fontSize: 10.5, letterSpacing: .8, color: C.sideLabel, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    InkWell(
                      onTap: () => setState(() => _collapsed[g.group!] = !(_collapsed[g.group!] ?? false)),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 8, 6),
                        child: Text(
                          '${g.group!.toUpperCase()} ${_collapsed[g.group!] == true ? "▸" : "▾"}',
                          style: const TextStyle(fontSize: 10.5, letterSpacing: .8, color: C.sideLabel, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                if (g.group == null || !g.collapsible || _collapsed[g.group!] != true)
                  for (final it in g.items.where(navItemVisible))
                    if (it.category != null) ...[
                      Builder(builder: (_) {
                        final label = it.category!.label;
                        // open when clicked, or when one of its reports is the current screen
                        final open = _openCat[label] ?? it.category!.items.any((x) => x.id == S.view);
                        return Column(children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _openCat[label] = !open),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                child: Row(children: [
                                  Icon(ic(it.category!.icon), size: 16, color: C.sideText),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(label, style: const TextStyle(fontSize: 13.3, fontWeight: FontWeight.w500, color: C.sideText))),
                                  Icon(open ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, size: 18, color: C.sideText),
                                ]),
                              ),
                            ),
                          ),
                          if (open)
                            Padding(
                              padding: const EdgeInsets.only(left: 14, bottom: 4),
                              child: Column(children: [
                                for (final sub in it.category!.items.where((x) => S.canView(x.id))) _NavTile(sub, widget.onPicked),
                              ]),
                            ),
                        ]);
                      }),
                    ] else
                      _NavTile(it, widget.onPicked),
              ],
              const SizedBox(height: 12),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x14FFFFFF)))),
            child: Row(children: [
              Avatar(S.user?.name ?? 'Srinivas Rao', strong: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(S.user?.name ?? 'Srinivas Rao', style: const TextStyle(color: C.sideStrong, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text((S.user?.title ?? 'SCM Manager').split(' · ').first, style: const TextStyle(color: Color(0xFF8C95AB), fontSize: 11.5)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}


class _NavTile extends StatelessWidget {
  final NavItem it;
  final VoidCallback? onPicked;
  const _NavTile(this.it, this.onPicked);
  @override
  Widget build(BuildContext context) {
    final active = S.view == it.id;
    final c = it.count?.call() ?? 0;
    // Plain box (no ink, no animation): the active colour switches instantly and
    // tapping the screen that is already open does nothing, so nothing flickers.
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: MouseRegion(
        cursor: active ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            onPicked?.call();
            if (!active) S.go(it.id);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: active ? C.blue600 : Colors.transparent, borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              Icon(ic(it.icon), size: 16, color: active ? Colors.white : C.sideText),
              const SizedBox(width: 10),
              Expanded(child: Text(it.label, style: TextStyle(fontSize: 13.3, fontWeight: FontWeight.w500, color: active ? Colors.white : C.sideText))),
              if (c > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: active ? const Color(0x2EFFFFFF) : const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(20)),
                  child: Text('$c', style: const TextStyle(fontSize: 11, color: Color(0xFFDFE3EE))),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ================================================================ TOP BAR
class TopBar extends StatelessWidget {
  final VoidCallback onMenu;
  final bool desktop;
  const TopBar({super.key, required this.onMenu, required this.desktop});

  Widget _switcher(String icon, String value, List<Opt> options, void Function(String) onPick, {double maxW = 170}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      height: 36,
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic(icon), size: 14, color: C.faint),
        const SizedBox(width: 7),
        ProtoSelect(kind: SelKind.bare, maxWidth: maxW, value: value, options: options.map((o) => SelOpt(o.value, o.label)).toList(), onChanged: onPick),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final whSwitch = _switcher('grid', S.currentWh.id, S.warehouses.map((w) => Opt(w.id, mobile ? w.code : '${w.code} — ${w.city}')).toList(), (v) {
      S.currentWh = S.wh(v);
      S.refresh();
      toast('Now working in ${S.currentWh.name}');
    }, maxW: mobile ? 78 : 170);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 22, vertical: 11),
      decoration: const BoxDecoration(color: C.card, border: Border(bottom: BorderSide(color: C.border))),
      child: Row(children: [
        // sidebar is always shown on desktop — the menu button only opens the drawer on phones
        if (!desktop) ...[
          IconBtn('menu', onMenu, tip: 'Menu'),
          const SizedBox(width: 12),
        ],
        // a supplier sees only its portal: no company-wide search, entity / warehouse switch or alerts
        if (S.isSupplier)
          const Expanded(child: Text('IMPACGO Chain · Supplier Portal', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)))
        else if (!mobile)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: TextField(
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search orders, invoices, items, customers…',
                    fillColor: C.bg,
                    prefixIcon: Icon(Icons.search, size: 17, color: C.faint),
                    prefixIconConstraints: BoxConstraints(minWidth: 36),
                  ),
                  onSubmitted: globalSearch,
                ),
              ),
            ),
          )
        else ...[
          const Expanded(child: Text('IMPACGO Chain', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
          IconBtn('search', () => openSearchDialog()),
        ],
        const SizedBox(width: 10),
        if (!S.isSupplier && screenW(context) >= 900) ...[
          _switcher('store', S.currentCompany, S.companies.map((c) => Opt(c, c)).toList(), (v) {
            S.currentCompany = v;
            S.refresh();
            toast('Switched legal entity to $v');
          }),
          const SizedBox(width: 10),
        ],
        if (!S.isSupplier) ...[
          whSwitch,
          const SizedBox(width: 10),
          IconBtn('bell', openNotifications, dot: true, tip: 'Notifications'),
          const SizedBox(width: 10),
        ],
        // start over: reloads the app so it opens fresh on the SCM Workspace (like F5)
        IconBtn('refresh', S.restartApp, tip: 'Restart — reload the app and start fresh'),
        const SizedBox(width: 10),
        InkWell(
          onTap: openProfile,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: mobile ? const EdgeInsets.all(2) : const EdgeInsets.fromLTRB(5, 5, 10, 5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: mobile ? Colors.transparent : C.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Avatar(S.user?.name ?? 'Srinivas Rao', strong: true),
              if (!mobile && screenW(context) >= 1000) ...[
                const SizedBox(width: 9),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(S.user?.name ?? 'Srinivas Rao', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  Text(S.user?.title ?? 'SCM Manager · All modules', style: const TextStyle(fontSize: 11, color: C.faint)),
                ]),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more, size: 16, color: C.soft),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

// ================================================================ search / alerts / profile
void globalSearch(String q) {
  q = q.trim().toLowerCase();
  if (q.isEmpty) return;
  for (final d in S.docs) {
    if (d.id.toLowerCase().contains(q)) {
      openDocNav(d.id);
      return;
    }
  }
  for (final p in S.items) {
    if (p.name.toLowerCase().contains(q) || p.id.toLowerCase() == q) {
      S.go('items');
      openItemPanel(p.id);
      return;
    }
  }
  for (final c in S.customers) {
    if (c.name.toLowerCase().contains(q)) {
      S.go('customers');
      openCustomerPanel(c.id);
      return;
    }
  }
  for (final s in S.suppliers) {
    if (s.name.toLowerCase().contains(q)) {
      S.go('suppliers');
      openSupplierPanel(s.id);
      return;
    }
  }
  toast('No order, invoice, item or party matched “$q”');
}

void openSearchDialog() {
  final c = TextEditingController();
  openModal(
    'Search',
    TextField(
      controller: c,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'Order no., invoice, item or customer', prefixIcon: Icon(Icons.search, size: 17)),
      onSubmitted: (v) {
        Navigator.of(rootCtx).pop();
        globalSearch(v);
      },
    ),
    size: ModalSize.narrow,
    actions: (ctx) => [
      Btn('Search', icon: 'search', onTap: () {
        Navigator.of(ctx).pop();
        globalSearch(c.text);
      })
    ],
  );
}

class Alert {
  final String icon, title, sub;
  final Tone tone;
  final String? doc, view;
  Alert(this.icon, this.tone, this.title, this.sub, {this.doc, this.view});
}

List<Alert> alertsList() {
  final a = <Alert>[];
  for (final d in S.docsOf('SO').where((d) => d.status == 'Pending Approval')) {
    a.add(Alert('alert', Tone.amber, '${d.id} awaits approval', '${S.partyName(d)} · ${fmtINR(d.amount)} is above the ${fmtINR(S.params.soApproval)} limit', doc: d.id));
  }
  for (final d in S.docsOf('SO').where((d) => d.status == 'On Hold')) {
    a.add(Alert('lock', Tone.red, '${d.id} on credit hold', d.hold ?? '', doc: d.id));
  }
  for (final p in S.items) {
    for (final w in S.warehouses) {
      if (S.avail(w.id, p.id) < p.reorder) {
        a.add(Alert('box', Tone.red, 'Below reorder: ${p.name}', '${S.avail(w.id, p.id)} ${p.uom} available at ${w.code} — reorder level ${p.reorder}', view: 'onhand'));
      }
    }
  }
  for (final d in S.docsOf('GRN').where((d) => !qcDone(d))) {
    a.add(Alert('inbox', Tone.blue, '${d.id} ${d.status == 'QC Requested' ? 'with the QC team' : 'waiting for QC'}', '${S.partyName(d)} · ${S.calc(d).qty} units at ${S.wh(d.wh).code}', doc: d.id));
  }
  for (final d in S.docsOf('PI').where((d) => d.status == 'Pending Approval')) {
    a.add(Alert('alert', Tone.amber, '${d.id} — invoice verification failed', d.match?.msg ?? '', doc: d.id));
  }
  for (final b in S.batches.where((b) => b.status == 'Expiring Soon')) {
    a.add(Alert('clock', Tone.amber, 'Batch ${b.id} expires ${b.exp}', '${S.item(b.item).name} · ${b.qty} at ${S.wh(b.wh).code}', view: 'batches'));
  }
  for (final d in S.docsOf('INV').where((i) => i.status != 'Paid' && i.due != null && daysBetween(i.due!, todayStr()) > 0)) {
    a.add(Alert('clock', Tone.red, '${d.id} overdue ${daysBetween(d.due!, todayStr())} days', '${S.partyName(d)} · balance ${fmtINR(d.amount - d.paid)}', doc: d.id));
  }
  return a;
}

void openNotifications() {
  final a = alertsList();
  openModal(
    'Notifications · ${a.length} need attention',
    Column(children: [
      for (final x in a)
        ActivityRow(x.icon, x.title, x.sub, tone: x.tone, onTap: () {
          closeAll();
          if (x.doc != null) {
            openDocNav(x.doc!);
          } else {
            S.go(x.view!);
          }
        }),
    ]),
    actions: (ctx) => [Btn.secondary('Close', onTap: () => Navigator.of(ctx).pop())],
  );
}

void openProfile() {
  openModal(
    'Srinivas Rao — SCM Manager',
    KvGrid([
      Kv.t('Employee ID', 'EMP-0102'),
      Kv.t('Legal entity', S.currentCompany),
      Kv.t('Default warehouse', S.currentWh.name),
      Kv.t('Role', 'SCM Manager (all modules)'),
      Kv.t('Approval limit', fmtINR(2500000)),
      Kv.t('GSTIN', S.companyInfo['gstin']!),
    ]),
    actions: (ctx) => [Btn.secondary('Close', onTap: () => Navigator.of(ctx).pop())],
  );
}
