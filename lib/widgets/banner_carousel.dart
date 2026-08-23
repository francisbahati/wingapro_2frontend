// lib/widgets/banner_carousel.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../models/banner_model.dart' as BannerModel;
import '../services/cache_service.dart'; // NEW

class BannerCarousel extends StatefulWidget {
  final String? walletBalance;
  final String? userName;
  final String? userPhone;
  final String walletPosition;

  const BannerCarousel({
    super.key,
    this.walletBalance,
    this.userName,
    this.userPhone,
    this.walletPosition = 'first',
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  final CacheService _cache = CacheService(); // NEW
  int _currentPage = 0;
  int _totalPages = 1;
  List<BannerModel.Banner> _banners = [];
  bool _loading = true;
  String? _error;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients && mounted) {
        final nextPage = (_currentPage + 1) % _totalPages;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchBanners({bool forceRefresh = false}) async {
    setState(() => _loading = true);

    try {
      // 1️⃣ Try cache first
      String? cached = _cache.get('banners');
      if (cached != null && !forceRefresh) {
        final data = jsonDecode(cached);
        final list = data['banners'] as List? ?? [];
        setState(() {
          _banners = list.map((json) => BannerModel.Banner.fromJson(json)).toList();
          _totalPages = _banners.length + 1;
          _loading = false;
        });
        return;
      }

      // 2️⃣ Fetch from network
      final url = '${ApiConfig.baseUrl}/api/banners';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['banners'] as List? ?? [];
          // Store in cache
          _cache.set('banners', jsonEncode({'banners': list}), ttlSeconds: CacheTTL.banners);

          setState(() {
            _banners = list.map((json) => BannerModel.Banner.fromJson(json)).toList();
            _totalPages = _banners.length + 1;
            _loading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load banners');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error loading banners: $_error'),
              TextButton(
                onPressed: () => _fetchBanners(forceRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Wallet card
    final walletCard = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A2E5C), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '💰 Wallet Balance',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'TZS ${widget.walletBalance ?? '0'}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.userName != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.userName!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Banner widgets
    final bannerWidgets = _banners.map((banner) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              banner.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('Image not available'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();

    // Combine children
    List<Widget> children;
    if (widget.walletPosition == 'first') {
      children = [walletCard, ...bannerWidgets];
    } else {
      children = [...bannerWidgets, walletCard];
    }

    if (_banners.isEmpty) {
      children = [walletCard];
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _autoScrollTimer?.cancel();
              _startAutoScroll();
            },
            children: children,
          ),
        ),
        const SizedBox(height: 12),
        SmoothPageIndicator(
          controller: _pageController,
          count: children.length,
          effect: ExpandingDotsEffect(
            activeDotColor: Theme.of(context).primaryColor,
            dotHeight: 8,
            dotWidth: 8,
            expansionFactor: 3,
            dotColor: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}