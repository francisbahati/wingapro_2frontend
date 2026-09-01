// lib/screens/admin/admin_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
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
// import 'admin_account_recovery_screen.dart'; // ❌ REMOVED
import 'admin_corporate_targets_screen.dart';
import 'admin_wallet_overview_screen.dart';
import 'admin_sellers_screen.dart';
import 'admin_withdrawals_screen.dart';
import '../settings_screen.dart';

// ================================================================
// DESIGN TOKENS – MATCH BUYER DASHBOARD
// ================================================================
class _AppColors {
  static const Color primary = Color(0xFF0A2E5C);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color shadow = Color(0x1A000000);
}

// ================================================================
// MAIN SCREEN
// ================================================================
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
  int _pendingWithdrawals = 0;

  // Bottom navigation state
  int _selectedIndex = 0;
  final List<String> _titles = [
    'Admin Panel',
    'Manage Packages',
    'Manage Users',
    'All Transactions',
  ];

  // Screens for tabs 1,2,3 (home is handled separately)
  final List<Widget> _tabScreens = [
    const AdminPackagesScreen(showAppBar: false),
    const AdminUsersScreen(showAppBar: false),
    const AdminTransactionsScreen(showAppBar: false),
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchPendingWithdrawals();
  }

  Future<void> _fetchPendingWithdrawals() async {
    try {
      final token = await _auth.getToken();
      if (token == null) return;
      final response = await _api.adminGetPendingWithdrawalCount(context);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) setState(() => _pendingWithdrawals = data['count'] ?? 0);
        }
      }
    } catch (_) {}
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
        if (data['success'] == true) {
          if (mounted) setState(() => _user = data['user']);
        }
      }
      if (statsRes.statusCode == 200) {
        final data = jsonDecode(statsRes.body);
        if (data['success'] == true) {
          if (mounted) setState(() => _stats = data['stats']);
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

  // ================================================================
  // MORE BUTTON BOTTOM SHEET – FIXED OVERFLOW
  // ================================================================
  void _showMoreSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final moreItems = [
      {'label': 'Branches', 'icon': Icons.store, 'screen': const AdminBranchesScreen()},
      {'label': 'Purchases', 'icon': Icons.shopping_cart, 'screen': const AdminPurchasesScreen()},
      {'label': 'Staff', 'icon': Icons.people_outline, 'screen': const AdminStaffScreen()},
      {'label': 'Tickets', 'icon': Icons.support_agent, 'screen': const AdminTicketsScreen()},
      {'label': 'Promotions', 'icon': Icons.local_offer, 'screen': const AdminPromotionsScreen()},
      {'label': 'Escrow', 'icon': Icons.account_balance, 'screen': const AdminEscrowScreen()},
      {'label': 'Price Management', 'icon': Icons.attach_money, 'screen': const AdminPriceManagementScreen()},
      {'label': 'Banners', 'icon': Icons.image, 'screen': const AdminBannersScreen()},
      {'label': 'Announcements', 'icon': Icons.announcement, 'screen': const AdminAnnouncementsScreen()},
      // ❌ Account Recovery removed
      {'label': 'Corporate Targets', 'icon': Icons.track_changes, 'screen': const AdminCorporateTargetsScreen()},
      {'label': 'Wallet Overview', 'icon': Icons.account_balance_wallet, 'screen': const AdminWalletOverviewScreen()},
      {'label': 'Sellers', 'icon': Icons.storefront, 'screen': const AdminSellersScreen()},
      {'label': 'Withdrawals', 'icon': Icons.currency_exchange, 'screen': const AdminWithdrawalsScreen()},
      {'label': 'Profile', 'icon': Icons.person, 'screen': const AdminProfileScreen()},
      {'label': 'Settings', 'icon': Icons.settings, 'screen': const SettingsScreen()},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.10) : _AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag indicator
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.more_horiz, color: _AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'More Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : _AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(
                          Icons.close,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: moreItems.length,
                    itemBuilder: (context, index) {
                      final item = moreItems[index];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(item['icon'] as IconData, color: _AppColors.primary),
                          title: Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white : _AppColors.textPrimary,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => item['screen'] as Widget),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isHome = _selectedIndex == 0;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B1220) : _AppColors.background,
        body: Column(
          children: [
            // Fixed header
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                bottom: 12,
              ),
              color: isDark ? const Color(0xFF0B1220) : _AppColors.background,
              child: _HeaderSection(
                username: _user?['username'] ?? 'Admin',
                phone: _user?['phone'] ?? '',
                role: 'Administrator',
                title: 'Admin Panel',
                showAvatar: true,
                showBackButton: false,
              ),
            ),
            Expanded(
              child: ErrorView(
                title: _errorTitle!,
                message: _errorMessage!,
                onRetry: _retryAction,
                isFullScreen: false,
              ),
            ),
          ],
        ),
      );
    }

    // Build body based on selected index
    Widget body;
    if (_selectedIndex == 0) {
      body = _AdminHomeContent(
        stats: _stats,
        user: _user,
        onRefresh: _fetchData,
      );
    } else {
      final index = _selectedIndex - 1;
      body = _tabScreens[index];
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : _AppColors.background,
      body: Column(
        children: [
          // ─── FIXED HEADER ───
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 20,
              bottom: 12,
            ),
            color: isDark ? const Color(0xFF0B1220) : _AppColors.background,
            child: _HeaderSection(
              username: _user?['username'] ?? 'Admin',
              phone: _user?['phone'] ?? '',
              role: 'Administrator',
              title: _titles[_selectedIndex],
              showAvatar: isHome,
              showBackButton: !isHome,
              onBackPressed: () {
                setState(() => _selectedIndex = 0);
              },
              titleStyle: isHome
                  ? null
                  : const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _AppColors.textPrimary,
              ),
            ),
          ),
          // ─── SCROLLABLE CONTENT ───
          Expanded(
            child: body,
          ),
        ],
      ),
      // ─── FLOATING BOTTOM NAVIGATION ───
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: const SizedBox.shrink(),
      bottomNavigationBar: _FloatingBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() => _selectedIndex = index);
        },
        pendingWithdrawals: _pendingWithdrawals,
        onMoreTap: () => _showMoreSheet(context),
      ),
    );
  }
}

