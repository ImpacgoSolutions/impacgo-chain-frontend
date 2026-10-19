// Formatting and date helpers shared by the whole app.

const String kToday = '2026-09-28';

String todayStr() => kToday;

String nowStr() {
  final d = DateTime.now();
  var h = d.hour;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h == 0) h = 12;
  return '${h.toString().padLeft(2, '0')}:$m $ap';
}

String nowStamp() => '${todayStr()} ${nowStr()}';

DateTime _p(String s) => DateTime.parse(s);

int daysBetween(String a, String b) => _p(b).difference(_p(a)).inDays;

String addDays(String d, int n) {
  final x = _p(d).add(Duration(days: n));
  return '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
}

String _groupIndian(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// ₹ with Indian digit grouping. Decimals are shown only when the value has paise.
String fmtINR(num v) {
  final neg = v < 0;
  final r = (v.abs() * 100).round() / 100;
  final whole = r.floor();
  final frac = ((r - whole) * 100).round();
  var s = '₹${_groupIndian(whole)}';
  if (frac != 0) s += '.${frac.toString().padLeft(2, '0')}';
  return neg ? '-$s' : s;
}

String fmtNum(num v) => _groupIndian(v.round().abs()) == '0' && v == 0
    ? '0'
    : '${v < 0 ? '-' : ''}${_groupIndian(v.round().abs())}';

String initials(String n) {
  final parts = n.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]);
  return parts.join().toUpperCase();
}

String capFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
