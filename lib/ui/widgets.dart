import 'package:flutter/material.dart';
import '../core/format.dart';
import 'tokens.dart';

// ---------------------------------------------------------------- responsive
double screenW(BuildContext c) => MediaQuery.sizeOf(c).width;
bool isMobile(BuildContext c) => screenW(c) < 760;
bool isDesktop(BuildContext c) => screenW(c) >= 1100;

const tsTitle = TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: C.text, letterSpacing: -.2);
const tsSub = TextStyle(fontSize: 13, color: C.soft);
const tsFaint = TextStyle(fontSize: 11.5, color: C.faint);
const tsB = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.text); // <b>
const tsB6 = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text); // .cell-two b
const tsBody = TextStyle(fontSize: 13, color: C.text);

// ---------------------------------------------------------------- buttons
enum BtnKind { primary, secondary, ghost, danger }

class Btn extends StatelessWidget {
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool small;
  const Btn(this.label, {super.key, this.icon, this.onTap, this.kind = BtnKind.primary, this.small = false});
  const Btn.secondary(this.label, {super.key, this.icon, this.onTap, this.small = false}) : kind = BtnKind.secondary;
  const Btn.ghost(this.label, {super.key, this.icon, this.onTap, this.small = false}) : kind = BtnKind.ghost;
  const Btn.danger(this.label, {super.key, this.icon, this.onTap, this.small = false}) : kind = BtnKind.danger;

  @override
  Widget build(BuildContext context) {
    Color bg, fg, bd;
    switch (kind) {
      case BtnKind.primary:
        bg = C.blue600;
        fg = Colors.white;
        bd = C.blue600;
        break;
      case BtnKind.secondary:
        bg = C.card;
        fg = C.text;
        bd = C.border;
        break;
      case BtnKind.ghost:
        bg = Colors.transparent;
        fg = C.soft;
        bd = Colors.transparent;
        break;
      case BtnKind.danger:
        bg = C.redBg;
        fg = C.red;
        bd = C.redBg;
        break;
    }
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? .5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 7 : 9), side: BorderSide(color: bd)),
        child: InkWell(
          borderRadius: BorderRadius.circular(small ? 7 : 9),
          onTap: onTap,
          child: Padding(
            padding: small ? const EdgeInsets.symmetric(horizontal: 11, vertical: 6) : const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(ic(icon!), size: small ? 14 : 15, color: fg), const SizedBox(width: 7)],
              // wraps instead of overflowing when the screen is narrow
              Flexible(child: Text(label, style: TextStyle(fontSize: small ? 12.3 : 13, fontWeight: FontWeight.w600, color: fg))),
            ]),
          ),
        ),
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final bool dot;
  final String? tip;
  final Color? color;
  final double size;
  const IconBtn(this.icon, this.onTap, {super.key, this.dot = false, this.tip, this.color, this.size = 36});
  @override
  Widget build(BuildContext context) {
    final w = Material(
      color: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: C.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            Icon(ic(icon), size: 18, color: color ?? C.soft),
            if (dot)
              Positioned(
                top: 7,
                right: 7,
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: C.red, shape: BoxShape.circle, border: Border.all(color: C.card, width: 1.5))),
              ),
          ]),
        ),
      ),
    );
    return tip == null ? w : Tooltip(message: tip!, child: w);
  }
}

