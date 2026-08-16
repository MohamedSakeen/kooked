import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _authService.signUpWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/pantry');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  Future<void> _handleGoogleRegister() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _authService.signInWithGoogle();
      if (mounted) context.go('/pantry');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (msg.contains('weak-password')) return 'Password is too weak.';
    if (msg.contains('invalid-email')) return 'Invalid email address.';
    if (msg.contains('network')) return 'Network error. Check your connection.';
    return 'Registration failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text('🍳', style: TextStyle(fontSize: 40)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Create Account', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Start cooking smarter today',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Please enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter your email';
                          if (!v.contains('@')) return 'Please enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter a password';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outlined),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          child: const Text('Create Account'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR', style: Theme.of(context).textTheme.bodySmall),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleRegister,
                          icon: const Icon(Icons.g_mobiledata, size: 24),
                          label: const Text('Continue with Google'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have an account? ',
                              style: Theme.of(context).textTheme.bodySmall),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white70,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }
}
