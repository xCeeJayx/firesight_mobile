import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isOfficerExpanded = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        // Fetch user profile
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (profileData != null && profileData['role'] == 'inspector') {
          // Navigate to Task Dashboard
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(isPublicUser: false),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
        } else {
          // Clear session and show error
          await Supabase.instance.client.auth.signOut();
          _showToast('Access Denied: BFP Inspector privileges required.');
        }
      }
    } on AuthException catch (e) {
      _showToast(e.message);
    } catch (e) {
      _showToast('An unexpected error occurred during sign in.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToGuestMode() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(isPublicUser: true),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626), // Tactical red
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Deep slate background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF020617), // Dark slate top
              Color(0xFF0F172A), // Navy bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),

                      // BFP Tactical Hero Header & Guidance
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E293B),
                          border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.4), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFF97316),
                          size: 54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'FireSight',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'BFP LINGAYEN PUBLIC SAFETY & COMMAND PORTAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B), // Gold / Amber accent
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Text(
                          'Select your mode to continue',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // CHOICE MATRIX

                      // CARD A: BFP Inspector / Officer Sign In (Expandable Inline)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isOfficerExpanded
                                ? const Color(0xFFF97316)
                                : const Color(0xFF334155),
                            width: _isOfficerExpanded ? 1.8 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isOfficerExpanded
                                  ? const Color(0xFFEA580C).withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                // Card Header Trigger
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isOfficerExpanded = !_isOfficerExpanded;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.shield_outlined,
                                            color: Color(0xFFF97316),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: const [
                                              Text(
                                                'BFP Inspector / Staff Sign In',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                'Authorized personnel login for inspection orders, audits, & official approvals.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF94A3B8),
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          _isOfficerExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          color: const Color(0xFFF97316),
                                          size: 28,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Inline Expanded Credentials Form
                                AnimatedCrossFade(
                                  firstChild: const SizedBox(width: double.infinity),
                                  secondChild: Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          const Divider(color: Color(0xFF334155), height: 24),

                                          // Email / Badge Field
                                          TextFormField(
                                            controller: _emailController,
                                            style: const TextStyle(color: Colors.white, fontSize: 14),
                                            keyboardType: TextInputType.emailAddress,
                                            decoration: _inputDecoration(
                                              icon: Icons.badge_outlined,
                                              hintText: 'Inspector Email / Badge ID',
                                            ),
                                            validator: (val) {
                                              if (val == null || val.trim().isEmpty) {
                                                return 'Please enter email or badge ID';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 14),

                                          // Password Field
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: !_isPasswordVisible,
                                            style: const TextStyle(color: Colors.white, fontSize: 14),
                                            decoration: _inputDecoration(
                                              icon: Icons.lock_outline,
                                              hintText: 'Password',
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                                  color: const Color(0xFF94A3B8),
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _isPasswordVisible = !_isPasswordVisible;
                                                  });
                                                },
                                              ),
                                            ),
                                            validator: (val) {
                                              if (val == null || val.isEmpty) {
                                                return 'Please enter password';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20),

                                          // Sign In CTA Button
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFFEA580C), Color(0xFFD97706)],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: _isLoading ? null : _signIn,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor: Colors.transparent,
                                                padding: const EdgeInsets.symmetric(vertical: 15),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child: CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.5,
                                                      ),
                                                    )
                                                  : const Text(
                                                      'SIGN IN AS BFP OFFICER',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 1.5,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  crossFadeState: _isOfficerExpanded
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 300),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // CARD B: Public Citizen / Guest Mode (Single-Tap Direct Access)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFF97316).withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF97316).withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _navigateToGuestMode,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF97316).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.map_outlined,
                                        color: Color(0xFFF97316),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Public Citizen / Guest Mode',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            'View live fire hazard & hydrant maps, find evacuation shelters, or report an incident.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF97316),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      suffixIcon: suffixIcon,
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }
}