// ================================================================
// ADMIN HOME CONTENT
// ================================================================
class _AdminHomeContent extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? user;
  final Future<void> Function() onRefresh;

  const _AdminHomeContent({
    required this.stats,
    required this.user,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  title: 'Users',
                  value: stats?['totalUsers'] ?? 0,
                  icon: Icons.people,
                  color: Colors.blue,
                  isDark: isDark,
                ),
                _StatCard(
                  title: 'Active',
                  value: stats?['activeUsers'] ?? 0,
                  icon: Icons.person_outline,
                  color: Colors.green,
                  isDark: isDark,
                ),
                _StatCard(
                  title: 'Packages',
                  value: stats?['totalPackages'] ?? 0,
                  icon: Icons.wifi,
                  color: Colors.orange,
                  isDark: isDark,
                ),
                _StatCard(
                  title: 'Purchases',
                  value: stats?['totalPurchases'] ?? 0,
                  icon: Icons.shopping_cart,
                  color: Colors.purple,
                  isDark: isDark,
                ),
                _StatCard(
                  title: 'Revenue',
                  value: 'TZS ${NumberFormat('#,###').format(stats?['totalRevenue'] ?? 0)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                  isDark: isDark,
                ),
                _StatCard(
                  title: 'Branches',
                  value: stats?['totalBranches'] ?? 0,
                  icon: Icons.store,
                  color: Colors.indigo,
                  isDark: isDark,
                ),
                _StatCard(
                  title: 'Tickets',
                  value: stats?['openTickets'] ?? 0,
                  icon: Icons.support_agent,
                  color: Colors.red,
                  isDark: isDark,
                ),
                _StatCard(
                  title: 'Staff',
                  value: stats?['totalStaff'] ?? 0,
                  icon: Icons.people_outline,
                  color: Colors.teal,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// STAT CARD
// ================================================================
class _StatCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
}

// ================================================================
// HEADER SECTION
// ================================================================
class _HeaderSection extends StatelessWidget {
  final String username;
  final String phone;
  final String role;
  final String title;
  final bool showAvatar;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final TextStyle? titleStyle;

  const _HeaderSection({
    required this.username,
    required this.phone,
    this.role = 'Administrator',
    this.title = 'Admin Panel',
    this.showAvatar = true,
    this.showBackButton = false,
    this.onBackPressed,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isHome = title == 'Admin Panel' && showAvatar;

    return Row(
      children: [
        if (showBackButton)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: onBackPressed,
            color: _AppColors.primary,
          ),
        if (showAvatar) ...[
          CircleAvatar(
            radius: 24,
            backgroundColor: _AppColors.primary,
            child: Text(
              _getInitials(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: titleStyle ??
                    TextStyle(
                      fontSize: isHome ? 16 : 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : _AppColors.textPrimary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isHome) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      phone.isNotEmpty ? phone : role,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : _AppColors.textSecondary,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white70 : _AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : _AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        // Always show notification icon
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _AppColors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const NotificationIcon(),
        ),
      ],
    );
  }

  String _getInitials() {
    final parts = username.split(' ');
    if (parts.length >= 2) {
      return parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : 'A';
  }
}

// ================================================================
// FLOATING BOTTOM NAVIGATION
// ================================================================
class _FloatingBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final int pendingWithdrawals;
  final VoidCallback onMoreTap;

  const _FloatingBottomNav({
    required this.selectedIndex,
    required this.onItemTapped,
    this.pendingWithdrawals = 0,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {'label': 'Home', 'icon': Icons.home, 'index': 0},
      {'label': 'Packages', 'icon': Icons.wifi, 'index': 1},
      {'label': 'Users', 'icon': Icons.people, 'index': 2},
      {'label': 'Transactions', 'icon': Icons.receipt_long, 'index': 3},
      {'label': 'More', 'icon': Icons.more_horiz, 'index': 4},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final index = item['index'] as int;
            final isSelected = index == selectedIndex;
            final label = item['label'] as String;
            final icon = item['icon'] as IconData;

            if (label == 'More') {
              return Expanded(
                child: GestureDetector(
                  onTap: onMoreTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            color: _AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (pendingWithdrawals > 0)
                        Positioned(
                          right: -8,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              pendingWithdrawals > 9 ? '9+' : '$pendingWithdrawals',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => onItemTapped(index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: _AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: _AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}