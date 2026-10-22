import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import 'select.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Country calling codes offered next to mobile number fields: (code, country).
const kCountryCodes = <(String, String)>[
  ('+91', 'India'), ('+1', 'USA / Canada'), ('+44', 'UK'), ('+971', 'UAE'), ('+966', 'Saudi Arabia'), ('+974', 'Qatar'), ('+965', 'Kuwait'),
  ('+968', 'Oman'), ('+973', 'Bahrain'), ('+65', 'Singapore'), ('+60', 'Malaysia'), ('+61', 'Australia'), ('+64', 'New Zealand'),
  ('+49', 'Germany'), ('+33', 'France'), ('+39', 'Italy'), ('+34', 'Spain'), ('+31', 'Netherlands'), ('+41', 'Switzerland'), ('+46', 'Sweden'),
  ('+353', 'Ireland'), ('+351', 'Portugal'), ('+48', 'Poland'), ('+7', 'Russia'), ('+90', 'Turkey'), ('+81', 'Japan'), ('+82', 'South Korea'),
  ('+86', 'China'), ('+852', 'Hong Kong'), ('+880', 'Bangladesh'), ('+94', 'Sri Lanka'), ('+977', 'Nepal'), ('+975', 'Bhutan'), ('+92', 'Pakistan'),
  ('+93', 'Afghanistan'), ('+62', 'Indonesia'), ('+66', 'Thailand'), ('+84', 'Vietnam'), ('+63', 'Philippines'), ('+27', 'South Africa'),
  ('+234', 'Nigeria'), ('+254', 'Kenya'), ('+20', 'Egypt'), ('+98', 'Iran'), ('+964', 'Iraq'), ('+972', 'Israel'), ('+55', 'Brazil'),
  ('+52', 'Mexico'), ('+54', 'Argentina'),
];

final navKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

BuildContext get rootCtx => navKey.currentContext!;

/// Every message shown so far this run (lets tests read what a person was told).
final List<String> debugToasts = [];

void toast(String msg) {
  debugToasts.add(msg);
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  final w = screenW(rootCtx);
  // the message sits in the bottom-right corner (full width at the bottom on a phone) and goes away by itself
  const cardW = 380.0;
  m.showSnackBar(SnackBar(
    content: Text(msg, textAlign: TextAlign.left),
    duration: const Duration(seconds: 3),
    behavior: SnackBarBehavior.floating,
    margin: w > 560 ? EdgeInsets.only(left: w - cardW - 22, right: 22, bottom: 22) : const EdgeInsets.fromLTRB(12, 0, 12, 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));
}

void closeAll() => navKey.currentState?.popUntil((r) => r.isFirst);

// ---------------------------------------------------------------- modal
enum ModalSize { narrow, normal, wide }

Future<void> openModal(String title, Widget body, {List<Widget> Function(BuildContext ctx)? actions, ModalSize size = ModalSize.normal}) async {
  await showDialog<void>(
    context: rootCtx,
    barrierColor: const Color(0x73141B2D),
    builder: (ctx) {
      final maxW = size == ModalSize.wide ? 900.0 : size == ModalSize.narrow ? 480.0 : 720.0;
      final mobile = isMobile(ctx);
      return Dialog(
        backgroundColor: C.card,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 40, vertical: mobile ? 20 : 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: MediaQuery.sizeOf(ctx).height * .88),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
              child: Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                IconBtn('x', () => Navigator.of(ctx).pop()),
              ]),
            ),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), child: body)),
            if (actions != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.border))),
                child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: actions(ctx)),
              ),
          ]),
        ),
      );
    },
  );
}

