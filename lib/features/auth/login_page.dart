import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _hasNavigated = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final session = data.session;
        final event = data.event;

        debugPrint("Auth Event: $event | Has session: ${session != null}");

        if ((event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.initialSession ||
                event == AuthChangeEvent.tokenRefreshed) &&
            session != null &&
            mounted &&
            !_hasNavigated) {
          debugPrint("Auth changed, will navigate to dashboard");
          _hasNavigated = true;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _navigateToDashboard();
          });
        } else if (event == AuthChangeEvent.signedOut && mounted) {
          if (_isLoading) {
            setState(() => _isLoading = false);
          }
        }
      },
      onError: (error) {
        debugPrint("Auth Subscription Error: $error");
        if (mounted) {
          _showError("Authentication error. Please try again.");
          setState(() => _isLoading = false);
        }
      },
    );
  }

  /// Google Sign In
  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    _hasNavigated = false;
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://callback',
      );
    } on AuthException catch (error) {
      _showError(error.message);
      if (mounted) setState(() => _isLoading = false);
    } catch (error) {
      debugPrint("Google Sign-In failed: $error");
      _showError("Google Sign-In failed.");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (error) {
      _showError(error.message);
      if (mounted) setState(() => _isLoading = false);
    } catch (error) {
      _showError("An unexpected error occurred.");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAsGuest() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } on AuthException catch (error) {
      _showError(error.message);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard() {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardPage()),
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[700]!, Colors.green[900]!],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Icon(Icons.storefront,
                      size: 80, color: Colors.white),
                  const SizedBox(height: 10),
                  const Text(
                    "Davao MSME Hub",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text("Supporting Local Artisans",
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 40),
                  _buildLoginCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text("Welcome Back",
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            _buildSignInButton(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text("OR", style: TextStyle(color: Colors.grey)),
            ),
            _buildGoogleButton(),
            TextButton(
              onPressed: _isLoading ? null : _signInAsGuest,
              child: const Text("Continue as Guest",
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Text("Sign In"),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _signInWithGoogle,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
              'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
              height: 24),
          const SizedBox(width: 12),
          const Text("Sign in with ADDU Mail",
              style: TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}