import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/auth.dart';
import '../ui/overlays.dart';
import '../ui/select.dart';
import '../ui/shell.dart' show sidebarScreens;
import '../ui/table.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// Setup › Users & Roles (SCM Manager only): every account, who it is, its role and the screens it may open.
/// An account's sidebar shows exactly the screens ticked for it.
Widget usersView() {
  final active = S.users.where((u) => u.active).length;
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const PageHeader('Users & Roles', sub: 'Create accounts, choose each person\'s role and the screens they can open'),
    StatRow([
      Stat('Accounts', '${S.users.length}', 'All', 'users', Tone.blue),
      Stat('Active', '$active', 'Can sign in', 'check', Tone.green),
      Stat('Staff', '${S.users.where((u) => u.role != 'supplier').length}', 'Company', 'badge', Tone.purple),
      Stat('Suppliers', '${S.users.where((u) => u.role == 'supplier').length}', 'Portal', 'store', Tone.amber),
    ], max: 4, compact: true),
    DataTableCard(
      id: 'users',
      rows: S.users,
      exportName: 'users',
      createLabel: 'New user',
      onCreate: () => openUserForm(),
      onRow: (r) => openUserForm(r as AppUser),
      allowDelete: false,
      search: (r) => '${(r as AppUser).name} ${r.email} ${r.title}',
      filters: [
        Filt('Role', roleNames.values.toList(), (r) => roleNames[(r as AppUser).role] ?? ''),
        Filt('Status', const ['Active', 'Inactive'], (r) => (r as AppUser).active ? 'Active' : 'Inactive'),
      ],
      cols: [
        Col('Name', (r) => CellAv((r as AppUser).name, r.email), text: (r) => (r as AppUser).name, sort: (r) => (r as AppUser).name),
        Col.t('Role', (r) => roleNames[(r as AppUser).role] ?? r.role),
        Col.t('Works at', (r) => _worksAt(r as AppUser)),
        Col.t('Mobile', (r) => (r as AppUser).phone.isEmpty ? '—' : r.phone),
        Col.t('Screens', (r) => (r as AppUser).role == 'admin' ? 'All' : '${_screensOf(r).length}', num: true),
        Col('Status', (r) => StatusBadge((r as AppUser).active ? 'Active' : 'Inactive', tone: r.active ? Tone.green : Tone.gray), status: true, text: (r) => (r as AppUser).active ? 'Active' : 'Inactive'),
      ],
    ),
  ]);
}

String _worksAt(AppUser u) {
  if (u.role == 'supplier') return u.party == null || !S.suppliers.any((s) => s.id == u.party) ? '—' : S.sup(u.party!).name;
  if (u.wh.isEmpty || !S.warehouses.any((w) => w.id == u.wh)) return 'All warehouses';
  return '${S.wh(u.wh).code} — ${S.wh(u.wh).city}';
}

Set<String> _screensOf(AppUser u) => u.screens ?? roleScreens(u.role);

void openUserForm([AppUser? u]) => openFormPage(u == null ? 'New user' : 'Edit user · ${u.name}', UserForm(u), subtitle: 'Fill in the mandatory fields (*) and choose the screens');

class UserForm extends StatefulWidget {
  final AppUser? user;
  const UserForm(this.user, {super.key});
  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  late final _phone = TextEditingController(text: widget.user?.phone ?? '');
  final _pass = TextEditingController();
  late String _role = widget.user?.role ?? 'exec';
  late String _wh = widget.user?.wh ?? '';
  late String _sup = widget.user?.party ?? '';
  late bool _active = widget.user?.active ?? true;
  late Set<String> _screens = {...?(widget.user == null ? null : _screensOf(widget.user!))};
  bool _tried = false;

