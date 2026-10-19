import 'package:flutter/material.dart';
import 'tokens.dart';

/// Option for [ProtoSelect].
class SelOpt {
  final String value, label;
  const SelOpt(this.value, this.label);
}

/// Look of the closed control.
enum SelKind {
  /// Table filter: `.select-filter` — 1px border, 8px radius, 7×10 padding, 12.6px soft text.
  filter,

  /// Form field: `.field select` — full width, 9×11 padding, 13px text, blue focus ring.
  form,

  /// Top-bar switcher: `.switcher select` — no border, 12.5px semibold.
  bare,
}

/// Extra empty space (px) form and record pages add under their content while a dropdown is open,
/// so the page can scroll far enough for the whole list to show under the field.
final ValueNotifier<double> dropdownRoom = ValueNotifier(0);

/// Placed around the scroll area of form and record pages (the only places that add [dropdownRoom] space).
/// Dropdowns elsewhere, such as table filters, never scroll the page: their list just fits the space below.
class DropdownRoomScope extends InheritedWidget {
  const DropdownRoomScope({super.key, required super.child});
  @override
  bool updateShouldNotify(DropdownRoomScope oldWidget) => false;
}

/// A dropdown: flat box with a small chevron. The list always opens right under
/// the box (never upward), at least as wide as the box, with a search box when
/// the list is long. Tapping anywhere else closes it.
class ProtoSelect extends StatefulWidget {
  final String value;
  final List<SelOpt> options;
  final ValueChanged<String> onChanged;
  final SelKind kind;
  final bool error;
  final double? maxWidth;
  /// Show a search box. By default it appears when there are more than 7 options.
  final bool? searchable;
  /// Shown (faint) while nothing is chosen, instead of the first option.
  final String? placeholder;
  const ProtoSelect({super.key, this.placeholder, required this.value, required this.options, required this.onChanged, this.kind = SelKind.form, this.error = false, this.maxWidth, this.searchable});

  @override
  State<ProtoSelect> createState() => _ProtoSelectState();
}

