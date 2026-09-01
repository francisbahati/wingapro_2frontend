// lib/screens/technical/technical_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/profile_header.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/error_view.dart';
import '../../widgets/notification_icon.dart';
import '../settings_screen.dart';
import '../notification_screen.dart';
import 'technical_tickets_screen.dart';
import 'technical_staff_screen.dart';
import 'technical_error_logs_screen.dart';
// import 'technical_account_recovery_screen.dart'; // ❌ REMOVED
import 'technical_payment_integrations_screen.dart';
import 'technical_security_alerts_screen.dart';
import 'technical_suspicious_transactions_screen.dart';
import 'technical_system_maintenance_screen.dart';
import 'technical_communication_screen.dart';
import 'technical_profile_screen.dart';

class TechnicalDashboardScreen extends StatefulWidget {
  const TechnicalDashboardScreen({super.key});

  @override
  State<TechnicalDashboardScreen> createState() =>
      _TechnicalDashboardScreenState();
}

class _TechnicalDashboardScreenState extends State<TechnicalDashboardScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  Map<String, dynamic>? _user;
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Technical Dashboard',
    'Tickets',
    'Staff',
    'Error Logs',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (_isRefreshing) return;
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/users/profile',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) setState(() => _user = data['user']);
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchData);
      if (mounted) {
        setState(() {
          _errorTitle = info.title;
          _errorMessage = info.message;
          _retryAction = info.action;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildHomeContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return ErrorView(
        title: _errorTitle!,
        message: _errorMessage!,
        onRetry: _retryAction,
        isFullScreen: false,
      );
    }

    if (_isLoading) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SkeletonProfile(),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                children: List.generate(9, (_) => const SkeletonStatCard()),
              ),
            ],
          ),
        ),
      );
    }

    final branch = _user?['Branch']?['name'] ?? '';

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFF0A2E5C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProfileHeader(
              username: _user?['username'] ?? 'Technical Staff',
              role: 'Technical Team',
              email: _user?['email'] ?? '',
              phone: _user?['phone'] ?? '',
              branch: branch.isNotEmpty ? branch : null,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.2,
              children: [
                _buildActionCard('Tickets', Icons.support_agent, Colors.blue,
                        () => _navigateTo(1)),
                _buildActionCard('Staff', Icons.people, Colors.green,
                        () => _navigateTo(2)),
                _buildActionCard('Error Logs', Icons.bug_report, Colors.red,
                        () => _navigateTo(3)),
                // ❌ Account Recovery card removed
                _buildActionCard('Payments', Icons.payment, Colors.purple,
                        () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                        const TechnicalPaymentIntegrationsScreen()))),
                _buildActionCard('Security', Icons.security, Colors.indigo,
                        () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                        const TechnicalSecurityAlertsScreen()))),
                _buildActionCard('Suspicious', Icons.warning,
                    Colors.red.shade900,
                        () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                        const TechnicalSuspiciousTransactionsScreen()))),
                _buildActionCard('Maintenance', Icons.settings, Colors.teal,
                        () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                        const TechnicalSystemMaintenanceScreen()))),
                _buildActionCard('Comms', Icons.chat, Colors.cyan,
                        () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                        const TechnicalCommunicationScreen()))),
                _buildActionCard('Profile', Icons.person, Colors.grey,
                        () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                        const TechnicalProfileScreen()))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildActionCard(String title, IconData icon, Color color,
      VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Show More menu ───
  void _showMoreMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final moreItems = [
      {'label': 'Payments', 'icon': Icons.payment,
        'screen': const TechnicalPaymentIntegrationsScreen()},
      {'label': 'Security', 'icon': Icons.security,
        'screen': const TechnicalSecurityAlertsScreen()},
      {'label': 'Suspicious', 'icon': Icons.warning,
        'screen': const TechnicalSuspiciousTransactionsScreen()},
      {'label': 'Maintenance', 'icon': Icons.settings,
        'screen': const TechnicalSystemMaintenanceScreen()},
      {'label': 'Comms', 'icon': Icons.chat,
        'screen': const TechnicalCommunicationScreen()},
      {'label': 'Profile', 'icon': Icons.person,
        'screen': const TechnicalProfileScreen()},
      {'label': 'Settings', 'icon': Icons.settings,
        'screen': const SettingsScreen()},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.3)
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...moreItems.map((item) => Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(item['icon'] as IconData,
                      color: const Color(0xFF0A2E5C)),
                  title: Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => item['screen'] as Widget),
                    );
                  },
                ),
              )),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom Navigation ───
  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.support_agent, 'Tickets', 1),
              _buildNavItem(Icons.people, 'Staff', 2),
              _buildNavItem(Icons.bug_report, 'Errors', 3),
              _buildMoreButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0A2E5C)
                  : (isDark ? Colors.white60 : Colors.grey.shade600),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFF0A2E5C)
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: _showMoreMenu,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.more_horiz, color: Colors.grey, size: 24),
            const SizedBox(height: 2),
            Text(
              'More',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Body based on selected index ───
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const TechnicalTicketsScreen(showAppBar: false);
      case 2:
        return const TechnicalStaffScreen(showAppBar: false);
      case 3:
        return const TechnicalErrorLogsScreen(showAppBar: false);
      default:
        return _buildHomeContent();
    }
  }

  // ─── Build App Bar ───
  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isHome = _selectedIndex == 0;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_ethernet, color: Color(0xFF0A2E5C)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _titles[_selectedIndex],
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0A2E5C),
              ),
            ),
          ),
          if (isHome)
            const NotificationIcon(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        body: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: ErrorView(
                title: _errorTitle!,
                message: _errorMessage!,
                onRetry: _retryAction,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}