  bool get _editing => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (!_editing) _screens = roleScreens(_role);
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The sidebar sections this role can be given (a supplier: only its portal; staff: everything else).
  /// Users & Roles and Company Settings stay with the SCM Manager.
  List<(String, List<(String, String)>)> get _groups => [
        for (final g in sidebarScreens())
          if (_role == 'supplier' ? g.$1 == 'Supplier Portal' : g.$1 != 'Supplier Portal')
            (g.$1, [for (final i in g.$2) if (!adminOnlyScreens.contains(i.id)) (i.id, i.label)]),
      ].where((g) => g.$2.isNotEmpty).toList();

  void _setRole(String r) => setState(() {
        _role = r;
        _screens = roleScreens(r); // a new role starts with its standard screens
      });

  String? _problem() {
    final email = _email.text.trim().toLowerCase();
    if (_name.text.trim().isEmpty) return 'Enter the full name';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email address';
    if (S.users.any((x) => x != widget.user && x.email.toLowerCase() == email)) return 'An account with this email already exists';
    if (!_editing && _pass.text.length < 6) return 'The password needs at least 6 characters';
    if (_editing && _pass.text.isNotEmpty && _pass.text.length < 6) return 'The new password needs at least 6 characters';
    if (_role == 'supplier' && _sup.isEmpty) return 'Choose the supplier this login belongs to';
    if (_role != 'admin' && _screens.isEmpty) return 'Tick at least one screen';
    final me = S.user;
    if (_editing && widget.user == me && (_role != 'admin' || !_active)) return 'You cannot remove your own Admin role or switch off your own account';
    final admins = S.users.where((x) => x.role == 'admin' && x.active && x != widget.user).length;
    if (admins == 0 && (_role != 'admin' || !_active)) return 'At least one active SCM Manager (Admin) is needed';
    return null;
  }

  void _save() {
    final p = _problem();
    if (p != null) {
      setState(() => _tried = true);
      toast(p);
      return;
    }
    final supName = _sup.isEmpty || !S.suppliers.any((s) => s.id == _sup) ? '' : S.sup(_sup).name;
    final screens = _role == 'admin' ? null : {..._screens};
    final u = widget.user;
    if (u == null) {
      S.users.add(AppUser(_email.text.trim(), _pass.text, _name.text.trim(), _role, roleTitle(_role, supplierName: supName),
          party: _role == 'supplier' ? _sup : null, phone: _phone.text.trim(), wh: _role == 'supplier' ? '' : _wh, active: _active, screens: screens));
    } else {
      u
        ..name = _name.text.trim()
        ..email = _email.text.trim()
        ..phone = _phone.text.trim()
        ..role = _role
        ..title = roleTitle(_role, supplierName: supName)
        ..party = _role == 'supplier' ? _sup : null
        ..wh = _role == 'supplier' ? '' : _wh
        ..active = _active
        ..screens = screens;
      if (_pass.text.isNotEmpty) u.password = _pass.text;
    }
    closeAll();
    S.go('h_users');
    S.refresh();
    toast(u == null ? 'Account created for ${_name.text.trim()} · ${roleNames[_role]} · they can sign in with ${_email.text.trim()}' : 'Changes saved for ${_name.text.trim()}');
  }

