// lib/screens/welcome_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_provider.dart';
import 'terms_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Tap counter for logo
  int _logoTapCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
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

  void _navigateToTerms() {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => const TermsScreen(),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.3, 0), end: Offset
                  .zero).animate(animation),
              child: child)),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  // Show developer links dialog
  void _showDeveloperDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Developed by'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Visit our websites:'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _launchUrl('https://msimutechnologies.com'),
              icon: const Icon(Icons.business),
              label: const Text('Msimu Softech'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5C),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _launchUrl('http://francisbahatiportfolio.netlify.app'),
              icon: const Icon(Icons.person),
              label: const Text('Francis Bahati Portfolio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5C),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    // Reset counter after showing dialog
    _logoTapCount = 0;
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
      );
    }
  }

  void _onLogoTap() {
    _logoTapCount++;
    if (_logoTapCount >= 7) {
      _showDeveloperDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E1A), Color(0xFF141B2D)])
                : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A2E5C), Color(0xFF1A3A7A)])),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: GestureDetector(
                      onTap: _onLogoTap,
                      child: Image.asset(
                        'assets/images/wingapro.png',
                        width: 180,
                        height: 180,
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.wifi_tethering, size: 120,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'WINGA PRO',
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                                blurRadius: 12,
                                color: Colors.black26,
                                offset: Offset(2, 2))
                          ]),
                    )),
                const SizedBox(height: 8),
                FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Smart Internet Business Management',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400),
                      textAlign: TextAlign.center,
                    )),
                const Spacer(flex: 3),
                SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: ElevatedButton(
                          onPressed: _navigateToTerms,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0A2E5C),
                              minimumSize: const Size(200, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 8,
                              shadowColor: Colors.black26),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ))),
                const SizedBox(height: 20),
                FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'By continuing, you agree to our Terms & Privacy Policy',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                      textAlign: TextAlign.center,
                    )),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}