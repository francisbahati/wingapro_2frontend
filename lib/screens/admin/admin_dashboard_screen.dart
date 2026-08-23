// lib/screens/admin/admin_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/profile_header.dart';
import '../../widgets/role_navigation.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/error_view.dart';
import '../../widgets/notification_icon.dart';
import '../notification_screen.dart';
import 'admin_users_screen.dart';
import 'admin_branches_screen.dart';
import 'admin_packages_screen.dart';
import 'admin_purchases_screen.dart';
import 'admin_tickets_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_price_management_screen.dart';
import 'admin_escrow_screen.dart';
import 'admin_promotions_screen.dart';
import 'admin_banners_screen.dart';
import 'admin_transactions_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_account_recovery_screen.dart';
import 'admin_corporate_targets_screen.dart';
import 'admin_wallet_overview_screen.dart'; // ✅ New
import 'admin_sellers_screen.dart'; // ✅ New

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _user;

  // Bottom navigation
  int _selectedIndex = 0;

  // Titles for each tab
  final List<String> _titles = [
    'Admin Panel',
    'Packages',
    'Users',
    'Transactions',
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
        '${ApiConfig.baseUrl}/api/users/profile',
      );
      final statsRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/admin/stats',
      );

      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body);
        if (data['success'] == true) setState(() => _user = data['user']);
      }
      if (statsRes.statusCode == 200) {
        final data = jsonDecode(statsRes.body);
        if (data['success'] == true) setState(() => _stats = data['stats']);
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
    if (_isLoading) return _buildLoadingState();

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: Theme.of(context).primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProfileHeader(
              username: _user?['username'] ?? 'Admin',
              role: 'Administrator',
              email: _user?['email'] ?? '',
              phone: _user?['phone'] ?? '',
              showChangeAvatar: false,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard('Users', _stats?['totalUsers'] ?? 0, Icons.people,
                    Colors.blue),
                _buildStatCard('Active', _stats?['activeUsers'] ?? 0,
                    Icons.person_outline, Colors.green),
                _buildStatCard('Packages', _stats?['totalPackages'] ?? 0,
                    Icons.wifi, Colors.orange),
                _buildStatCard('Purchases', _stats?['totalPurchases'] ?? 0,
                    Icons.shopping_cart, Colors.purple),
                _buildStatCard(
                    'Revenue',
                    'TZS ${NumberFormat('#,###').format(_stats?['totalRevenue'] ?? 0)}',
                    Icons.attach_money,
                    Colors.green),
                _buildStatCard('Branches', _stats?['totalBranches'] ?? 0,
                    Icons.store, Colors.indigo),
                _buildStatCard('Tickets', _stats?['openTickets'] ?? 0,
                    Icons.support_agent, Colors.red),
                _buildStatCard('Staff', _stats?['totalStaff'] ?? 0,
                    Icons.people_outline, Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
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
              childAspectRatio: 1.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(8, (_) => const SkeletonStatCard()),
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

  // ─── Bottom Navigation ───
  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final moreItems = [
      MoreItem(
        label: 'Branches',
        icon: Icons.store,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminBranchesScreen())),
      ),
      MoreItem(
        label: 'Purchases',
        icon: Icons.shopping_cart,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminPurchasesScreen())),
      ),
      MoreItem(
        label: 'Staff',
        icon: Icons.people_outline,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminStaffScreen())),
      ),
      MoreItem(
        label: 'Tickets',
        icon: Icons.support_agent,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminTicketsScreen())),
      ),
      MoreItem(
        label: 'Promotions',
        icon: Icons.local_offer,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminPromotionsScreen())),
      ),
      MoreItem(
        label: 'Escrow',
        icon: Icons.account_balance,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminEscrowScreen())),
      ),
      MoreItem(
        label: 'Price Management',
        icon: Icons.attach_money,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminPriceManagementScreen())),
      ),
      MoreItem(
        label: 'Banners',
        icon: Icons.image,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminBannersScreen())),
      ),
      MoreItem(
        label: 'Transactions',
        icon: Icons.receipt_long,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminTransactionsScreen())),
      ),
      MoreItem(
        label: 'Announcements',
        icon: Icons.announcement,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAnnouncementsScreen())),
      ),
      MoreItem(
        label: 'Account Recovery',
        icon: Icons.lock_reset,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAccountRecoveryScreen())),
      ),
      MoreItem(
        label: 'Corporate Targets',
        icon: Icons.track_changes,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminCorporateTargetsScreen())),
      ),
      // ✅ NEW: Wallet Overview
      MoreItem(
        label: 'Wallet Overview',
        icon: Icons.account_balance_wallet,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminWalletOverviewScreen())),
      ),
      // ✅ NEW: Sellers
      MoreItem(
        label: 'Sellers',
        icon: Icons.storefront,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminSellersScreen())),
      ),
      MoreItem(
        label: 'Profile',
        icon: Icons.person,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminProfileScreen())),
      ),
    ];

    return RoleNavigation(
      items: [
        NavItem(label: 'Home', icon: Icons.home, screen: _buildHomeContent()),
        NavItem(
            label: 'Packages',
            icon: Icons.wifi,
            screen: const AdminPackagesScreen()),
        NavItem(
            label: 'Users', icon: Icons.people, screen: const AdminUsersScreen()),
        NavItem(
            label: 'Transactions',
            icon: Icons.receipt_long,
            screen: const AdminTransactionsScreen()),
      ],
      moreItems: moreItems,
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
            // Fixed App Bar
            Container(
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
                  const Icon(Icons.admin_panel_settings, color: Color(0xFF0A2E5C)),
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
            // Error Body
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
          // Fixed App Bar
          Container(
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
                const Icon(Icons.admin_panel_settings, color: Color(0xFF0A2E5C)),
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
          // Body with bottom navigation
          Expanded(
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }
}