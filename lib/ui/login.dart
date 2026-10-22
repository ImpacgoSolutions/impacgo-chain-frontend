import 'package:flutter/material.dart';
import '../app_state.dart';
import '../core/auth.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Sign-in page shown until someone logs in.
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

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.soft)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [C.blue600, Color(0xFF6A5CF7)])),
                  child: const Text('IC', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                const Text('IMPACGO Chain', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 6),
              const Text('Supply Chain Management', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: C.faint)),
              const SizedBox(height: 22),
              CardBox(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Sign in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Use your work email and password', style: TextStyle(fontSize: 12.5, color: C.faint)),
                  const SizedBox(height: 18),
                  _label('Email'),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(hintText: 'name@impacgo.com', contentPadding: EdgeInsets.symmetric(horizontal: 11, vertical: 13)),
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 14),
                  _label('Password'),
                  TextField(
                    controller: _pass,
                    obscureText: _hide,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
                      suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18), onPressed: () => setState(() => _hide = !_hide)),
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: C.red))),
                  const SizedBox(height: 18),
                  SizedBox(height: 42, child: Btn('Sign in', icon: 'check', onTap: _signIn)),
                  const SizedBox(height: 12),
                  const Text('Forgot your password? Ask your administrator to reset it.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: C.faint)),
                ]),
              ),
              const SizedBox(height: 16),
              CardBox(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Demo accounts · tap one to fill in the form', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.soft)),
                  const SizedBox(height: 6),
                  for (final u in demoUsers)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() {
                        _email.text = u.email;
                        _pass.text = u.password;
                        _error = null;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(children: [
                          Avatar(u.name),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(u.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              Text(u.email, style: const TextStyle(fontSize: 11.5, color: C.faint)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: C.faint),
                        ]),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
