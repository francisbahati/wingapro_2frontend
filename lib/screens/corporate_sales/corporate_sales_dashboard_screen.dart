// lib/screens/corporate_sales/corporate_sales_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
import 'corporate_sales_clients_screen.dart';
import 'corporate_sales_sellers_screen.dart';
import 'corporate_sales_reports_screen.dart';
import 'corporate_sales_profile_screen.dart';

class CorporateSalesDashboardScreen extends StatefulWidget {
  const CorporateSalesDashboardScreen({super.key});

  @override
  State<CorporateSalesDashboardScreen> createState() =>
      _CorporateSalesDashboardScreenState();
}

class _CorporateSalesDashboardScreenState
    extends State<CorporateSalesDashboardScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _user;
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Corporate Sales',
    'Clients',
    'Sellers',
    'Reports',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      final profileRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/corporate-sales/profile',
      );
      final statsRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/corporate-sales/stats',
      );

      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body);
        if (data['success'] == true) {
          setState(() => _user = data['user']);
        }
      }
      if (statsRes.statusCode == 200) {
        final data = jsonDecode(statsRes.body);
        if (data['success'] == true) {
          setState(() => _stats = data['stats']);
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchData);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
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
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                children: List.generate(4, (_) => const SkeletonStatCard()),
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
              username: _user?['username'] ?? 'Corporate Sales',
              role: 'Corporate Sales',
              email: _user?['email'] ?? '',
              phone: _user?['phone'] ?? '',
              branch: branch.isNotEmpty ? branch : null,
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.2,
              children: [
                _buildStatCard('Clients', _stats?['totalClients'] ?? 0,
                    Icons.business, Colors.blue),
                _buildStatCard('Active Clients', _stats?['activeClients'] ?? 0,
                    Icons.check_circle, Colors.green),
                _buildStatCard('Sellers', _stats?['totalSellers'] ?? 0,
                    Icons.store, Colors.orange),
                _buildStatCard('Products', _stats?['totalProducts'] ?? 0,
                    Icons.wifi, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, dynamic value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = value is String ? value : value.toString();
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A1A2B).withOpacity(0.85)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade300.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
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
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Show More menu ───
  void _showMoreMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final moreItems = [
      {'label': 'Profile', 'icon': Icons.person, 'screen': const CorporateSalesProfileScreen()},
      {'label': 'Settings', 'icon': Icons.settings, 'screen': const SettingsScreen()},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0A1A2B).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade300.withOpacity(0.5),
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
                  color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...moreItems.map((item) => Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(item['icon'] as IconData, color: const Color(0xFF0A2E5C)),
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
            ? const Color(0xFF0A1A2B).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
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
              _buildNavItem(Icons.business, 'Clients', 1),
              _buildNavItem(Icons.store, 'Sellers', 2),
              _buildNavItem(Icons.assessment, 'Reports', 3),
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
              color: isSelected ? const Color(0xFF0A2E5C) : (isDark ? Colors.white60 : Colors.grey.shade600),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFF0A2E5C) : (isDark ? Colors.white60 : Colors.grey.shade600),
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
        return const CorporateSalesClientsScreen(showAppBar: false);
      case 2:
        return const CorporateSalesSellersScreen(showAppBar: false);
      case 3:
        return const CorporateSalesReportsScreen(showAppBar: false);
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
            ? const Color(0xFF0A1A2B).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.corporate_fare, color: Color(0xFF0A2E5C)),
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