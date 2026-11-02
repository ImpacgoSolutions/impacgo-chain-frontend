import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/store.dart';

/// Units are plain names; a unit typed on the item form ("+ Add a new unit") is added to Units of Measure once.
void main() {
  AppStore.singleDemo = true;
  test('the standard units are plain names, without pack sizes in brackets', () {
    for (final u in S.uoms) {
      expect(u.name.contains('('), isFalse, reason: u.name);
      expect(u.name.contains(' of '), isFalse, reason: u.name);
    }
  });

  test('a new unit is added once; an existing one is reused whatever the capitals', () {
    final before = S.uoms.length;
    expect(S.unitFor('Pallet'), 'Pallet');
    expect(S.uoms.length, before + 1);
    expect(S.unitFor('pallet'), 'Pallet');
    expect(S.unitFor(' Box '), 'Box');
    expect(S.uoms.length, before + 1);
  });
}