/// Opens a data-entry form as a full page (not a pop-up card): a header with
/// a back arrow and title, the form centred in an aligned two-column card, and
/// a fixed action bar at the bottom. Closing works exactly like a dialog
/// (Navigator.pop / closeAll), so every existing Save and Cancel still works.
Future<void> openFormPage(String title, Widget body, {List<Widget> Function(BuildContext ctx)? actions, List<Widget> headerActions = const [], String? subtitle}) async {
  await navKey.currentState!.push(PageRouteBuilder<void>(
    // instant: a fade shows the page underneath and looks like a blink
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) {
      final mobile = isMobile(ctx);
      final pad = mobile ? 14.0 : 28.0;
      final barActions = actions?.call(ctx) ?? const <Widget>[];
      return Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              color: C.card,
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
              child: Row(children: [
                IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(subtitle ?? 'Fill in the mandatory fields (*) and save', style: const TextStyle(fontSize: 12, color: C.faint)),
                  ]),
                ),
                ...headerActions,
              ]),
            ),
            const Divider(height: 1, color: C.border),
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) => ValueListenableBuilder<double>(
                  valueListenable: dropdownRoom,
                  builder: (_, room, __) => SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, 22, pad, 22 + room),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 1180, minHeight: math.max(0, box.maxHeight - 44)),
                        child: Container(
                          padding: EdgeInsets.all(mobile ? 16 : 26),
                          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
                          child: DropdownRoomScope(child: body),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (barActions.isNotEmpty)
              Container(
                decoration: const BoxDecoration(color: C.card, border: Border(top: BorderSide(color: C.border))),
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: barActions),
                  ),
                ),
              ),
          ]),
        ),
      );
    },
  ));
}

Future<void> confirmDelete(String what, VoidCallback onYes) => openModal(
      'Delete $what?',
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: C.redBg, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline, color: C.red, size: 18)),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('This action cannot be undone.', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            SizedBox(height: 3),
            Text('The records will be removed. Historical reports are not affected.', style: TextStyle(fontSize: 12.5, color: C.soft)),
          ]),
        ),
      ]),
      size: ModalSize.narrow,
      actions: (ctx) => [
        Btn.secondary('Cancel', onTap: () => Navigator.of(ctx).pop()),
        Btn.danger('Delete permanently', icon: 'trash', onTap: () {
          Navigator.of(ctx).pop();
          onYes();
        }),
      ],
    );

// ---------------------------------------------------------------- record page
/// Opens a record (document, customer, item…) as a full page, the same layout
/// as the form pages: a header with a back arrow and the title, the details in
/// a centred card, and the actions in a fixed bar at the bottom. Closing works
/// like before (Navigator.pop / closeAll), so every existing action still works.
Future<void> openPanel({required Widget Function(BuildContext ctx) header, required Widget Function(BuildContext ctx) body, List<Widget> Function(BuildContext ctx)? footer}) async {
  await navKey.currentState!.push(PageRouteBuilder<void>(
    // instant: a fade shows the page underneath and looks like a blink
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) {
      final mobile = isMobile(ctx);
      final pad = mobile ? 14.0 : 28.0;
      final acts = footer?.call(ctx) ?? const <Widget>[];
      return Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              color: C.card,
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
              child: Row(children: [
                IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.of(ctx).pop()),
                const SizedBox(width: 6),
                Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 18), child: header(ctx))),
              ]),
            ),
            const Divider(height: 1, color: C.border),
            Expanded(
              // the card fills the page height, so a short record does not leave a blank gap below it
              child: LayoutBuilder(
                builder: (_, box) => ValueListenableBuilder<double>(
                  valueListenable: dropdownRoom,
                  builder: (_, room, __) => SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, 22, pad, 22 + room),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 1180, minHeight: math.max(0, box.maxHeight - 44)),
                        child: Container(
                          padding: EdgeInsets.all(mobile ? 16 : 26),
                          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
                          child: DropdownRoomScope(child: body(ctx)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (acts.isNotEmpty)
              Container(
                decoration: const BoxDecoration(color: C.card, border: Border(top: BorderSide(color: C.border))),
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: acts),
                  ),
                ),
              ),
          ]),
        ),
      );
    },
  ));
}

/// Status strip at the top of a form: the status is decided by the system, not typed.
class FormStatusBar extends StatelessWidget {
  final String status, note;
  const FormStatusBar(this.status, this.note, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
        child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6, color: C.faint)),
          StatusBadge(status),
          Text(note, style: const TextStyle(fontSize: 12, color: C.soft)),
        ]),
      );
}