// ---------------------------------------------------------------- badges & chips
Tone toneFor(String status) {
  const green = ['Active', 'Approved', 'Completed', 'Received', 'Delivered', 'Paid', 'Posted', 'Bin Allocated', 'QC Checked', 'Accepted', 'Allocated', 'Released', 'In stock', 'Credited', 'Awarded', 'Ordered', 'Issued', 'Returned', 'OK', 'Won', 'Done', 'Available', 'Matched', 'Verified', 'Sent '];
  const teal = ['Picked', 'Packed'];
  const amber = ['Received from Supplier', 'Awaiting Goods Receipt', 'Pending Approval', 'Pending', 'QC Pending', 'QC Requested', 'Submitted', 'Partially Paid', 'Partially Received', 'Expiring Soon', 'Quotes Received', 'Requested', 'Counting', 'To Do', 'To Pick', 'Packing', 'Ready to Dispatch', 'Loading', 'On Probation', 'Low', 'Unpaid', 'Negotiation', 'Open', 'Under review', 'Today', 'Contacted'];
  const blue = ['Sent', 'Sent to Supplier', 'Confirmed', 'Picking', 'Dispatched', 'In Transit', 'Picked Up', 'RFQ Sent', 'Awaiting Quotes', 'Reserved', 'Proposal', 'Assigned', 'Tomorrow', 'Current'];
  const purple = ['Invoiced', 'Out for Delivery', 'On Route'];
  const red = ['On Hold', 'Credit Hold', 'Overdue', 'Rejected', 'Quarantine', 'Expired', 'Below reorder', 'Lost', 'Late', 'Cancelled', 'Variance', 'Price Difference', 'Missing key'];
  if (green.contains(status)) return Tone.green;
  if (teal.contains(status)) return Tone.teal;
  if (amber.contains(status)) return Tone.amber;
  if (blue.contains(status)) return Tone.blue;
  if (purple.contains(status)) return Tone.purple;
  if (red.contains(status)) return Tone.red;
  return Tone.gray;
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Tone? tone;
  final bool dot;
  const StatusBadge(this.text, {super.key, this.tone, this.dot = true});
  @override
  Widget build(BuildContext context) {
    final t = tone ?? toneFor(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: t.fg, shape: BoxShape.circle)), const SizedBox(width: 5)],
        // long statuses shrink with an ellipsis instead of overflowing on phones
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.3, fontWeight: FontWeight.w700, color: t.fg))),
      ]),
    );
  }
}

class AutoTag extends StatelessWidget {
  final String mode; // AUTO / SEMI / MANUAL
  const AutoTag(this.mode, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = mode == 'AUTO' ? Tone.green : mode == 'SEMI' ? Tone.blue : Tone.gray;
    return StatusBadge(mode == 'AUTO' ? 'Automatic' : mode == 'SEMI' ? 'Semi-automatic' : 'Manual', tone: t);
  }
}

class Tag extends StatelessWidget {
  final String text;
  final String? icon;
  final VoidCallback? onTap;
  const Tag(this.text, {super.key, this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    final w = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: C.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(ic(icon!), size: 13, color: C.soft), const SizedBox(width: 4)],
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: C.soft))),
      ]),
    );
    return onTap == null ? w : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(7), child: w);
  }
}

// ---------------------------------------------------------------- containers
class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18), this.onTap});
  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(R.r), border: Border.all(color: C.border), boxShadow: kShadow),
      child: child,
    );
    if (onTap == null) return box;
    return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: box));
  }
}

class CardHead extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget? leading;
  const CardHead(this.title, {super.key, this.hint, this.leading});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
        child: LayoutBuilder(
          builder: (ctx, c) => Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
            // the hint stays on the right and shortens with … on narrow screens
            if (hint != null) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth * .55),
                child: Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: C.faint)),
              ),
            ],
          ]),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final bool first;
  const SectionTitle(this.text, {super.key, this.first = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 24, bottom: 12),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? sub;
  final List<Widget> actions;
  const PageHeader(this.title, {super.key, this.sub, this.actions = const []});
  @override
  Widget build(BuildContext context) {
    final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: isMobile(context) ? tsTitle.copyWith(fontSize: 19) : tsTitle),
      if (sub != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub!, style: tsSub)),
    ]);
    final acts = Wrap(spacing: 8, runSpacing: 8, children: actions);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: isMobile(context) || actions.isEmpty
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head, if (actions.isNotEmpty) ...[const SizedBox(height: 12), acts]])
          // many header buttons wrap onto a second line instead of running off the edge
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: head),
              const SizedBox(width: 16),
              Flexible(flex: 2, child: Align(alignment: Alignment.topRight, child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions))),
            ]),
    );
  }
}

