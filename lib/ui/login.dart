import 'package:flutter/material.dart';
import '../app_state.dart';
import 'overlays.dart';
import 'tokens.dart';
import 'widgets.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Sign-in page shown until someone logs in: one card with email, password, "Forgot password?" and Sign in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _signIn() {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Enter your email and password');
      return;
    }
    final err = S.loginError(_email.text.trim(), _pass.text);
    if (err != null) setState(() => _error = err);
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.soft)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: CardBox(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // brand
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), gradient: const LinearGradient(colors: [C.blue600, Color(0xFF6A5CF7)])),
                    child: const Text('IC', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('IMPACGO Chain', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Use your work email and password', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: C.faint)),
                const SizedBox(height: 24),
                _label('Email'),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(hintText: 'name@impacgo.com', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                  onSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _label('Password')),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _forgotPassword(_email.text.trim()),
                      child: const Text('Forgot password?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.blue600)),
                    ),
                  ),
                ]),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  autofillHints: const [AutofillHints.password],
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: IconButton(
                      tooltip: _hide ? 'Show password' : 'Hide password',
                      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: C.faint),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  onSubmitted: (_) => _signIn(),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: C.red))),
                const SizedBox(height: 22),
                // full width, the text in the middle
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _signIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: C.blue600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Sign in'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Forgot password: the reset link goes to the email address (sent by the backend once it is connected).
/// The message is the same whether or not the account exists, so nobody can find out which emails have accounts.
void _forgotPassword(String email) {
  final ctl = TextEditingController(text: email);
  String? error;
  showDialog<void>(
    context: rootCtx,
    barrierColor: const Color(0x73141B2D),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void send() {
          final e = ctl.text.trim();
          if (!_emailPattern.hasMatch(e)) {
            setState(() => error = 'Enter a valid email address');
            return;
          }
          S.requestPasswordReset(e);
          Navigator.of(ctx).pop();
          toast('If an account exists for $e, a link to reset the password has been sent to it');
        }

        return Dialog(
          backgroundColor: C.card,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Reset your password', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Enter the email you sign in with. We will send you a link to choose a new password.', style: TextStyle(fontSize: 12.5, color: C.soft, height: 1.5)),
                const SizedBox(height: 16),
                TextField(
                  controller: ctl,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(hintText: 'name@impacgo.com', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                  onSubmitted: (_) => send(),
                ),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(fontSize: 12.5, color: C.red))),
                const SizedBox(height: 20),
                Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
                  Btn.secondary('Cancel', onTap: () => Navigator.of(ctx).pop()),
                  Btn('Send reset link', icon: 'msg', onTap: send),
                ]),
              ]),
            ),
          ),
        );
      },
    ),
  ).whenComplete(ctl.dispose);
}
