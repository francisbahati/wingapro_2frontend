// lib/screens/buyer/buyerDashboardScreen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/error_view.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/notification_icon.dart';
import '../notification_screen.dart';
import 'buyer_orders_screen.dart';
import 'buyer_wallet_screen.dart';
import 'buyer_profile_screen.dart';
import 'buyer_promotions_screen.dart';
import 'buyer_support_screen.dart';
import 'network_packages_screen.dart';
import '../settings_screen.dart';

// ================================================================
// DESIGN TOKENS – SINGLE DARK BLUE THEME
// ================================================================
class _AppColors {
  static const Color primary = Color(0xFF0A2E5C);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color shadow = Color(0x1A000000);
}

// ================================================================
// MAIN SCREEN
// ================================================================
class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({super.key});

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  final CacheService _cache = CacheService();

  // Focus node for the search field
  final FocusNode _searchFocusNode = FocusNode();

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedNetwork = 'All';
  double? _minPrice;
  double? _maxPrice;

  // --- User state ---
  String _username = 'User';
  String _email = '';
  String _phone = 'Not provided';
  double _walletBalance = 0.0;
  List<dynamic> _promotions = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  // --- Network data ---
  static const List<String> _networks = ['Halotel', 'Tigo', 'Vodacom', 'Airtel'];
  static const Map<String, String> _networkImages = {
    'Halotel': 'assets/images/halotel.png',
    'Tigo': 'assets/images/yas.png',
    'Vodacom': 'assets/images/vodacom.png',
    'Airtel': 'assets/images/airtel.png',
  };

  // Flag to prevent multiple loads
  bool _initialLoadDone = false;

  // ================================================================
  // LIFECYCLE
  // ================================================================
  @override
  void initState() {
    super.initState();
    _loadData(forceRefresh: true);
    // Fetch unread notification count after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().fetchUnreadCount();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only run once after the first frame, but avoid triggering on every rebuild
    if (!_initialLoadDone) {
      _initialLoadDone = true;
      _cache.invalidate('user_profile');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ================================================================
  // DATA LOADING
  // ================================================================
  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });

    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      final profile = await _fetchProfile(forceRefresh);
      _updateProfile(profile);

      _promotions = await _fetchPromotions(forceRefresh);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: () => _loadData(forceRefresh: true));
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

  Future<Map<String, dynamic>> _fetchProfile(bool forceRefresh) async {
    final response = await _api.get(
      context,
      '${ApiConfig.baseUrl}/api/users/profile',
      forceRefresh: forceRefresh,
      ttlSeconds: CacheTTL.profile,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['user'] != null) {
        return data['user'];
      }
    }
    throw Exception('Failed to load profile');
  }

  Future<List<dynamic>> _fetchPromotions(bool forceRefresh) async {
    final response = await _api.get(
      context,
      '${ApiConfig.baseUrl}/api/promotions',
      forceRefresh: forceRefresh,
      ttlSeconds: CacheTTL.promotions,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['promotions'] ?? [];
      }
    }
    return [];
  }

  void _updateProfile(Map<String, dynamic> user) {
    setState(() {
      _username = user['username'] ?? 'User';
      _email = user['email'] ?? '';
      _phone = user['phone'] ?? 'Not provided';
      _walletBalance = (user['wallet_balance'] ?? 0.0).toDouble();
    });
  }

  // ================================================================
  // HELPERS
  // ================================================================
  void _navigateToNetworkPackages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NetworkPackagesScreen(
          network: _selectedNetwork == 'All' ? '' : _selectedNetwork,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
        ),
      ),
    );
  }

  void _navigateToWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuyerWalletScreen()),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B1220) : _AppColors.background,
        body: ErrorView(
          title: _errorTitle!,
          message: _errorMessage!,
          onRetry: _retryAction,
          isFullScreen: true,
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B1220) : _AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
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
              username: _username,
              phone: _phone,
            ),
          ),
          // ─── SCROLLABLE CONTENT ───
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              color: _AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // ─── SEARCH & FILTER ───
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _AppColors.shadow,
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Search packages...',
                                hintStyle: TextStyle(color: _AppColors.textLight),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchController.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.search, color: _AppColors.primary),
                                      onPressed: () {
                                        _searchQuery = _searchController.text.trim();
                                        if (_searchQuery.isNotEmpty) {
                                          _searchFocusNode.unfocus();
                                          _navigateToNetworkPackages();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please enter a search term'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                              ),
                              onSubmitted: (query) {
                                _searchQuery = query.trim();
                                if (_searchQuery.isNotEmpty) {
                                  _searchFocusNode.unfocus();
                                  _navigateToNetworkPackages();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter a search term'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ─── FILTER BUTTON (always primary) ───
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: _AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.tune, color: Colors.white),
                            onPressed: () => _showFilterBottomSheet(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BannerCarousel(
                          walletBalance: _walletBalance.toStringAsFixed(0),
                          userName: _username,
                          userPhone: _phone,
                          walletPosition: 'first',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _TrustStrip(isDark: isDark),
                    const SizedBox(height: 28),

                    // ─── Networks Section ───
                    _SectionHeader(
                      title: 'Available Networks',
                      onSeeAll: _navigateToNetworkPackages,
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _networks.length,
                      itemBuilder: (ctx, i) {
                        final network = _networks[i];
                        return GestureDetector(
                          onTap: () {
                            // Set network filter and navigate
                            _selectedNetwork = network;
                            _navigateToNetworkPackages();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _AppColors.shadow,
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                _networkImages[network]!,
                                height: 80,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                const Icon(Icons.signal_cellular_alt, size: 60, color: _AppColors.primary),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // ─── Promotions Section ───
                    _SectionHeader(
                      title: 'Active Promotions',
                      onSeeAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BuyerPromotionsScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_promotions.isEmpty)
                      const Center(
                        child: Text('No active promotions at the moment.',
                            style: TextStyle(color: _AppColors.textSecondary)),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _promotions.length > 3 ? 3 : _promotions.length,
                        itemBuilder: (ctx, i) {
                          final promo = _promotions[i];
                          return _PromotionCard(promo: promo);
                        },
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: const SizedBox.shrink(),
      bottomNavigationBar: _FloatingBottomNav(
        onHomeTap: () {},
        onOrdersTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BuyerOrdersScreen()),
          );
        },
        onWalletTap: _navigateToWallet,
        onOffersTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BuyerPromotionsScreen()),
          );
        },
        onMoreTap: () => _showMoreSheet(context),
      ),
    );
  }

  // ================================================================
  // FILTER & MORE SHEETS
  // ================================================================

  void _showFilterBottomSheet(BuildContext context) {
    // Copy current filter values
    String localNetwork = _selectedNetwork;
    double? localMinPrice = _minPrice;
    double? localMaxPrice = _maxPrice;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('Filter Packages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: localNetwork,
                    decoration: const InputDecoration(
                      labelText: 'Network',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', ..._networks].map((n) {
                      return DropdownMenuItem(value: n, child: Text(n));
                    }).toList(),
                    onChanged: (val) => setStateSheet(() => localNetwork = val!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min Price (TZS)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => localMinPrice = double.tryParse(val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Price (TZS)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => localMaxPrice = double.tryParse(val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setStateSheet(() {
                              localNetwork = 'All';
                              localMinPrice = null;
                              localMaxPrice = null;
                            });
                          },
                          child: const Text('Clear All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Validate min/max
                            if (localMinPrice != null &&
                                localMaxPrice != null &&
                                localMinPrice! > localMaxPrice!) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Minimum price cannot be greater than maximum price'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            // Update parent state
                            setState(() {
                              _selectedNetwork = localNetwork;
                              _minPrice = localMinPrice;
                              _maxPrice = localMaxPrice;
                            });
                            Navigator.pop(ctx);
                            // Navigate with new filters
                            _navigateToNetworkPackages();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── CLEAN MORE SHEET ───
  void _showMoreSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moreItems = [
      {'label': 'Support', 'icon': Icons.support_agent, 'screen': const BuyerSupportScreen()},
      {'label': 'Profile', 'icon': Icons.person, 'screen': const BuyerProfileScreen()},
      {'label': 'Settings', 'icon': Icons.settings, 'screen': const SettingsScreen()},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
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
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.more_horiz,
                        color: _AppColors.primary,
                        size: 22,
                      ),
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
                ...moreItems.map((item) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(
                      item['icon'] as IconData,
                      color: _AppColors.primary,
                    ),
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
                )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// SUB-WIDGETS
// ================================================================

class _HeaderSection extends StatelessWidget {
  final String username;
  final String phone;

  const _HeaderSection({
    required this.username,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _AppColors.primary,
          child: Text(
            _getInitials(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $username',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                phone,
                style: TextStyle(
                  fontSize: 14,
                  color: _AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
    return username.isNotEmpty ? username[0].toUpperCase() : 'U';
  }
}

class _TrustStrip extends StatelessWidget {
  final bool isDark;

  const _TrustStrip({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final principles = [
      {'icon': Icons.security_rounded, 'label': 'Trusted'},
      {'icon': Icons.lock_outline_rounded, 'label': 'Secure'},
      {'icon': Icons.verified_rounded, 'label': 'Verified'},
      {'icon': Icons.support_agent_rounded, 'label': '24/7 Support'},
      {'icon': Icons.trending_up_rounded, 'label': 'Best Value'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: _AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: principles.map((p) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(p['icon'] as IconData, color: _AppColors.primary, size: 18),
              ),
              const SizedBox(height: 4),
              Text(
                p['label'] as String,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _AppColors.textPrimary,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See All',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PromotionCard extends StatelessWidget {
  final Map<dynamic, dynamic> promo;

  const _PromotionCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final package = promo['Package'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo['title'] ?? 'Special Offer',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  promo['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: _AppColors.textSecondary,
                  ),
                ),
                if (promo['discount'] != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '-${promo['discount']}% OFF',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _AppColors.primary,
                      ),
                    ),
                  ),
                if (package != null)
                  Text(
                    '${package['name']} · TZS ${package['displayPrice']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _AppColors.textSecondary,
                    ),
                  ),
                if (promo['validUntil'] != null)
                  Text(
                    'Valid until ${DateFormat('dd MMM yyyy').format(DateTime.parse(promo['validUntil']))}',
                    style: TextStyle(
                      fontSize: 10,
                      color: _AppColors.textLight,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: _AppColors.textLight),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuyerPromotionsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── FLOATING BOTTOM NAVIGATION – ALL ICONS DARK BLUE ───
class _FloatingBottomNav extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onOrdersTap;
  final VoidCallback onWalletTap;
  final VoidCallback onOffersTap;
  final VoidCallback onMoreTap;

  const _FloatingBottomNav({
    required this.onHomeTap,
    required this.onOrdersTap,
    required this.onWalletTap,
    required this.onOffersTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {'label': 'Home', 'icon': Icons.home, 'onTap': onHomeTap},
      {'label': 'Orders', 'icon': Icons.receipt_long, 'onTap': onOrdersTap},
      {'label': 'Wallet', 'icon': Icons.account_balance_wallet, 'onTap': onWalletTap},
      {'label': 'Offers', 'icon': Icons.local_offer, 'onTap': onOffersTap},
      {'label': 'More', 'icon': Icons.more_horiz, 'onTap': onMoreTap},
    ];

    int selectedIndex = 0;

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
          children: items.asMap().entries.map((entry) {
            int index = entry.key;
            var item = entry.value;
            bool isSelected = index == selectedIndex;
            return Expanded(
              child: GestureDetector(
                onTap: item['onTap'] as VoidCallback,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color: _AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['label'] as String,
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