// ---------------------------------------------------------------- grids
/// Responsive grid: picks a column count from the available width.
class RGrid extends StatelessWidget {
  final List<Widget> children;
  final int max;
  final double minTile;
  final double gap;
  const RGrid({super.key, required this.children, this.max = 4, this.minTile = 220, this.gap = 16});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
        int cols = (c.maxWidth / minTile).floor();
        if (cols < 1) cols = 1;
        if (cols > max) cols = max;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: children.map((e) => SizedBox(width: w, child: e)).toList());
      });
}

class Stat {
  final String label, value, trend, icon;
  final bool up;
  final Tone tone;
  final VoidCallback? onTap;
  Stat(this.label, this.value, this.trend, this.icon, this.tone, {this.up = true, this.onTap});
}

class StatCard extends StatelessWidget {
  final Stat s;
  final bool compact;
  const StatCard(this.s, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) => compact ? _small() : CardBox(
        onTap: s.onTap,
        padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: s.tone.bg, borderRadius: BorderRadius.circular(10)), child: Icon(ic(s.icon), size: 18, color: s.tone.fg)),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: s.up ? C.greenBg : C.redBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(s.trend, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: s.up ? C.green : C.red)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(s.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.2, height: 1.25, color: C.text))),
          const SizedBox(height: 2),
          Text(s.label, style: const TextStyle(fontSize: 12.5, color: C.soft)),
        ]),
      );
}

extension on StatCard {
  // Small, minimal card: icon + badge on one line, value and label below.
  Widget _small() => CardBox(
        onTap: s.onTap,
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: s.tone.bg, borderRadius: BorderRadius.circular(8)), child: Icon(ic(s.icon), size: 15, color: s.tone.fg)),
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: s.up ? C.greenBg : C.redBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(s.trend, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: s.up ? C.green : C.red)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 9),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(s.value, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.2, color: C.text))),
          const SizedBox(height: 1),
          Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.soft)),
        ]),
      );
}

class StatRow extends StatelessWidget {
  final List<Stat> stats;
  final int max;
  final bool compact;
  const StatRow(this.stats, {super.key, this.max = 6, this.compact = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: RGrid(max: max, minTile: compact ? 150 : (isMobile(context) ? 150 : 175), gap: compact ? 12 : 16, children: stats.map((s) => StatCard(s, compact: compact)).toList()),
      );
}

class ModCard extends StatelessWidget {
  final String icon, title;
  final Tone tone;
  final List<String> list;
  final VoidCallback onTap;
  const ModCard(this.icon, this.title, this.tone, this.list, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => CardBox(
        onTap: onTap,
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(10)), child: Icon(ic(icon), size: 19, color: tone.fg)),
          const SizedBox(height: 11),
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...list.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: C.faint, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l, style: const TextStyle(fontSize: 12, color: C.soft))),
                ]),
              )),
        ]),
      );
}

class FlowChips extends StatelessWidget {
  final String title, note;
  final List<String> flow;
  final int hi;
  const FlowChips(this.title, this.flow, this.hi, this.note, {super.key});
  @override
  Widget build(BuildContext context) => CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (var i = 0; i < flow.length; i++) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: i == hi ? C.blue600 : C.bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: i == hi ? C.blue600 : C.border)),
                child: Text(flow[i], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: i == hi ? Colors.white : C.soft)),
              ),
              if (i < flow.length - 1) const Text('→', style: TextStyle(color: C.faint)),
            ]
          ]),
          const SizedBox(height: 8),
          Text(note, style: const TextStyle(fontSize: 12, color: C.faint)),
        ]),
      );
}