/// Record page title with its status shown right next to it.
Widget panelHead(String title, String sub, {Widget? status}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        if (status != null) status,
      ]),
      if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: const TextStyle(fontSize: 12, color: C.faint))),
    ]);

// ---------------------------------------------------------------- form engine
class Opt {
  final String value, label;
  final bool checked;
  const Opt(this.value, this.label, {this.checked = false});
}

List<Opt> opts(List<String> v) => v.map((x) => Opt(x, x)).toList();

class F {
  final String k, l;
  final String type; // text number email date select textarea checks header readonly
  final List<Opt> options;
  final String def;
  final bool req, full, calc;
  final String? help, hint, section;
  final String empty;
  /// Conditional field: shown and mandatory only when select [when] equals [whenIs] ("!X": when it is anything but X).
  final String? when, whenIs;
  /// Shown on the form but without the mandatory star (e.g. supplier pickers that start on
  /// "Select supplier"); the screen checks the value itself on save.
  final bool show;
  /// Select only: adds "Other (type your own)", which shows a text box and saves what is typed.
  final bool custom;

  const F(this.k, this.l, {
    this.custom = false,
    this.type = 'text',
    this.options = const [],
    this.def = '',
    this.req = false,
    this.full = false,
    this.calc = false,
    this.help,
    this.hint,
    this.section,
    this.empty = 'Nothing available',
    this.when,
    this.whenIs,
    this.show = false,
  });

  const F.header(String title)
      : custom = false,
        k = '',
        l = title,
        type = 'header',
        options = const [],
        def = '',
        req = false,
        full = true,
        calc = false,
        help = null,
        hint = null,
        section = null,
        empty = '',
        when = null,
        whenIs = null,
        show = false;

  const F.calc(String key, String label, {String def = '0', bool full = false})
      : custom = false,
        k = key,
        l = label,
        type = 'readonly',
        options = const [],
        def = def,
        req = false,
        full = full,
        calc = true,
        help = null,
        hint = null,
        section = null,
        empty = '',
        when = null,
        whenIs = null,
        show = false;
}

typedef FormVals = Map<String, dynamic>;

/// Opens a form page with the given fields. [onSave] returns true to close the page.
///
/// Status: a form's `status` field is shown at the top. On a new record it is
/// set automatically (read-only, its default value); on an edit form
/// ('Save changes') or when [statusEditable] is true it stays a choice.
/// Forms without a status field can still show one at the top with [status].
/// The last form opened (title, fields, save): lets tests fill a form in and call its save without tapping every field.
({String title, List<F> fields, bool Function(FormVals v, BuildContext ctx) onSave})? debugLastForm;

