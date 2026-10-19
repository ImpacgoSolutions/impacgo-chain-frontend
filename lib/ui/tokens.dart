import 'package:flutter/material.dart';
import '../core/render_mode_stub.dart' if (dart.library.html) '../core/render_mode_web.dart';

/// Design tokens copied from the IMPACGO prototype CSS (:root variables).
class C {
  static const navy950 = Color(0xFF141B2D);
  static const navy900 = Color(0xFF182234);
  static const navy800 = Color(0xFF1F2B42);
  static const blue600 = Color(0xFF3B6FEF);
  static const blue500 = Color(0xFF4F7BF5);
  static const blue100 = Color(0xFFE4ECFF);
  static const blue50 = Color(0xFFEEF3FF);
  static const bg = Color(0xFFF3F5FA);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6E9F2);
  static const text = Color(0xFF1C2434);
  static const soft = Color(0xFF5B6478);
  static const faint = Color(0xFF8A91A3);
  static const green = Color(0xFF17A673);
  static const greenBg = Color(0xFFE3F8EF);
  static const amber = Color(0xFFE8A325);
  static const amberBg = Color(0xFFFDF1DC);
  static const red = Color(0xFFE6493F);
  static const redBg = Color(0xFFFBE6E4);
  static const purple = Color(0xFF7C5CFC);
  static const purpleBg = Color(0xFFEDE9FF);
  static const teal = Color(0xFF14B8A6);
  static const tealBg = Color(0xFFDCFAF5);
  static const pink = Color(0xFFEC5A9D);
  static const pinkBg = Color(0xFFFCE6F1);
  static const cyan = Color(0xFF0EA5C4);
  static const cyanBg = Color(0xFFDFF4F9);
  static const gray = Color(0xFF6B7385);
  static const grayBg = Color(0xFFEEF0F5);
  // sidebar text
  static const sideText = Color(0xFFAAB1C6);
  static const sideLabel = Color(0xFF6B7690);
  static const sideStrong = Color(0xFFE7EAF3);
}

class R {
  static const r = 12.0;
  static const sm = 8.0;
}

/// A pair of foreground / background colours used by badges, icons and notes.
class Tone {
  final Color fg, bg;
  const Tone(this.fg, this.bg);
  static const blue = Tone(C.blue600, C.blue50);
  static const green = Tone(C.green, C.greenBg);
  static const amber = Tone(C.amber, C.amberBg);
  static const red = Tone(C.red, C.redBg);
  static const purple = Tone(C.purple, C.purpleBg);
  static const teal = Tone(C.teal, C.tealBg);
  static const pink = Tone(C.pink, C.pinkBg);
  static const cyan = Tone(C.cyan, C.cyanBg);
  static const gray = Tone(C.gray, C.grayBg);
}

/// True when the processor draws the screen. Every change on screen then costs a full redraw on the processor,
/// so cosmetic hover highlights (table rows, header buttons) are skipped: moving the mouse draws nothing.
final bool kLightUi = drawingWithProcessor();

/// Card shadow. A large blurred shadow on every card is slow to draw when the processor does the drawing
/// (the safe mode used when the graphics card has shader problems), so that mode keeps only a hairline shadow.
final List<BoxShadow> kShadow = drawingWithProcessor()
    ? const [BoxShadow(color: Color(0x14141B2D), blurRadius: 1, offset: Offset(0, 1))]
    : const [
        BoxShadow(color: Color(0x0A141B2D), blurRadius: 2, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x1A141B2D), blurRadius: 24, spreadRadius: -12, offset: Offset(0, 8)),
      ];