// ---------------------------------------------------------------- small pieces
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final bool strong;
  const Avatar(this.name, {super.key, this.size = 34, this.strong = false});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: strong ? C.blue500 : C.blue100, shape: BoxShape.circle),
        child: Text(initials(name), style: TextStyle(fontSize: size * .35, fontWeight: FontWeight.w700, color: strong ? Colors.white : C.blue600)),
      );
}

class CellTwo extends StatelessWidget {
  final String title, sub;
  const CellTwo(this.title, this.sub, {super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: tsB6),
        if (sub.isNotEmpty) Text(sub, style: tsFaint),
      ]);
}

class CellAv extends StatelessWidget {
  final String name, sub;
  const CellAv(this.name, this.sub, {super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Avatar(name),
        const SizedBox(width: 10),
        Flexible(child: CellTwo(name, sub)),
      ]);
}

class Bar extends StatelessWidget {
  final double pct; // 0..100
  final Color? color;
  final double? width;
  const Bar(this.pct, {super.key, this.color, this.width});
  @override
  Widget build(BuildContext context) {
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1).toDouble(), minHeight: 7, backgroundColor: C.bg, color: color ?? C.blue600),
    );
    return width == null ? bar : SizedBox(width: width, child: bar);
  }
}

class BarPct extends StatelessWidget {
  final double pct;
  final Color? color;
  const BarPct(this.pct, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Bar(pct, color: color, width: 90),
        const SizedBox(width: 8),
        Text('${pct.round()}%', style: tsBody),
      ]);
}

class NoteBox extends StatelessWidget {
  final Tone tone;
  final String icon;
  final String bold, text;
  const NoteBox(this.tone, this.icon, this.bold, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(R.sm), border: Border.all(color: C.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic(icon), size: 16, color: tone.fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(children: [
              if (bold.isNotEmpty) TextSpan(text: '$bold ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: text),
            ]), style: const TextStyle(fontSize: 12.5, color: C.text)),
          ),
        ]),
      );
}

class Kv {
  final String label;
  final Widget value;
  /// Spans the whole row in a [KvForm] (long text such as a reason).
  final bool full;
  Kv(this.label, this.value, {this.full = false});
  Kv.t(this.label, String v, {this.full = false}) : value = Text(v, style: const TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600));
}

class KvGrid extends StatelessWidget {
  final List<Kv> items;
  const KvGrid(this.items, {super.key});
  /// Read-only details laid out like a printed document: label on the left, value on the
  /// right, a thin line under each row; two columns on wide screens, one on phones.
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
        final cols = c.maxWidth < 560 ? 1 : 2;
        final gap = cols == 1 ? 0.0 : 36.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        final labelW = w < 320 ? 112.0 : 150.0;
        return Wrap(
          spacing: gap,
          children: items
              .map((k) => Container(
                    width: w,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: labelW, child: Text(k.label, style: const TextStyle(fontSize: 12.5, color: C.faint))),
                      const SizedBox(width: 10),
                      Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: C.text), child: k.value)),
                    ]),
                  ))
              .toList(),
        );
      });
}

/// Read-only details laid out exactly like a data-entry form: a section bar, then each
/// field as a label above a bordered box, two columns on wide screens.
class KvForm extends StatelessWidget {
  final String section;
  final List<Kv> items;
  const KvForm(this.section, this.items, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
        final half = c.maxWidth >= 480 ? (c.maxWidth - 18) / 2 : c.maxWidth;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(section, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 14),
          Wrap(spacing: 18, runSpacing: 16, children: [
            for (final k in items)
              SizedBox(
                width: k.full ? c.maxWidth : half,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(k.label, style: const TextStyle(fontSize: 12.5, color: C.soft))),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(R.sm), border: Border.all(color: C.border)),
                    child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13.2, fontWeight: FontWeight.w500, color: C.text), child: k.value),
                  ),
                ]),
              ),
          ]),
        ]);
      });
}