Future<void> mform(String title, List<F> fields, bool Function(FormVals v, BuildContext ctx) onSave,
    {String btn = 'Save', String icon = 'check', String? intro, String? note, bool disabled = false, ModalSize size = ModalSize.normal,
    String? status, String? statusNote, bool statusEditable = false,
    /// A record page: next-step buttons shown before Save, and extra icons (attachments…) at the top.
    List<Widget> Function(BuildContext ctx)? extra, List<Widget> headerActions = const [], bool cancel = true,
    /// Shows the form exactly as it was filled in, but not changeable: no Save, no Cancel, only [extra].
    bool readOnly = false,
    /// A second button that saves what is typed so far WITHOUT checking the mandatory fields (e.g. "Save changes"
    /// on a draft that is submitted later with the main button).
    String? altBtn, String altIcon = 'edit', void Function(FormVals v, BuildContext ctx)? onAlt}) {
  debugLastForm = (title: title, fields: fields, onSave: onSave);
  final key = GlobalKey<_MFormState>();
  var list = fields;
  String? auto = status;
  final si = fields.indexWhere((f) => f.k == 'status' && f.type == 'select');
  if (si >= 0) {
    final sf = fields[si];
    final rest = [...fields]..removeAt(si);
    if (statusEditable || btn == 'Save changes' || btn == 'Save status') {
      // a real choice: move it to the top, right under the first section title
      final at = rest.isNotEmpty && rest.first.type == 'header' ? 1 : 0;
      rest.insert(at, F(sf.k, sf.l, type: 'select', req: true, def: sf.def, options: sf.options, full: false));
    } else {
      auto = sf.options.any((o) => o.value == sf.def) ? sf.def : (sf.options.isEmpty ? 'Active' : sf.options.first.value);
    }
    list = rest;
  }
  return openFormPage(
    title,
    readOnly
        ? IgnorePointer(child: _MForm(key: key, fields: list, intro: intro, note: note, autoStatus: auto, statusNote: statusNote, readOnly: true))
        : _MForm(key: key, fields: list, intro: intro, note: note, autoStatus: auto, statusNote: statusNote, manual: title.startsWith('New ') && !title.contains(' · ')),
    subtitle: readOnly ? 'This document is no longer changeable · the next step is the button at the bottom' : null,
    headerActions: headerActions,
    actions: (ctx) => [
      if (cancel && !readOnly) Btn.secondary('Cancel', onTap: () => Navigator.of(ctx).pop()),
      ...?extra?.call(ctx),
      if (altBtn != null && onAlt != null && !readOnly)
        Btn.secondary(altBtn, icon: altIcon, onTap: () => onAlt(key.currentState!.rawValues(), ctx)),
      if (!disabled && !readOnly)
        Btn(btn, icon: icon, onTap: () {
          final st = key.currentState!;
          final v = st.collect();
          if (v == null) return;
          if (_saves(onSave, v, ctx)) Navigator.of(ctx).pop();
        }),
    ],
  );
}

/// A short form shown as a small pop-up card (instead of a full page), for one or two quick fields.
Future<void> mdialog(String title, List<F> fields, bool Function(FormVals v, BuildContext ctx) onSave, {String btn = 'Save', String icon = 'check', String? note}) {
  final key = GlobalKey<_MFormState>();
  return openModal(
    title,
    _MForm(key: key, fields: fields, note: note),
    size: ModalSize.narrow,
    actions: (ctx) => [
      Btn.secondary('Cancel', onTap: () => Navigator.of(ctx).pop()),
      Btn(btn, icon: icon, onTap: () {
        final v = key.currentState!.collect();
        if (v == null) return;
        if (_saves(onSave, v, ctx)) Navigator.of(ctx).pop();
      }),
    ],
  );
}

/// Runs a form's save. If it throws, the person sees a message and the form stays open (a silent failure looks like a stuck button).
bool _saves(bool Function(FormVals v, BuildContext ctx) onSave, FormVals v, BuildContext ctx) {
  try {
    return onSave(v, ctx);
  } catch (e, st) {
    debugPrint('Save failed: $e $st');
    toast('Could not save: ${e.toString().split(RegExp(r'[\r\n]')).first}');
    return false;
  }
}

class _MForm extends StatefulWidget {
  final List<F> fields;
  final String? intro, note, autoStatus, statusNote;
  /// Shown as filled in, not changeable (no "Mandatory fields" hint).
  final bool readOnly;
  /// A "New …" form (not one made from another record, whose title has " · "): only what the system decides (number, date, status, currency, company / branch / warehouse) starts filled in;
  /// everything a person decides starts empty and is chosen or typed by hand.
  final bool manual;
  const _MForm({super.key, required this.fields, this.intro, this.note, this.autoStatus, this.statusNote, this.readOnly = false, this.manual = false});
  @override
  State<_MForm> createState() => _MFormState();
}

class _MFormState extends State<_MForm> {
  final Map<String, TextEditingController> ctl = {};
  final Map<String, String> sel = {};
  final Map<String, Set<String>> checks = {};
  final Set<String> bad = {};
  static const _other = '__other__';
  final Map<String, TextEditingController> otherCtl = {};
  /// Country code chosen for each phone field (the number itself is in [ctl]).
  final Map<String, String> cc = {};

  /// Every plain text field called "phone" gets a country-code picker.
  static bool _isPhone(F f) => f.k == 'phone' && f.type == 'text';

