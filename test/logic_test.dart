import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/screens/importer.dart';

void main() {
  test('import checks and creates real records', () {
    final spec = importSpecs['cust']!;
    final n = S.customers.length;
    final good = {'Name': 'Import Test Co', 'City': 'Guntur', 'State': 'Andhra Pradesh', 'Payment Terms': 'Net 45 days', 'Credit Limit': '500000'};
    expect(spec.check(good), isNull);
    final id = spec.create(good);
    expect(S.customers.length, n + 1);
    expect(S.cust(id).terms, 45);
    expect(S.cust(id).limit, 500000);
    expect(spec.check(good), contains('already exists'));
    expect(spec.check({...good, 'Name': 'X', 'State': 'Atlantis'}), contains('not a state'));
    expect(spec.check({...good, 'Name': 'Y', 'GSTIN': '12ABC'}), contains('GSTIN'));
    expect(spec.check({...good, 'Name': 'Z', 'Payment Terms': 'Net 999 days'}), contains('Payment term'));
    final it = importSpecs['itm']!;
    expect(it.check({'Name': 'N', 'Category': S.categories.first, 'Cost': '100', 'Price': '50'}), contains('below cost'));
    final iid = it.create({'Name': 'Imported Item', 'Category': S.categories.first, 'Cost': '10', 'Price': '15'});
    expect(S.stk(S.warehouses.first.id, iid).onhand, 0);
    final ld = importSpecs['lead']!;
    expect(ld.check({'Company': 'A', 'Contact': 'B', 'City': 'C'}), contains('mobile'));
    ld.create({'Company': 'Lead Co', 'Contact': 'B', 'City': 'C', 'Phone': '9999999999'});
    expect(S.leads.first.company, 'Lead Co');
  });

  test('ids stay unique after a delete; lists feed the dropdowns', () {
    final a = S.nextCustomerId();
    S.customers.removeWhere((c) => c.id == S.customers.first.id); // delete the first customer
    final b = S.nextCustomerId();
    expect(S.customers.any((c) => c.id == b), isFalse);
    expect(b == a || b.compareTo(a) >= 0, isTrue);
    S.taxCodes.add(S.taxCodes.first..status = 'Active');
    expect(S.taxRateOf('GST 28%'), 28);
    expect(S.termDaysOf('Net 45 days'), 45);
    expect(S.branchNames, isNotEmpty);
    expect(S.currencyCodes, contains('INR'));
  });
}
