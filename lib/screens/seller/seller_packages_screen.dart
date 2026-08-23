// lib/screens/seller/seller_packages_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class SellerPackagesScreen extends StatefulWidget {
  final bool showAppBar;
  const SellerPackagesScreen({super.key, this.showAppBar = true});

  @override
  State<SellerPackagesScreen> createState() => _SellerPackagesScreenState();
}

class _SellerPackagesScreenState extends State<SellerPackagesScreen>
    with TickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _adoptedPackages = [];
  List<dynamic> _availablePackages = [];
  bool _isLoading = true;
  bool _loadingAvailable = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  late TabController _tabController;

  double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _fetchPackages();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPackages() async {
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
        '${ApiConfig.baseUrl}/api/seller/packages',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _adoptedPackages = data['packages'] ?? [];
            _isLoading = false;
          });
          _fetchAvailablePackages(silent: true);
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load packages',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchPackages);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAvailablePackages({bool silent = false}) async {
    if (!silent) setState(() => _loadingAvailable = true);
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/seller/available-packages',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _availablePackages = data['packages'] ?? [];
            _loadingAvailable = false;
          });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load available packages',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!silent) {
        showErrorSnackbar(context, e);
      }
      setState(() => _loadingAvailable = false);
    }
  }

  Future<void> _adoptPackage(int packageId) async {
    try {
      final token = await _auth.getToken();
      final response = await _api.post(
        context,
        '${ApiConfig.baseUrl}/api/seller/packages/$packageId/adopt',
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package adopted!'), backgroundColor: Colors.green),
        );
        await _fetchPackages();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Adoption failed',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    }
  }

  Future<void> _unadoptPackage(int packageId, String packageName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Package'),
        content: Text(
          'Are you sure you want to remove "$packageName" from your adopted packages?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final token = await _auth.getToken();
      final response = await _api.delete(
        context,
        '${ApiConfig.baseUrl}/api/seller/packages/$packageId/unadopt',
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package removed'), backgroundColor: Colors.green),
        );
        await _fetchPackages();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Failed to remove',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
        ? ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => const SkeletonListTile(),
    )
        : _errorTitle != null
        ? ErrorView(
      title: _errorTitle!,
      message: _errorMessage!,
      onRetry: _retryAction,
      isFullScreen: false,
    )
        : RefreshIndicator(
      onRefresh: _fetchPackages,
      color: const Color(0xFF0A2E5C),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            color: isDark
                ? Colors.grey.shade800.withOpacity(0.5)
                : Colors.grey.shade50,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Adopted'),
                      Tab(text: 'Available'),
                    ],
                    indicatorColor: const Color(0xFF0A2E5C),
                    labelColor: isDark ? Colors.white
                        : const Color(0xFF0A2E5C),
                    unselectedLabelColor: isDark
                        ? Colors.white60
                        : Colors.grey,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh,
                      color: Color(0xFF0A2E5C)),
                  onPressed: _fetchPackages,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Adopted
                _adoptedPackages.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64,
                          color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                          'No adopted packages yet.'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            _tabController.animateTo(1),
                        child: const Text(
                            'Browse available packages'),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _adoptedPackages.length,
                  itemBuilder: (ctx, i) {
                    final p = _adoptedPackages[i];
                    final price = _parsePrice(p['price']);
                    return GlassCard(
                      backgroundColor: isDark
                          ? const Color(0xFF0A1A2B)
                          .withOpacity(0.85)
                          : Colors.white.withOpacity(0.85),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'] ?? 'Package',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            if (p['description'] != null &&
                                p['description'].isNotEmpty)
                              Padding(
                                padding:
                                const EdgeInsets.only(
                                    top: 4),
                                child: Text(
                                  p['description'],
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildInfoChip(
                                  icon: Icons.attach_money,
                                  label:
                                  'TZS ${NumberFormat('#,###').format(price)}',
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoChip(
                                  icon: Icons.data_usage,
                                  label:
                                  p['dataSize'] ?? 'N/A',
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoChip(
                                  icon: Icons.timer,
                                  label:
                                  p['validity'] ?? 'N/A',
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Network: ${p['network']}',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment:
                              Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _unadoptPackage(
                                      p['id'],
                                      p['name'] ?? 'Package',
                                    ),
                                icon: const Icon(
                                    Icons.remove_circle,
                                    size: 18,
                                    color: Colors.red),
                                label: const Text('Unadopt'),
                                style: OutlinedButton
                                    .styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(
                                      color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(
                                        20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Available
                _loadingAvailable
                    ? const Center(
                    child: CircularProgressIndicator())
                    : _availablePackages.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64,
                          color: Colors.green),
                      const SizedBox(height: 16),
                      const Text(
                          'All packages adopted!'),
                      const SizedBox(height: 8),
                      const Text(
                          'Come back later for new offers.'),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _availablePackages.length,
                  itemBuilder: (ctx, i) {
                    final p = _availablePackages[i];
                    final price = _parsePrice(p['price']);
                    return GlassCard(
                      backgroundColor: isDark
                          ? const Color(0xFF0A1A2B)
                          .withOpacity(0.85)
                          : Colors.white.withOpacity(0.85),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'] ?? 'Package',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            if (p['description'] !=
                                null &&
                                p['description']
                                    .isNotEmpty)
                              Padding(
                                padding:
                                const EdgeInsets.only(
                                    top: 4),
                                child: Text(
                                  p['description'],
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey
                                        .shade600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildInfoChip(
                                  icon: Icons.attach_money,
                                  label:
                                  'TZS ${NumberFormat('#,###').format(price)}',
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoChip(
                                  icon: Icons.data_usage,
                                  label: p['dataSize'] ??
                                      'N/A',
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoChip(
                                  icon: Icons.timer,
                                  label: p['validity'] ??
                                      'N/A',
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Network: ${p['network']}',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey
                                    .shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment:
                              Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _adoptPackage(
                                        p['id']),
                                icon: const Icon(Icons.add),
                                label: const Text('Adopt'),
                                style: ElevatedButton
                                    .styleFrom(
                                  backgroundColor:
                                  const Color(
                                      0xFF0A2E5C),
                                  foregroundColor:
                                  Colors.white,
                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Packages'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }

  Widget _buildInfoChip(
      {required IconData icon, required String label, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16,
              color: isDark ? Colors.white60 : Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade700)),
        ],
      ),
    );
  }
}