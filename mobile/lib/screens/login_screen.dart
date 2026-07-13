import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = true;

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 6) {
      setState(() {
        _message = 'Enter your email and a password of at least 6 characters.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_isSignUp) {
        await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': _fullName.text.trim()},
        );
        setState(() {
          _message = 'Check your email to confirm your account!';
          _messageIsError = false;
        });
      } else {
        await supabase.auth.signInWithPassword(email: email, password: password);
        // AuthGate reacts to the auth stream; nothing else to do here.
      }
    } on AuthException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
        _messageIsError = true;
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(gradient: kGradient, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.attach_money, size: 34, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text('TakaKhata', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                Text('Manage your finances with ease',
                    style: TextStyle(color: kFg.withValues(alpha: 0.4), fontSize: 13)),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isSignUp ? 'Create Account' : 'Welcome Back',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        if (_message != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_messageIsError ? kRed : kEmerald).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_message!,
                                style: TextStyle(color: _messageIsError ? kRed : kEmerald, fontSize: 13)),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_isSignUp) ...[
                          TextField(
                            controller: _fullName,
                            decoration: const InputDecoration(hintText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(hintText: 'Email address', prefixIcon: Icon(Icons.mail_outline)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(hintText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                        ),
                        const SizedBox(height: 18),
                        GradientButton(label: _isSignUp ? 'Create Account' : 'Sign In', busy: _busy, onPressed: _submit),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _isSignUp = !_isSignUp;
                              _message = null;
                            }),
                            child: Text(
                              _isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up",
                              style: TextStyle(color: kFg.withValues(alpha: 0.45), fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
