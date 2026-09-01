// lib/services/cache_service.dart
import 'dart:convert';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Map: key -> { data, timestamp, ttlSeconds }
  final Map<String, _CacheEntry> _cache = {};

  /// Stores data with a TTL (time‑to‑live) in seconds.
  void set(String key, dynamic data, {int ttlSeconds = 900}) {
    _cache[key] = _CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      ttlSeconds: ttlSeconds,
    );
  }

  /// Retrieves cached data if it hasn’t expired.
  dynamic get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    final isExpired = DateTime.now().difference(entry.timestamp).inSeconds > entry.ttlSeconds;
    if (isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.data;
  }

  /// Removes a specific key from cache.
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Clears all cached data.
  void clearAll() {
    _cache.clear();
  }

  /// Checks if a key exists and is still valid.
  bool isValid(String key) {
    return get(key) != null;
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final int ttlSeconds;

  _CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttlSeconds,
  });
}

/// Predefined TTL values (in seconds)
class CacheTTL {
  static const int profile = 3600;          // 1 hour
  static const int banners = 3600;          // 1 hour
  static const int corporateTargets = 3600; // 1 hour
  static const int promotions = 900;        // 15 minutes
}