  /// Whether a field may start with its default value. Everything does on an edit / action form; on a "New …" form only
  /// values the system decides itself do.
  bool _starts(F f) =>
      !widget.manual ||
      f.calc ||
      f.type == 'readonly' ||
      f.type == 'date' ||
      const {'status', 'currency', 'co', 'company', 'branch', 'wh', 'country'}.contains(f.k);

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      if (f.type == 'header') continue;
      if (f.type == 'select') {
        sel[f.k] = !_starts(f) ? '' : f.options.any((o) => o.value == f.def) ? f.def : (f.options.isEmpty ? '' : f.options.first.value);
        if (f.custom) otherCtl[f.k] = TextEditingController();
      } else if (f.type == 'checks') {
        checks[f.k] = f.options.where((o) => o.checked).map((o) => o.value).toSet();
      } else if (_isPhone(f)) {
        final def = _starts(f) ? f.def : '';
        final m = RegExp(r'^\s*(\+\d{1,4})\s*(.*)$').firstMatch(def);
        cc[f.k] = m?.group(1) ?? '+91';
        ctl[f.k] = TextEditingController(text: m != null ? m.group(2)! : def.trim());
      } else {
        ctl[f.k] = TextEditingController(text: _starts(f) ? f.def : '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in [...ctl.values, ...otherCtl.values]) {
      c.dispose();
    }
    super.dispose();
  }

  /// What is typed right now, with no checking: empty number fields come back null, empty text ''.
  FormVals rawValues() {
    final v = <String, dynamic>{};
    for (final f in widget.fields) {
      if (f.type == 'header') continue;
      if (f.type == 'select') {
        v[f.k] = f.custom && sel[f.k] == _other ? (otherCtl[f.k]?.text.trim() ?? '') : (sel[f.k] ?? '');
      } else if (f.type == 'checks') {
        v[f.k] = checks[f.k]!.toList();
      } else {
        final t = ctl[f.k]!.text.trim();
        v[f.k] = _isPhone(f) ? (t.isEmpty ? '' : '${cc[f.k] ?? '+91'} $t') : f.type == 'number' ? (t.isEmpty ? null : num.tryParse(t)) : t;
      }
    }
    return v;
  }

