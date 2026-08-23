// lib/screens/terms_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen>
    with SingleTickerProviderStateMixin {
  bool _termsAccepted = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, String>> _terms = [
    {'title': '1. Acceptance of Terms',
      'content': 'By using the WINGA PRO application, you agree to comply with and be bound by these Terms and Conditions. If you do not agree, please do not use the application.'},
    {'title': '2. Description of Service',
      'content': 'WINGA PRO is a digital business management platform that provides internet package sales, customer management, staff tracking, financial reporting, and other related services.'},
    {'title': '3. User Accounts',
      'content': 'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You must notify us immediately of any unauthorized use.'},
    {'title': '4. Payments and Transactions',
      'content': 'All payments made through the platform are subject to our payment gateway terms. You agree to provide accurate payment information and authorize us to charge the applicable fees.'},
    {'title': '5. Privacy Policy',
      'content': 'Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your personal information.'},
    {'title': '6. Prohibited Activities',
      'content': 'You agree not to misuse the application, including but not limited to: hacking, distributing malware, violating any laws, or infringing on intellectual property rights.'},
    {'title': '7. Termination',
      'content': 'We reserve the right to terminate or suspend your account at any time for violations of these terms or for any other reason deemed appropriate.'},
    {'title': '8. Limitation of Liability',
      'content': 'WINGA PRO is provided "as is" without warranties of any kind. We are not liable for any damages arising from the use of the application.'},
    {'title': '9. Changes to Terms',
      'content': 'We may update these Terms and Conditions from time to time. Continued use of the application constitutes acceptance of the revised terms.'},
    {'title': '10. Governing Law',
      'content': 'These terms shall be governed by and construed in accordance with the laws of Tanzania.'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset
        .zero).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAgreeAndStart() {
    if (_termsAccepted) {
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(-0.3, 0), end: Offset
                    .zero).animate(animation),
                child: child)),
        transitionDuration: const Duration(milliseconds: 500),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E1A), Color(0xFF141B2D),
                  Color(0xFF1A2540)])
                : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A2E5C), Color(0xFF1A3A7A),
                  Color(0xFF2A5A9A)])),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16,
                      vertical: 12),
                  child: Row(children: [
                    IconButton(
                        icon: Icon(Icons.arrow_back_ios,
                            color: isDark ? Colors.white70 : Colors.white),
                        onPressed: () => Navigator.pop(context)),
                    const Spacer(),
                    Text('Terms and Conditions',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.white)),
                    const Spacer(),
                    const SizedBox(width: 48)
                  ])),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('Terms and Conditions',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.white)),
                          const SizedBox(height: 4),
                          Text('Last updated: July 2026',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white60
                                      : Colors.white70)),
                          const SizedBox(height: 24),
                          ..._terms.map((term) =>
                              _buildTermCard(term, isDark)).toList(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.white.withOpacity(0.15),
                  border: Border(
                      top: BorderSide(
                          color: Colors.white.withOpacity(
                              isDark ? 0.08 : 0.15),
                          width: 1.5)),
                ),
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            Checkbox(
                                value: _termsAccepted,
                                onChanged: (value) => setState(() =>
                                _termsAccepted = value ?? false),
                                activeColor: Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6))),
                            Expanded(
                                child: Text(
                                  'I have read and agree to the Terms and Conditions',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white
                                          : Colors.white),
                                )),
                          ]),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _termsAccepted
                                  ? _onAgreeAndStart
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _termsAccepted
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
                                disabledBackgroundColor: Colors.grey.shade600,
                              ),
                              child: const Text(
                                'Start',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermCard(Map<String, String> term, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: isDark
          ? Colors.white.withOpacity(0.04)
          : Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Colors.white.withOpacity(isDark ? 0.06 : 0.15),
            width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(term['title']!,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.white)),
                const SizedBox(height: 6),
                Text(term['content']!,
                    style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark ? Colors.white70
                            : Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}