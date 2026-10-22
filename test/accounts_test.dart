import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impacgo_chain/app_state.dart';
import 'package:impacgo_chain/core/auth.dart';
import 'package:impacgo_chain/core/store.dart';
import 'package:impacgo_chain/main.dart';
import 'package:impacgo_chain/screens/users.dart';
import 'package:impacgo_chain/ui/overlays.dart';
import 'package:impacgo_chain/ui/shell.dart';

Finder _box(String hint) => find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint);

/// Sign-in, accounts with chosen screens, the profile card and signing out.
void main() {
  AppStore.singleDemo = true;
  AppStore.requireLogin = true; // like the website: it opens on the sign-in page

  Future<void> start(WidgetTester t, {Size size = const Size(1536, 900)}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ImpacgoChainApp());
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the website opens on the sign-in page; a wrong password is refused; the right one signs in', (t) async {
    await start(t);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('SCM Workspace'), findsNothing);
    await t.enterText(_box('name@impacgo.com'), 'admin@impacgo.com');
    await t.enterText(_box('Password'), 'wrong');
    await t.tap(find.text('Sign in').last);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Email or password is incorrect'), findsOneWidget);
    // forgot password: a reset link is sent (the same message whether or not the account exists)
    await t.tap(find.text('Forgot password?'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Reset your password'), findsOneWidget);
    await t.tap(find.text('Send reset link'));
    await t.pump(const Duration(milliseconds: 300));
    expect(debugToasts.last, contains('a link to reset the password has been sent'));
    expect(S.emails.first.to, 'admin@impacgo.com');
    await t.pump(const Duration(seconds: 4));
    expect(find.text('Demo accounts · tap one to fill in the form'), findsNothing, reason: 'only the sign-in card');
    await t.enterText(_box('Password'), 'Admin@123');
    await t.tap(find.text('Sign in').last);
    await t.pump(const Duration(milliseconds: 400));
    expect(S.signedIn, isTrue);
    expect(find.text('SCM Workspace'), findsWidgets);
    expect(S.canView('h_users'), isTrue, reason: 'the Admin has Users & Roles in Setup');
    expect(t.takeException(), isNull);
  });

  testWidgets('the Admin creates an account on the form: the role\'s standard screens are ticked', (t) async {
    S.login('admin@impacgo.com', 'Admin@123');
    await start(t, size: const Size(1536, 2000)); // tall enough to show the whole form
    grantableScreens = {for (final g in sidebarScreens()) ...g.$2.map((i) => i.id)};
    openUserForm();
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    await t.enterText(_box('e.g. Ravi Teja'), 'Ravi Teja');
    await t.enterText(_box('name@impacgo.com'), 'ravi@impacgo.com');
    await t.enterText(_box('At least 6 characters'), 'Ravi@123');
    await t.ensureVisible(find.text('Create user'));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.text('Create user'));
    await t.pump(const Duration(milliseconds: 500));
    final ravi = S.users.firstWhere((u) => u.email == 'ravi@impacgo.com');
    expect(ravi.role, 'exec');
    expect(ravi.screens, roleScreens('exec'));
    expect(ravi.screens, isNot(contains('h_users')));
    expect(t.takeException(), isNull);
  });

  test('an account opens exactly the screens ticked for it; Admin-only screens can never be given', () {
    grantableScreens = {for (final g in sidebarScreens()) ...g.$2.map((i) => i.id)};
    S.users.add(AppUser('meena@impacgo.com', 'Meena@123', 'Meena Iyer', 'exec', roleTitle('exec'), screens: {'workspace', 'preqs', 'pinvoices', 'h_users', 'h_company'}));
    expect(S.login('meena@impacgo.com', 'Meena@123'), isTrue);
    expect(S.canView('preqs'), isTrue);
    expect(S.canView('pinvoices'), isTrue, reason: 'given although not standard for the role');
    expect(S.canView('porders'), isFalse, reason: 'standard for the role but not ticked');
    expect(S.canView('h_users'), isFalse);
    expect(S.canView('h_company'), isFalse);
    // the sidebar shows exactly those screens
    final shown = [for (final g in nav) for (final it in g.items) if (it.category == null && navItemVisible(it)) it.id];
    expect(shown.toSet(), {'workspace', 'preqs', 'pinvoices'});
    // what she may press still follows her role
    expect(S.canAct('PI', 'Approve difference'), isFalse);
    S.login('admin@impacgo.com', 'Admin@123');
  });

  testWidgets('the Admin deletes an account (after confirming); not their own, not the last Admin', (t) async {
    S.login('admin@impacgo.com', 'Admin@123');
    await start(t);
    final temp = AppUser('temp@impacgo.com', 'Temp@123', 'Temp User', 'delivery', roleTitle('delivery'));
    S.users.add(temp);
    // the only Admin, and yourself, cannot be deleted
    expect(cannotDeleteUser(S.user!), isNotNull);
    deleteUser(S.user!);
    expect(S.users, contains(S.user));
    // another account: confirm, and it is gone
    deleteUser(temp);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Delete permanently'));
    await t.pump(const Duration(milliseconds: 400));
    expect(S.users, isNot(contains(temp)));
    expect(S.loginError('temp@impacgo.com', 'Temp@123'), isNotNull, reason: 'a deleted account cannot sign in');
    // the edit form offers Delete user for others, not for yourself
    openUserForm(S.users.firstWhere((u) => u.role == 'store'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Delete user'), findsOneWidget);
    closeAll();
    await t.pump(const Duration(milliseconds: 300));
    openUserForm(S.user);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Delete user'), findsNothing);
    closeAll();
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
  });

  test('a switched-off account cannot sign in; at least one Admin always stays', () {
    final u = S.users.firstWhere((x) => x.role == 'delivery')..active = false;
    expect(S.loginError(u.email, u.password), contains('switched off'));
    u.active = true;
    expect(S.loginError(u.email, u.password), isNull);
    S.login('admin@impacgo.com', 'Admin@123');
  });

  testWidgets('profile card: edit and save changes, then sign out to the sign-in page', (t) async {
    S.login('executive@impacgo.com', 'Exec@123');
    await start(t, size: const Size(390, 844));
    openProfile();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Edit profile'), findsOneWidget);
    await t.tap(find.text('Edit profile'));
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(_box('Your full name'), 'Priya S. Sharma');
    await t.enterText(_box('+91 98480 12345'), '+91 90000 11111');
    await t.tap(find.text('Save changes'));
    await t.pump(const Duration(milliseconds: 300));
    expect(S.user!.name, 'Priya S. Sharma');
    expect(S.user!.phone, '+91 90000 11111');
    expect(find.text('Edit profile'), findsOneWidget, reason: 'back to the card');
    // mismatched passwords are refused
    await t.tap(find.text('Edit profile'));
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(_box('Leave empty to keep the current one'), 'NewPass1');
    await t.tap(find.text('Save changes'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('The two passwords do not match'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Sign out'));
    await t.pump(const Duration(milliseconds: 400));
    expect(S.signedIn, isFalse);
    expect(find.text('Sign in'), findsWidgets);
    expect(t.takeException(), isNull);
    S.user!.name = 'Priya Sharma';
    S.login('admin@impacgo.com', 'Admin@123');
    closeAll();
  });

  testWidgets('Users & Roles screen and the form fit a laptop and a phone', (t) async {
    for (final size in const [Size(1536, 900), Size(390, 844)]) {
      S.login('admin@impacgo.com', 'Admin@123');
      await start(t, size: size);
      S.go('h_users');
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      openUserForm(S.users.firstWhere((u) => u.role == 'store'));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      closeAll();
      await t.pump(const Duration(milliseconds: 300));
    }
  });
}