  FormVals? collect() {
    final v = <String, dynamic>{};
    bad.clear();
    F? first;
    String? customError;

    for (final f in widget.fields) {
      if (f.type == 'header') continue;
      if (f.type == 'select') {
        v[f.k] = f.custom && sel[f.k] == _other ? (otherCtl[f.k]?.text.trim() ?? '') : (sel[f.k] ?? '');
        if (f.custom && sel[f.k] == _other && v[f.k] == '') {
          bad.add(f.k);
          first ??= f;
        }
      } else if (f.type == 'checks') {
        v[f.k] = checks[f.k]!.toList();
        if (f.req && checks[f.k]!.isEmpty) {
          bad.add(f.k);
          first ??= f;
        }
        continue;
      } else {
        final t = ctl[f.k]!.text.trim();
        v[f.k] = _isPhone(f) ? (t.isEmpty ? '' : '${cc[f.k] ?? '+91'} $t') : f.type == 'number' ? (t.isEmpty ? null : num.tryParse(t)) : t;
        if (f.type == 'email' && t.isNotEmpty && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(t)) {
          bad.add(f.k);
          first ??= f;
          customError ??= 'Invalid email format in ${f.l}';
        }
        if (f.type == 'number' && v[f.k] != null && (v[f.k] as num) < 0 && !f.k.contains('adj')) {
          bad.add(f.k);
          first ??= f;
          customError ??= '${f.l} cannot be negative';
        }
      }
      if ((f.req || (_condOn(f) && !f.show)) && (v[f.k] == null || v[f.k] == '')) {
        bad.add(f.k);
        first ??= f;
      }
    }

    // Email or Phone: at least one (forms that list both as optional)
    final emailF = widget.fields.where((f) => f.k == 'email' && !f.req);
    final phoneF = widget.fields.where((f) => f.k == 'phone' && !f.req);
    if (emailF.isNotEmpty && phoneF.isNotEmpty) {
      final noEmail = (v['email'] ?? '').toString().trim().isEmpty;
      final noPhone = (v['phone'] ?? '').toString().replaceAll('+91', '').trim().isEmpty;
      if (noEmail && noPhone) {
        bad.addAll(['email', 'phone']);
        customError ??= 'Enter at least one: Email or Phone';
      }
    }

    // Validate date order if from_date and to_date present
    if (v.containsKey('from_date') && v.containsKey('to_date') && v['from_date'] != null && v['to_date'] != null) {
      if ((v['to_date'] as String).compareTo(v['from_date'] as String) < 0) {
        customError ??= 'End date must be greater than or equal to start date';
        bad.add('to_date');
      }
    }
    if (v.containsKey('start_date') && v.containsKey('end_date') && v['start_date'] != null && v['end_date'] != null) {
      if ((v['end_date'] as String).compareTo(v['start_date'] as String) < 0) {
        customError ??= 'End date must be greater than or equal to start date';
        bad.add('end_date');
      }
    }

    // Validate From <> To warehouse
    if (v.containsKey('from_wh') && v.containsKey('to_wh') && v['from_wh'] == v['to_wh'] && v['from_wh'].toString().isNotEmpty) {
      customError ??= 'From Warehouse and To Warehouse must differ';
      bad.add('to_wh');
    }
    if (v.containsKey('from') && v.containsKey('to') && v['from'] == v['to'] && v['from'].toString().isNotEmpty) {
      customError ??= 'From Warehouse and To Warehouse must differ';
      bad.add('to');
    }

    // Validate Reason mandatory when status is Lost / Rejected / Unqualified / On Hold
    final statusVal = (v['status'] ?? v['stage'] ?? '').toString();
    if (['Lost', 'Rejected', 'Unqualified', 'On Hold'].contains(statusVal)) {
      final reasonKey = v.containsKey('reason') ? 'reason' : (v.containsKey('unqualified_reason') ? 'unqualified_reason' : (v.containsKey('lost_reason') ? 'lost_reason' : 'hold_reason'));
      if (v.containsKey(reasonKey) && (v[reasonKey] == null || v[reasonKey].toString().trim().isEmpty)) {
        bad.add(reasonKey);
        customError ??= 'Reason is mandatory when status is $statusVal';
      }
    }

    if (widget.autoStatus != null) v['status'] = widget.autoStatus;
    setState(() {});
    if (customError != null) {
      toast(customError);
      return null;
    }
    if (first != null) {
      toast('Please fill in: ${first.l}');
      return null;
    }
    return v;
  }

  void markBad(String k) => setState(() => bad.add(k));

  /// The person changed a field that was marked red: the red goes away at once (not only when saving again).
  /// Email and phone are one rule ("at least one"), so typing in either clears both.
  void _fixed(String k) {
    final pair = k == 'email' || k == 'phone';
    if (!bad.contains(k) && !(pair && (bad.contains('email') || bad.contains('phone')))) return;
    setState(() {
      bad.remove(k);
      if (pair) {
        bad.remove('email');
        bad.remove('phone');
      }
    });
  }

  bool _condOn(F f) => f.when != null && ((f.whenIs ?? '').startsWith('!') ? sel[f.when] != f.whenIs!.substring(1) : sel[f.when] == f.whenIs);