/// A record shown like a form: its parts one under another, no tabs.
/// Attachments open from the pin at the top of the page, so they are not repeated here.
class RecordBody extends StatelessWidget {
  final List<TabDef> parts;
  const RecordBody(this.parts, {super.key});
  @override
  Widget build(BuildContext context) {
    final shown = parts.where((p) => p.label != 'Attachments' && p.label != 'History').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Text(shown[i].label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        shown[i].build(),
      ],
    ]);
  }
}

class ActivityRow extends StatelessWidget {
  final String icon, title, sub;
  final Tone tone;
  final Widget? trailing;
  final VoidCallback? onTap;
  const ActivityRow(this.icon, this.title, this.sub, {super.key, this.tone = Tone.blue, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    final w = Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(8)), child: Icon(ic(icon), size: 14, color: tone.fg)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12.7, fontWeight: FontWeight.w600)),
            if (sub.isNotEmpty) Text(sub, style: tsFaint),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
    return onTap == null ? w : InkWell(onTap: onTap, child: w);
  }
}

class Empty extends StatelessWidget {
  final String text;
  const Empty(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: C.faint))),
      );
}

class LegendRow extends StatelessWidget {
  final Color color;
  final String label, value;
  const LegendRow(this.color, this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

// ---------------------------------------------------------------- stepper
class StepItem {
  final String title, sub;
  final String state; // done / active / pending
  StepItem(this.title, this.sub, this.state);
}

class VStepper extends StatelessWidget {
  final List<StepItem> steps;
  const VStepper(this.steps, {super.key});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Column(children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: steps[i].state == 'done' ? C.green : steps[i].state == 'active' ? C.blue600 : C.bg,
                      border: steps[i].state == 'pending' ? Border.all(color: C.border, width: 1.5) : null,
                      boxShadow: steps[i].state == 'active' ? const [BoxShadow(color: C.blue50, spreadRadius: 4)] : null,
                    ),
                    child: steps[i].state == 'done'
                        ? const Icon(Icons.check, size: 15, color: Colors.white)
                        : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: steps[i].state == 'active' ? Colors.white : C.faint)),
                  ),
                  if (i < steps.length - 1) Expanded(child: Container(width: 2, color: steps[i].state == 'done' ? C.green : C.border)),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 20 : 0, top: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(steps[i].title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(steps[i].sub, style: tsFaint),
                    ]),
                  ),
                ),
              ]),
            ),
        ],
      );
}

// ---------------------------------------------------------------- tabs
class TabDef {
  final String label;
  final Widget Function() build;
  TabDef(this.label, this.build);
}

class Tabs extends StatefulWidget {
  final List<TabDef> tabs;
  final String? storeKey; // remembers the selected tab across rebuilds
  const Tabs(this.tabs, {super.key, this.storeKey});
  static final Map<String, int> memory = {};
  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  late int idx;
  @override
  void initState() {
    super.initState();
    idx = widget.storeKey != null ? (Tabs.memory[widget.storeKey!] ?? 0) : 0;
    if (idx >= widget.tabs.length) idx = 0;
  }

  @override
  void didUpdateWidget(covariant Tabs old) {
    super.didUpdateWidget(old);
    if (old.storeKey != widget.storeKey || old.tabs.length != widget.tabs.length) {
      idx = widget.storeKey != null ? (Tabs.memory[widget.storeKey!] ?? 0) : 0;
    }
    if (idx >= widget.tabs.length) idx = 0;
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < widget.tabs.length; i++)
                InkWell(
                  onTap: () => setState(() {
                    idx = i;
                    if (widget.storeKey != null) Tabs.memory[widget.storeKey!] = i;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 22),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == idx ? C.blue600 : Colors.transparent, width: 2.5))),
                    child: Text(widget.tabs[i].label, style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: i == idx ? C.blue600 : C.faint)),
                  ),
                ),
            ]),
          ),
        ),
        widget.tabs[idx].build(),
      ]);
}