/// Icon names used in the prototype mapped to Material icons.
IconData ic(String n) {
  const m = <String, IconData>{
    'grid': Icons.grid_view_outlined,
    'cart': Icons.shopping_cart_outlined,
    'file': Icons.description_outlined,
    'truck': Icons.local_shipping_outlined,
    'receipt': Icons.receipt_long_outlined,
    'wallet': Icons.account_balance_wallet_outlined,
    'refund': Icons.undo_rounded,
    'clipboard': Icons.assignment_outlined,
    'msg': Icons.chat_bubble_outline,
    'bag': Icons.shopping_bag_outlined,
    'inbox': Icons.inbox_outlined,
    'card': Icons.credit_card,
    'box': Icons.inventory_2_outlined,
    'history': Icons.history,
    'swap': Icons.swap_horiz,
    'sliders': Icons.tune,
    'layers': Icons.layers_outlined,
    'download': Icons.download_outlined,
    'checksq': Icons.fact_check_outlined,
    'package': Icons.all_inbox_outlined,
    'scan': Icons.qr_code_scanner,
    'map': Icons.map_outlined,
    'store': Icons.storefront_outlined,
    'users': Icons.people_outline,
    'tag': Icons.sell_outlined,
    'percent': Icons.percent,
    'home': Icons.warehouse_outlined,
    'bars': Icons.bar_chart_rounded,
    'gear': Icons.settings_outlined,
    'target': Icons.track_changes,
    'trend': Icons.trending_up,
    'contact': Icons.contact_page_outlined,
    'badge': Icons.badge_outlined,
    'move': Icons.open_with,
    'ruler': Icons.straighten,
    'calendar': Icons.calendar_month_outlined,
    'plus': Icons.add,
    'check': Icons.check,
    'x': Icons.close,
    'upload': Icons.upload_outlined,
    'search': Icons.search,
    'bell': Icons.notifications_none,
    'chevdown': Icons.expand_more,
    'menu': Icons.menu,
    'printer': Icons.print_outlined,
    'star': Icons.star_outline,
    'lock': Icons.lock_outline,
    'unlock': Icons.lock_open,
    'alert': Icons.warning_amber_rounded,
    'logout': Icons.logout,
    'eye': Icons.visibility_outlined,
    'edit': Icons.edit_outlined,
    'minus': Icons.remove,
    'play': Icons.play_arrow_rounded,
    'pause': Icons.pause,
    'refresh': Icons.refresh,
    'clock': Icons.schedule,
    'paperclip': Icons.attach_file,
    'trash': Icons.delete_outline,
  };
  return m[n] ?? Icons.circle_outlined;
}

/// Prototype-accurate text: Lato (Segoe UI metrics), no Material letter-spacing, CSS-like line height (1.45).
TextTheme _protoText(TextTheme t) {
  TextStyle? z(TextStyle? x) => x?.copyWith(fontFamily: 'Lato', letterSpacing: 0, height: 1.45, color: C.text);
  return TextTheme(
    displayLarge: z(t.displayLarge), displayMedium: z(t.displayMedium), displaySmall: z(t.displaySmall),
    headlineLarge: z(t.headlineLarge), headlineMedium: z(t.headlineMedium), headlineSmall: z(t.headlineSmall),
    titleLarge: z(t.titleLarge), titleMedium: z(t.titleMedium?.copyWith(fontSize: 14)), titleSmall: z(t.titleSmall?.copyWith(fontSize: 13)),
    bodyLarge: z(t.bodyLarge?.copyWith(fontSize: 14)), bodyMedium: z(t.bodyMedium?.copyWith(fontSize: 14)), bodySmall: z(t.bodySmall?.copyWith(fontSize: 12)),
    labelLarge: z(t.labelLarge?.copyWith(fontSize: 13)), labelMedium: z(t.labelMedium?.copyWith(fontSize: 12)), labelSmall: z(t.labelSmall?.copyWith(fontSize: 11)),
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Lato',
    colorScheme: ColorScheme.fromSeed(seedColor: C.blue600, surface: C.card, surfaceTint: Colors.transparent),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    // no click ripple / flash: on large rows and cards it looks like the screen blinking
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: kLightUi ? Colors.transparent : const Color(0x08141B2D),
    scaffoldBackgroundColor: C.bg,
    visualDensity: VisualDensity.compact,
  );
  return base.copyWith(
    textTheme: _protoText(base.textTheme),
    primaryTextTheme: _protoText(base.primaryTextTheme),
    tooltipTheme: const TooltipThemeData(textStyle: TextStyle(fontFamily: 'Lato', fontSize: 12, color: Colors.white, letterSpacing: 0)),
    dataTableTheme: const DataTableThemeData(dataTextStyle: TextStyle(fontFamily: 'Lato', fontSize: 13, color: C.text, letterSpacing: 0)),
    dividerColor: C.border,
    dividerTheme: const DividerThemeData(color: C.border, thickness: 1, space: 1),
    popupMenuTheme: const PopupMenuThemeData(color: C.card, surfaceTintColor: Colors.transparent, elevation: 8),
    drawerTheme: const DrawerThemeData(surfaceTintColor: Colors.transparent),
    // pop-ups (item picker, pick-a-document, confirmations) are plain white — no grey tint
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    datePickerTheme: const DatePickerThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: C.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: const BorderSide(color: C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: const BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: const BorderSide(color: C.blue600, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: const BorderSide(color: C.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: const BorderSide(color: C.red, width: 1.4)),
      hintStyle: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: C.faint, letterSpacing: 0),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.blue600 : Colors.white),
      side: const BorderSide(color: Color(0xFFC5CBD8), width: 1.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      visualDensity: VisualDensity.compact,
    ),
    snackBarTheme: const SnackBarThemeData(backgroundColor: C.navy900, behavior: SnackBarBehavior.floating, contentTextStyle: TextStyle(fontFamily: 'Lato', color: Colors.white, fontSize: 13, letterSpacing: 0)),
  );
}
