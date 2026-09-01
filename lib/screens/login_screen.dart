// lib/screens/login_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../services/notification_service.dart';
import '../services/theme_provider.dart';
import '../services/error_handler.dart';
import '../services/fcm_service.dart';
import '../widgets/error_snackbar.dart';
import 'buyer/buyerDashboardScreen.dart';
import 'seller/seller_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'branch_director/branch_director_dashboard_screen.dart';
import 'finance/finance_dashboard_screen.dart';
import 'technical/technical_dashboard_screen.dart';
import 'corporate_sales/corporate_sales_dashboard_screen.dart';
import 'showroom/showroom_dashboard_screen.dart';
import 'business_staff/business_staff_dashboard_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final AuthService _auth = AuthService();

  int _logoTapCount = 0;

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
    _logoTapCount = 0;
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  void _onLogoTap() {
    _logoTapCount++;
    if (_logoTapCount >= 7) {
      _showDeveloperDialog();
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'username': _identifierController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        throw ApiException(
          statusCode: 401,
          message: 'Invalid username or password. Please try again.',
        );
      }

      if (response.statusCode == 403) {
        throw ApiException(
          statusCode: 403,
          message: 'Your account is disabled. Please contact support.',
        );
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server returned an invalid response. Please try again later.',
        );
      }

      if (response.statusCode == 200 && data['success'] == true) {
        await _auth.storage.write(key: 'jwt_token', value: data['accessToken']);
        await _auth.storage.write(key: 'refresh_token', value: data['refreshToken']);
        await _auth.storage.write(key: 'user_role', value: data['user']['role']);
        // FCM handles notification updates

        // Initialize FCM after login
        await FcmService.init();

        final role = data['user']['role'];
        if (mounted) {
          Widget destination;
          switch (role) {
            case 'admin':
              destination = const AdminDashboardScreen();
              break;
            case 'seller':
              destination = const SellerDashboardScreen();
              break;
            case 'branch_director':
              destination = const BranchDirectorDashboardScreen();
              break;
            case 'finance':
              destination = const FinanceDashboardScreen();
              break;
            case 'technical':
              destination = const TechnicalDashboardScreen();
              break;
            case 'corporate_sales':
              destination = const CorporateSalesDashboardScreen();
              break;
            case 'showroom':
              destination = const ShowroomDashboardScreen();
              break;
            case 'business_staff':
              destination = const BusinessStaffDashboardScreen();
              break;
            default:
              destination = const BuyerDashboardScreen();
              break;
          }
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => destination),
                (route) => false,
          );
        }
        return;
      }

      String errorMessage;
      switch (response.statusCode) {
        case 400:
          errorMessage = data['message'] ?? 'Invalid request. Please check your input.';
          break;
        case 429:
          errorMessage = data['message'] ?? 'Too many login attempts. Please wait a moment.';
          break;
        case 500:
        case 502:
        case 503:
          errorMessage = 'Server is currently unavailable. Please try again later.';
          break;
        default:
          errorMessage = data['message'] ?? 'Login failed. Please try again.';
      }
      throw ApiException(statusCode: response.statusCode, message: errorMessage);
    } on ApiException catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } on SocketException {
      if (mounted) {
        showErrorSnackbar(
          context,
          ApiException(
            statusCode: null,
            message: 'No internet connection. Please check your network.',
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        showErrorSnackbar(
          context,
          ApiException(
            statusCode: null,
            message: 'Request timed out. The server may be busy. Please try again.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(
          context,
          ApiException(
            statusCode: null,
            message: 'An unexpected error occurred. Please try again later.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              colors: [Color(0xFF0A0E1A), Color(0xFF141B2D), Color(0xFF1A2540)])
              : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8F0FE), Color(0xFFD4E4F7), Color(0xFFB8D0E8)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GestureDetector(
                              onTap: _onLogoTap,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/wingapro.png',
                                    width: 60,
                                    height: 60,
                                    errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.wifi_tethering, size: 50),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'WINGA PRO',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0A2E5C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to your account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _identifierController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email or Phone Number',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                              validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Please enter your email or phone number'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(() =>
                                  _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                              validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Please enter your password'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Create New Account'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}