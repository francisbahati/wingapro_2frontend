// lib/screens/seller/seller_dashboard_screen.dart
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
import 'seller_packages_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_wallet_screen.dart';
import 'seller_profile_screen.dart';
import 'seller_earnings_screen.dart';
import 'seller_sales_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _stats;
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Seller Dashboard',
    'Packages',
    'Orders',
    'Wallet',
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
        '${ApiConfig.baseUrl}/api/seller/stats',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _userData = data['user'];
              _stats = data['stats'];
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load stats',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
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
                children: List.generate(4, (_) => const SkeletonStatCard()),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFF0A2E5C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProfileHeader(
              username: _userData?['username'] ?? 'Seller',
              role: 'Seller',
              email: _userData?['email'] ?? '',
              phone: _userData?['phone'] ?? '',
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
                _buildStatCard('Packages', _stats?['totalPackages'] ?? 0,
                    Icons.wifi, Colors.blue),
                _buildStatCard('Orders', _stats?['totalOrders'] ?? 0,
                    Icons.shopping_bag, Colors.orange),
                _buildStatCard('Earnings',
                    'TZS ${_stats?['totalEarnings'] ?? 0}', Icons.attach_money,
                    Colors.green),
                _buildStatCard('Balance',
                    'TZS ${_userData?['wallet_balance'] ?? 0}',
                    Icons.account_balance_wallet, Colors.purple),
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
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300.withValues(alpha: 0.5),
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

  void _showMoreMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final moreItems = [
      {'label': 'Earnings', 'icon': Icons.attach_money, 'screen': const SellerEarningsScreen()},
      {'label': 'Sales', 'icon': Icons.trending_up, 'screen': const SellerSalesScreen()},
      {'label': 'Profile', 'icon': Icons.person, 'screen': const SellerProfileScreen()},
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
              ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300.withValues(alpha: 0.5),
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
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.grey.shade400,
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
              _buildNavItem(Icons.wifi, 'Packages', 1),
              _buildNavItem(Icons.shopping_bag, 'Orders', 2),
              _buildNavItem(Icons.account_balance_wallet, 'Wallet', 3),
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

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const SellerPackagesScreen(showAppBar: false);
      case 2:
        return const SellerOrdersScreen(showAppBar: false);
      case 3:
        return const SellerWalletScreen(showAppBar: false);
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        body: Column(
          children: [
            Container(
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
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.store, color: Color(0xFF0A2E5C)),
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
                  const NotificationIcon(),
                ],
              ),
            ),
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
          Container(
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
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.store, color: Color(0xFF0A2E5C)),
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
                const NotificationIcon(),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}