  Widget _label(F f) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: f.l),
          if (f.req || (_condOn(f) && !f.show)) const TextSpan(text: ' *', style: TextStyle(color: C.red)),
          if (f.calc) const TextSpan(text: ' (Auto-filled)', style: TextStyle(color: C.blue600, fontSize: 11)),
        ]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft)),
      );

  Widget _control(F f) {
    final isBad = bad.contains(f.k);
    if (f.calc || f.type == 'readonly') {
      return InputDecorator(
        decoration: const InputDecoration(),
        child: Text(ctl[f.k]?.text ?? f.def, style: TextStyle(fontSize: 13, color: widget.readOnly ? C.text : C.soft)),
      );
    }
    if (_isPhone(f)) {
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 82,
          child: ProtoSelect(
            value: cc[f.k] ?? '+91',
            searchable: true,
            options: [for (final c in kCountryCodes) SelOpt(c.$1, c.$1)],
            onChanged: (x) => setState(() => cc[f.k] = x),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ctl[f.k],
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
            onChanged: (_) => _fixed(f.k),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13), hintText: f.hint ?? 'Mobile number', errorText: bad.contains(f.k) ? '' : null, errorStyle: const TextStyle(height: 0, fontSize: 0)),
          ),
        ),
      ]);
    }
    switch (f.type) {
      case 'select':
        final select = ProtoSelect(
          placeholder: 'Select ${f.l.toLowerCase()}',
          value: sel[f.k] ?? '',
          error: isBad && sel[f.k] != _other,
          options: [...f.options.map((o) => SelOpt(o.value, o.label)), if (f.custom) const SelOpt(_other, 'Other (type your own)')],
          onChanged: (x) => setState(() {
            sel[f.k] = x;
            bad.remove(f.k);
          }),
        );
        if (!f.custom || sel[f.k] != _other) return select;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          select,
          const SizedBox(height: 8),
          TextField(
            controller: otherCtl[f.k],
            autofocus: true,
            onChanged: (_) => _fixed(f.k),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13), hintText: 'Type your own ${f.l.toLowerCase()}', errorText: isBad ? '' : null, errorStyle: const TextStyle(height: 0, fontSize: 0)),
          ),
        ]);
      case 'checks':
        return Container(
          constraints: const BoxConstraints(maxHeight: 210),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(R.sm), border: Border.all(color: isBad ? C.red : C.border)),
          child: f.options.isEmpty
              ? Padding(padding: const EdgeInsets.all(12), child: Text(f.empty, style: const TextStyle(fontSize: 12.5, color: C.faint)))
              : ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4), children: [
                  for (final o in f.options)
                    InkWell(
                      onTap: () => setState(() {
                        checks[f.k]!.contains(o.value) ? checks[f.k]!.remove(o.value) : checks[f.k]!.add(o.value);
                        bad.remove(f.k);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(children: [
                          Checkbox(value: checks[f.k]!.contains(o.value), onChanged: (on) => setState(() {
                            on == true ? checks[f.k]!.add(o.value) : checks[f.k]!.remove(o.value);
                            bad.remove(f.k);
                          })),
                          Expanded(child: Text(o.label, style: const TextStyle(fontSize: 12.5))),
                        ]),
                      ),
                    ),
                ]),
        );
      case 'date':
        return TextField(
          controller: ctl[f.k],
          readOnly: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13), suffixIconConstraints: const BoxConstraints(minHeight: 18, minWidth: 36), suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16), errorText: isBad ? '' : null, errorStyle: const TextStyle(height: 0, fontSize: 0)),
          onTap: () async {
            final init = DateTime.tryParse(ctl[f.k]!.text) ?? DateTime(2026, 10, 6);
            final d = await pickDateClean(context, init);
            if (d != null) {
              ctl[f.k]!.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              _fixed(f.k);
            }
          },
        );
      default:
        return TextField(
          controller: ctl[f.k],
          minLines: f.type == 'textarea' ? 3 : null,
          maxLines: f.type == 'textarea' ? null : 1,
          obscureText: f.type == 'password',
          onChanged: (_) => _fixed(f.k),
          keyboardType: f.type == 'number' ? const TextInputType.numberWithOptions(decimal: true, signed: true) : f.type == 'email' ? TextInputType.emailAddress : f.type == 'textarea' ? TextInputType.multiline : TextInputType.text,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13), hintText: f.hint, errorText: isBad ? '' : null, errorStyle: const TextStyle(height: 0, fontSize: 0)),
        );
    }
  }

  /// Every field of the form is shown, mandatory (*) and optional alike, so the create form and the edit
  /// form of a record have the same fields. Only a field that depends on another choice appears when that
  /// choice is made: a reason when the status needs one, a bank reference unless the payment is cash.
  bool _visible(F f) {
    if (f.when != null) return _condOn(f);
    // a mandatory field is always on the form (e.g. the reason on Reject / Cancel)
    if (f.req) return true;
    final status = sel['status'] ?? sel['stage'] ?? '';
    // optional reason fields appear only when the chosen status needs them
    if (const ['reason', 'unqualified_reason', 'lost_reason', 'hold_reason'].contains(f.k)) {
      return const ['Lost', 'Rejected', 'Unqualified', 'On Hold'].contains(status);
    }
    if (f.k == 'utr') return (sel['mode'] ?? '') != 'Cash'; // reference needed unless paid in cash
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // safety check while developing / testing: a form must never hide one of its mandatory fields
    assert(() {
      final hidden = widget.fields.where((f) => f.type != 'header' && f.req && f.when == null && !_visible(f)).map((f) => f.l).toList();
      if (hidden.isNotEmpty) throw FlutterError('Mandatory field(s) hidden on the form: ${hidden.join(', ')}');
      return true;
    }());
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
        final two = c.maxWidth >= 480;
        final half = two ? (c.maxWidth - 18) / 2 : c.maxWidth;
        // drop section headers that have no visible field under them
        final shown = <F>[];
        for (var i = 0; i < widget.fields.length; i++) {
          final f = widget.fields[i];
          if (f.type == 'header') {
            var any = false;
            for (var j = i + 1; j < widget.fields.length && widget.fields[j].type != 'header'; j++) {
              if (_visible(widget.fields[j])) any = true;
            }
            if (any) shown.add(f);
          } else if (_visible(f)) {
            shown.add(f);
          }
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.autoStatus != null) FormStatusBar(widget.autoStatus!, widget.statusNote ?? 'Set automatically when you save.'),
          if (!widget.readOnly)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('* Mandatory fields', style: TextStyle(fontSize: 11.5, color: C.faint, fontStyle: FontStyle.italic)),
            ),
          if (widget.intro != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.intro!, style: const TextStyle(fontSize: 12.5, color: C.soft))),
          Wrap(spacing: 18, runSpacing: 16, children: [
            for (final f in shown)
              if (f.type == 'header')
                SizedBox(
                  width: c.maxWidth,
                  child: Padding(
                    padding: EdgeInsets.only(top: f == shown.first ? 0 : 10),
                    child: Text(f.l, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
                  ),
                )
              else
                SizedBox(
                  width: (f.full || f.type == 'checks' || f.type == 'textarea') ? c.maxWidth : half,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label(f),
                    _control(f),
                    if (f.help != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(f.help!, style: const TextStyle(fontSize: 11, color: C.faint))),
                  ]),
                ),
          ]),
          if (widget.note != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(widget.note!, style: const TextStyle(fontSize: 12, color: C.faint))),
        ]);
      });
}