  Widget _label(String t, {bool req = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [TextSpan(text: t), if (req) const TextSpan(text: ' *', style: TextStyle(color: C.red))]),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft)),
      );

  Widget _field(String label, TextEditingController c, {bool req = false, String? hint, bool secret = false, TextInputType? type}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, req: req),
        TextField(
          controller: c,
          obscureText: secret,
          keyboardType: type,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13)),
          onChanged: (_) => _tried ? setState(() {}) : null,
        ),
      ]);

  Widget _select(String label, String value, List<SelOpt> options, ValueChanged<String> onChanged, {bool req = false, String? placeholder}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, req: req),
        ProtoSelect(value: value, options: options, placeholder: placeholder, onChanged: onChanged),
      ]);

  Widget _screensBox(double width) {
    if (_role == 'admin') {
      return const NoteBox(Tone.blue, 'lock', 'The SCM Manager (Admin) sees every screen.', 'Including Users & Roles and Company Settings, which only the Admin can open.');
    }
    final all = [for (final g in _groups) ...g.$2.map((x) => x.$1)];
    final per = width >= 700 ? 3 : (width >= 440 ? 2 : 1);
    final cell = (width - 34 - 12 * (per - 1)) / per; // inside the box's padding and border
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('${_screens.where(all.contains).length} of ${all.length} screens ticked · this person\'s sidebar shows exactly these', style: const TextStyle(fontSize: 12, color: C.faint))),
        Btn.ghost('Standard for the role', small: true, onTap: () => setState(() => _screens = roleScreens(_role))),
      ]),
      const SizedBox(height: 8),
      for (final g in _groups)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(R.sm)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(g.$1.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.soft, letterSpacing: .5))),
              () {
                final ids = g.$2.map((x) => x.$1).toSet();
                final allOn = ids.every(_screens.contains);
                return Btn.ghost(allOn ? 'Clear' : 'Select all', small: true, onTap: () => setState(() => allOn ? _screens.removeAll(ids) : _screens.addAll(ids)));
              }(),
            ]),
            Wrap(spacing: 12, runSpacing: 2, children: [
              for (final (id, label) in g.$2)
                SizedBox(
                  width: cell,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => setState(() => _screens.contains(id) ? _screens.remove(id) : _screens.add(id)),
                    child: Row(children: [
                      SizedBox(width: 32, height: 32, child: Checkbox(value: _screens.contains(id), onChanged: (v) => setState(() => v == true ? _screens.add(id) : _screens.remove(id)))),
                      const SizedBox(width: 4),
                      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final two = c.maxWidth >= 560;
      final half = two ? (c.maxWidth - 14) / 2 : c.maxWidth;
      final p = _tried ? _problem() : null;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Account', first: true),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: half, child: _field('Full Name', _name, req: true, hint: 'e.g. Ravi Teja')),
          SizedBox(width: half, child: _field('Email', _email, req: true, hint: 'name@impacgo.com', type: TextInputType.emailAddress)),
          SizedBox(width: half, child: _field('Mobile No.', _phone, hint: '+91 98480 12345', type: TextInputType.phone)),
          SizedBox(width: half, child: _field(_editing ? 'New Password' : 'Password', _pass, req: !_editing, secret: true, hint: _editing ? 'Leave empty to keep the current one' : 'At least 6 characters')),
        ]),
        const SectionTitle('Role'),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(
            width: half,
            child: _select('Role', _role, [for (final e in roleNames.entries) SelOpt(e.key, e.value)], _setRole, req: true),
          ),
          if (_role == 'supplier')
            SizedBox(
              width: half,
              child: _select('Supplier', _sup, [for (final s in S.suppliers.where((s) => s.status != 'Inactive' || s.id == _sup)) SelOpt(s.id, s.name)], (v) => setState(() => _sup = v),
                  req: true, placeholder: 'Select supplier'),
            )
          else
            SizedBox(
              width: half,
              child: _select('Works At', _wh, [const SelOpt('', 'All warehouses'), for (final w in S.warehouses) SelOpt(w.id, '${w.code} — ${w.city}')], (v) => setState(() => _wh = v)),
            ),
          if (_editing)
            SizedBox(
              width: half,
              child: _select('Status', _active ? 'Active' : 'Inactive', const [SelOpt('Active', 'Active · can sign in'), SelOpt('Inactive', 'Inactive · cannot sign in')], (v) => setState(() => _active = v == 'Active')),
            ),
          SizedBox(width: c.maxWidth, child: Text(roleHints[_role] ?? '', style: const TextStyle(fontSize: 12, color: C.faint))),
        ]),
        const SectionTitle('Screens'),
        _screensBox(c.maxWidth),
        if (p != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(p, style: const TextStyle(fontSize: 12.5, color: C.red))),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
          Btn.secondary('Cancel', onTap: () => Navigator.of(context).pop()),
          Btn(_editing ? 'Save changes' : 'Create user', icon: _editing ? null : 'check', onTap: _save),
        ]),
      ]);
    });
  }
}