class _ProtoSelectState extends State<ProtoSelect> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _key = GlobalKey();
  final _search = TextEditingController();
  double _w = 160;
  double _maxH = 320;
  String _q = '';
  bool _open = false;

  bool get _searchable => widget.searchable ?? widget.options.length > 7;

  @override
  void dispose() {
    // never change the notifier while the tree is being torn down
    if (_open) WidgetsBinding.instance.addPostFrameCallback((_) => dropdownRoom.value = 0);
    _search.dispose();
    super.dispose();
  }

  static const _want = 330.0; // list height plus the search box

  bool get _showsPlaceholder => widget.placeholder != null && !widget.options.any((o) => o.value == widget.value);

  String get _label {
    for (final o in widget.options) {
      if (o.value == widget.value) return o.label;
    }
    if (widget.placeholder != null) return widget.placeholder!;
    return widget.options.isEmpty ? '' : widget.options.first.label;
  }

  void _close() {
    if (!_open) return;
    _portal.hide();
    dropdownRoom.value = 0;
    setState(() => _open = false);
  }

  /// Space between the bottom of the closed box and the bottom of the window.
  double _spaceBelow() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _want;
    return MediaQuery.sizeOf(context).height - box.localToGlobal(Offset(0, box.size.height)).dy - 12;
  }

  void _toggle() {
    if (_open) {
      _close();
      return;
    }
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) _w = box.size.width < 220 ? 220 : box.size.width;
    final need = _want - _spaceBelow();
    // only form / record pages make room by scrolling; everywhere else the list simply fits the space below
    final inPage = context.getInheritedWidgetOfExactType<DropdownRoomScope>() != null;
    _maxH = need <= 0 ? _want - 10 : (inPage ? 320 : _spaceBelow().clamp(150.0, 320.0));
    _search.clear();
    _q = '';
    setState(() => _open = true);
    _portal.show();
    if (need > 0 && inPage) {
      // not enough room under the box: let the page grow and scroll up so the whole list fits below it
      dropdownRoom.value = need;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_open) return;
        final sc = Scrollable.maybeOf(context);
        if (sc == null) return;
        final p = sc.position;
        p.animateTo((p.pixels + need).clamp(p.minScrollExtent, p.maxScrollExtent), duration: const Duration(milliseconds: 180), curve: Curves.easeOut).then((_) {
          // where the page cannot scroll any further, shrink the list to what is visible
          final room = _spaceBelow();
          if (mounted && _open && room < _maxH - 8) setState(() => _maxH = room.clamp(150.0, 320.0));
        });
      });
    }
  }

  void _pick(String v) {
    _close();
    widget.onChanged(v);
  }

  Widget _menu(BuildContext context) {
    final k = widget.kind;
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty ? widget.options : widget.options.where((o) => o.label.toLowerCase().contains(q)).toList();
    final fs = k == SelKind.filter ? 12.6 : 13.0;
    return Stack(children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _close)),
      CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 3),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _w,
            child: Material(
              color: Colors.white,
              elevation: 6,
              shadowColor: const Color(0x40141B2D),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFC9CED8))),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _maxH),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_searchable)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: TextField(
                        controller: _search,
                        autofocus: true,
                        style: const TextStyle(fontSize: 13),
                        onChanged: (t) => setState(() => _q = t),
                        onSubmitted: (_) {
                          if (shown.isNotEmpty) _pick(shown.first.value);
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Search…',
                          prefixIcon: Icon(Icons.search, size: 17),
                          prefixIconConstraints: BoxConstraints(minWidth: 34, minHeight: 30),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        ),
                      ),
                    ),
                  Flexible(
                    child: shown.isEmpty
                        ? const Padding(padding: EdgeInsets.all(14), child: Text('No match', style: TextStyle(fontSize: 12.5, color: C.faint)))
                        : ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            children: [
                              for (final o in shown)
                                InkWell(
                                  onTap: () => _pick(o.value),
                                  hoverColor: C.blue50,
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 32),
                                    color: o.value == widget.value ? C.blue50 : null,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    alignment: Alignment.centerLeft,
                                    child: Text(o.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontFamily: 'Lato', fontSize: fs, color: o.value == widget.value ? C.blue600 : C.text, fontWeight: o.value == widget.value ? FontWeight.w600 : FontWeight.w400)),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    final textStyle = TextStyle(
      fontFamily: 'Lato',
      fontSize: k == SelKind.filter ? 12.6 : (k == SelKind.bare ? 12.5 : 13),
      fontWeight: k == SelKind.bare ? FontWeight.w600 : FontWeight.w400,
      color: k == SelKind.filter ? C.soft : C.text,
      height: 1.2,
      letterSpacing: 0,
    );
    final borderColor = widget.error ? C.red : (_open && k == SelKind.form ? C.blue600 : C.border);

    Widget field = Row(mainAxisSize: k == SelKind.form ? MainAxisSize.max : MainAxisSize.min, children: [
      Flexible(
        fit: k == SelKind.form ? FlexFit.tight : FlexFit.loose,
        child: Text(_label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _showsPlaceholder ? textStyle.copyWith(color: C.faint) : textStyle),
      ),
      SizedBox(width: k == SelKind.bare ? 4 : 8),
      Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: k == SelKind.form ? 18 : 16, color: k == SelKind.filter ? C.soft : C.text),
    ]);
    if (widget.maxWidth != null) field = ConstrainedBox(constraints: BoxConstraints(maxWidth: widget.maxWidth!), child: field);

    final closed = Container(
      key: _key,
      width: k == SelKind.form ? double.infinity : null,
      padding: k == SelKind.filter
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : k == SelKind.form
              ? const EdgeInsets.symmetric(horizontal: 11, vertical: 10)
              : const EdgeInsets.symmetric(vertical: 2),
      decoration: k == SelKind.bare
          ? null
          : BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
              boxShadow: _open && k == SelKind.form ? const [BoxShadow(color: C.blue50, spreadRadius: 3)] : null,
            ),
      child: field,
    );

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _menu,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toggle, child: closed),
        ),
      ),
    );
  }
}