/// Clean, compact date picker used by every date field.
/// Tap a day to choose it (no OK step); "Today" jumps to today.
Future<DateTime?> pickDateClean(BuildContext context, DateTime initial) {
  final first = DateTime(2020), last = DateTime(2035, 12, 31);
  final init = initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial);
  return showDialog<DateTime>(
    context: context,
    barrierColor: const Color(0x40141B2D),
    builder: (ctx) {
      final w = math.min(MediaQuery.sizeOf(ctx).width - 32, 340.0);
      final theme = Theme.of(ctx);
      return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: w,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Text('Select date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
            ),
            Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(primary: C.blue600, onPrimary: Colors.white, surface: Colors.white, onSurface: C.text),
                datePickerTheme: DatePickerThemeData(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  dayStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  weekdayStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.faint),
                  todayBorder: const BorderSide(color: C.blue600),
                  dayShape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
              child: SizedBox(
                height: 330,
                child: CalendarDatePicker(
                  initialDate: init,
                  firstDate: first,
                  lastDate: last,
                  currentDate: DateTime.tryParse(todayStr()),
                  onDateChanged: (d) => Navigator.of(ctx).pop(d),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(DateTime.tryParse(todayStr()) ?? DateTime.now()), child: const Text('Today', style: TextStyle(fontWeight: FontWeight.w600, color: C.blue600))),
                const Spacer(),
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(color: C.soft))),
              ]),
            ),
          ]),
        ),
      );
    },
  );
}
