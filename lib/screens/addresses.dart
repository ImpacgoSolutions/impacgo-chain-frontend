import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../ui/overlays.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// Customer page › Addresses: the billing and delivery addresses offered on quotations and sales orders.
class AddressesTab extends StatefulWidget {
  final String custId;
  const AddressesTab(this.custId, {super.key});
  @override
  State<AddressesTab> createState() => _AddressesTabState();
}

class _AddressesTabState extends State<AddressesTab> {
  List<Address> get list => S.addressesOf(widget.custId);

  void _add() {
    mform('Add address · ${S.cust(widget.custId).name}', [
      const F.header('Address'),
      const F('label', 'Address Label', req: true, hint: 'e.g. Hyderabad branch, Main warehouse'),
      F('type', 'Address Type', type: 'select', req: true, options: opts(addressTypes)),
      const F('line', 'Address Line', req: true, full: true, hint: 'Building, street, area'),
      const F('city', 'City', req: true),
      F('state', 'State', type: 'select', req: true, def: S.cust(widget.custId).state, options: opts(kStates)),
      const F('pin', 'PIN Code', req: true, hint: '6 digits'),
    ], (v, _) {
      final label = (v['label'] as String).trim();
      final pin = (v['pin'] as String).trim();
      if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
        toast('PIN Code must be 6 digits');
        return false;
      }
      if (list.any((a) => a.label.toLowerCase() == label.toLowerCase())) {
        toast('An address called "$label" already exists');
        return false;
      }
      setState(() => list.add(Address(label, v['type'] as String, (v['line'] as String).trim(), (v['city'] as String).trim(), v['state'] as String, pin)));
      S.refresh();
      toast('$label added · it is offered on quotations and sales orders');
      return true;
    }, btn: 'Save address', icon: 'check');
  }

  void _remove(Address a) {
    final rest = list.where((x) => x != a).toList();
    if (!rest.any((x) => x.billing) || !rest.any((x) => x.shipping)) {
      toast('Keep at least one billing and one shipping address');
      return;
    }
    confirmDelete('address "${a.label}"', () {
      setState(() => list.remove(a));
      S.refresh();
      toast('${a.label} removed');
    });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final a in list)
          ActivityRow(
            'home',
            '${a.label} · ${a.type}',
            '${a.text}${a.state != S.cust(widget.custId).state ? ' · other state: IGST applies' : ''}',
            tone: a.billing ? Tone.blue : Tone.teal,
            trailing: IconBtn('trash', () => _remove(a), size: 30, tip: 'Remove'),
          ),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: Btn.secondary('Add address', icon: 'plus', small: true, onTap: _add)),
        const SizedBox(height: 8),
        const Text('When a customer has more than one address, quotations and sales orders show a dropdown for the billing and shipping address. GST follows the shipping state.',
            style: TextStyle(fontSize: 11.5, color: C.faint)),
      ]);
}
