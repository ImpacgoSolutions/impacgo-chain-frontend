/// Report and document print template, changed in Setup › Company Settings › Report Templates.
/// Every Excel / PDF report download, tax invoice and payment receipt reads it,
/// so a change applies to the next download.
class ReportTemplate {
  /// Name shown in the template list (a ready-made style or one the user saved).
  String name = 'Classic';
  /// Overall look of report PDFs: Classic, Modern, Compact or Minimal (see [templateStyles]).
  String style = 'Classic';
  /// Extra lines the company adds, printed under the report details: (label, value).
  final List<List<String>> customFields = [];

  // ---- layout (all reports)
  String accent = 'Blue';
  String orientation = 'Automatic';
  String dateFormat = 'DD-MM-YYYY';
  bool showLogo = true;
  bool showAddress = true;
  bool showInfoBar = true;
  bool showKeyFigures = true;
  bool shadeRows = true;
  bool showTotals = true;
  bool showPreparedBy = true;
  bool showPageNumbers = true;
  String footerNote = '';

  // ---- per report: title and the columns left out
  final Map<String, String> titles = {};
  final Map<String, Set<String>> hidden = {};

  // ---- tax invoice and payment receipt
  String invoiceTitle = 'TAX INVOICE';
  String invoiceCopy = 'Original for recipient';
  String invoiceFooter = 'This is a computer-generated invoice.';
  String bankDetails = 'HDFC Bank · Current A/c 50200012345678 · IFSC HDFC0001234';
  String receiptTitle = 'PAYMENT RECEIPT';
  String receiptFooter = 'This is a computer-generated receipt and needs no signature.';

  ReportTemplate copy() => ReportTemplate()..apply(this);

  /// Copies every setting from [o] into this template.
  void apply(ReportTemplate o) {
    name = o.name;
    style = o.style;
    customFields
      ..clear()
      ..addAll([for (final f in o.customFields) [...f]]);
    applyLook(o);
    titles
      ..clear()
      ..addAll(o.titles);
    hidden
      ..clear()
      ..addAll({for (final e in o.hidden.entries) e.key: {...e.value}});
    invoiceTitle = o.invoiceTitle;
    invoiceCopy = o.invoiceCopy;
    invoiceFooter = o.invoiceFooter;
    bankDetails = o.bankDetails;
    receiptTitle = o.receiptTitle;
    receiptFooter = o.receiptFooter;
  }

  /// Copies only the look (style, colour, orientation, on/off parts) from [o];
  /// titles, columns, custom fields and invoice texts stay as they are.
  void applyLook(ReportTemplate o) {
    style = o.style;
    accent = o.accent;
    orientation = o.orientation;
    dateFormat = o.dateFormat;
    showLogo = o.showLogo;
    showAddress = o.showAddress;
    showInfoBar = o.showInfoBar;
    showKeyFigures = o.showKeyFigures;
    shadeRows = o.shadeRows;
    showTotals = o.showTotals;
    showPreparedBy = o.showPreparedBy;
    showPageNumbers = o.showPageNumbers;
    footerNote = o.footerNote;
  }

  /// The title printed on [report]'s downloads.
  String titleOf(String report) {
    final t = (titles[report] ?? '').trim();
    return t.isEmpty ? report : t;
  }

  bool shows(String report, String column) => !(hidden[report]?.contains(column) ?? false);
}

/// The template in use.
final reportTemplate = ReportTemplate();

/// Templates the company saved under its own name (Setup › Report Templates › Save as new template).
final List<ReportTemplate> myTemplates = [];

/// The four ready-made looks: name → what it looks like.
const templateStyles = <String, String>{
  'Classic': 'Company header, dark table header, shaded rows, totals. Good for every report.',
  'Modern': 'Coloured title band across the top, open table without lines, bold key figures.',
  'Compact': 'Small type and tight rows, landscape, full grid. Fits the most rows on a page.',
  'Minimal': 'Black and white, no logo or shading, thin lines. Clean for printing and filing.',
};

/// A ready-made template for [style] (layout only; texts and columns use the defaults).
ReportTemplate presetTemplate(String style) {
  final t = ReportTemplate()
    ..name = style
    ..style = style;
  switch (style) {
    case 'Modern':
      t
        ..accent = 'Blue'
        ..shadeRows = false;
      break;
    case 'Compact':
      t
        ..accent = 'Charcoal'
        ..orientation = 'Landscape'
        ..showKeyFigures = false;
      break;
    case 'Minimal':
      t
        ..accent = 'Navy'
        ..showLogo = false
        ..shadeRows = false
        ..showKeyFigures = false;
      break;
  }
  return t;
}

/// Accent colours: (rule / logo colour, table header colour) as ARGB.
const accentColors = <String, (int, int)>{
  'Blue': (0xFF2F5BEA, 0xFF1F2A44),
  'Navy': (0xFF1F2A44, 0xFF1F2A44),
  'Green': (0xFF15803D, 0xFF14532D),
  'Maroon': (0xFF9F1239, 0xFF4C0519),
  'Charcoal': (0xFF4B5563, 0xFF111827),
};

const orientations = ['Automatic', 'Portrait', 'Landscape'];
const dateFormats = ['DD-MM-YYYY', 'DD/MM/YYYY', 'DD MMM YYYY', 'YYYY-MM-DD'];

/// The 8 mandatory reports and their columns, in screen order.
const templateReports = <String, List<String>>{
  'Sales Order Register': ['Order Number', 'Order Date', 'Customer', 'Warehouse', 'Items', 'Amount', 'Status'],
  'Pending Deliveries': ['Delivery Number', 'Customer', 'Items', 'Sales Order', 'Delivery Date', 'Expected Delivery', 'Warehouse', 'Vehicle / Driver', 'Pending Status'],
  'Purchase Order Register': ['PO Number', 'PO Date', 'Supplier', 'Warehouse', 'Items', 'Quantity', 'Purchase Amount', 'Expected Delivery', 'Status'],
  'Pending Purchase Orders': ['PO Number', 'PO Date', 'Supplier', 'Items Pending', 'Warehouse', 'Ordered Qty', 'Received Qty', 'Pending Qty', 'Expected Delivery', 'PO Amount', 'Status'],
  'Goods Receipt Register (GRN)': ['GRN Number', 'GRN Date', 'PO Number', 'Supplier', 'Items', 'Warehouse', 'Received Quantity', 'Accepted Quantity', 'Rejected Quantity', 'Status'],
  'Stock Summary': ['Item Code', 'Item Name', 'Category', 'Warehouse', 'On Hand', 'Reserved', 'Available', 'Reorder Level', 'Stock Status'],
  'Stock Ledger': ['Date', 'Item', 'Warehouse', 'Transaction Type', 'Reference Number', 'Quantity In', 'Quantity Out', 'Balance', 'User'],
  'Reorder Level Report': ['Item', 'Category', 'Warehouse', 'Available Quantity', 'Reorder Level', 'Deficit Quantity', 'Status'],
};

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// A yyyy-mm-dd date in the template's date format.
String fmtTemplateDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  switch (reportTemplate.dateFormat) {
    case 'DD/MM/YYYY':
      return '${two(d.day)}/${two(d.month)}/${d.year}';
    case 'DD MMM YYYY':
      return '${two(d.day)} ${_months[d.month - 1]} ${d.year}';
    case 'YYYY-MM-DD':
      return '${d.year}-${two(d.month)}-${two(d.day)}';
    default:
      return '${two(d.day)}-${two(d.month)}-${d.year}';
  }
}
