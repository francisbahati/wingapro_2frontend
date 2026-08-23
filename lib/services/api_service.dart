// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'error_handler.dart';

/// Simple in-memory cache entry with TTL
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final int ttlSeconds;

  _CacheEntry({required this.data, required this.timestamp, required this.ttlSeconds});

  bool get isExpired => DateTime.now().difference(timestamp).inSeconds > ttlSeconds;
}

class ApiService {
  final AuthService _auth = AuthService();
  final ConnectivityService _connectivity = ConnectivityService();

  // Cache storage: key -> _CacheEntry
  final Map<String, _CacheEntry> _cache = {};

  // Default TTL for GET requests (5 minutes)
  static const int _defaultTtlSeconds = 300;

  // ============================================================
  // CACHE HELPERS
  // ============================================================

  /// Build cache key from URL (optionally include query parameters)
  String _buildCacheKey(String url) => url;

  /// Get cached data if valid, else null
  dynamic _getCached(String url) {
    final key = _buildCacheKey(url);
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.data;
  }

  /// Store data in cache with optional TTL (default 5 minutes)
  void _setCached(String url, dynamic data, {int? ttlSeconds}) {
    final key = _buildCacheKey(url);
    _cache[key] = _CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      ttlSeconds: ttlSeconds ?? _defaultTtlSeconds,
    );
  }

  /// Invalidate a specific URL from cache
  void invalidateCache(String url) {
    final key = _buildCacheKey(url);
    _cache.remove(key);
  }

  /// Invalidate all cache entries that start with a given path prefix
  void invalidateCachePrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear entire cache
  void clearCache() {
    _cache.clear();
  }

  // ============================================================
  // CORE REQUEST HANDLER WITH CACHING
  // ============================================================

  /// GET with caching: returns cached response if fresh and not forced refresh.
  /// The response body is stored as a string (raw) to replay exactly.
  Future<http.Response> _safeRequestWithCache(
      BuildContext context,
      String url,
      Future<http.Response> Function() requestFn, {
        bool forceRefresh = false,
        int? ttlSeconds,
      }) async {
    // 1. Check connectivity
    if (!await _connectivity.checkConnectivity()) {
      throw ApiException(
        statusCode: null,
        message: 'No internet connection. Please check your network.',
      );
    }

    // 2. Try cache if not forced refresh
    if (!forceRefresh) {
      final cachedData = _getCached(url);
      if (cachedData != null) {
        // Reconstruct http.Response from cached data
        // We'll store body string, statusCode, headers
        final body = cachedData['body'] as String? ?? '';
        final statusCode = cachedData['statusCode'] as int? ?? 200;
        final headers = Map<String, String>.from(cachedData['headers'] ?? {});
        return http.Response(body, statusCode, headers: headers);
      }
    }

    try {
      final response = await requestFn();

      // 3. Cache successful responses (2xx)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final cacheData = {
          'body': response.body,
          'statusCode': response.statusCode,
          'headers': response.headers,
        };
        _setCached(url, cacheData, ttlSeconds: ttlSeconds);
      }

      // 4. Handle HTTP status codes (same as before)
      if (response.statusCode >= 400) {
        String errorMessage = '';
        try {
          final body = jsonDecode(response.body);
          errorMessage = body['message'] ?? body['error'] ?? 'An error occurred.';
        } catch (_) {
          errorMessage = 'Server error (${response.statusCode}).';
        }

        if (response.statusCode == 429) {
          throw ApiException(
            statusCode: 429,
            message: errorMessage.isNotEmpty
                ? errorMessage
                : 'Too many requests. Please try again later.',
          );
        }

        throw ApiException(
          statusCode: response.statusCode,
          message: errorMessage,
        );
      }
      return response;
    } on ApiException {
      rethrow;
    } on SocketException catch (_) {
      throw ApiException(
        statusCode: null,
        message: 'No internet connection. Please check your network.',
      );
    } on TimeoutException catch (_) {
      throw ApiException(
        statusCode: null,
        message: 'Connection timed out. Please try again.',
      );
    } catch (e) {
      throw ApiException(
        statusCode: null,
        message: 'An unexpected error occurred.',
        originalError: e,
      );
    }
  }

  // ============================================================
  // GET – with caching support
  // ============================================================
  Future<http.Response> get(
      BuildContext context,
      String url, {
        bool forceRefresh = false,
        int? ttlSeconds,
      }) async {
    String? token = await _auth.getToken();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated');
    }

    return _safeRequestWithCache(
      context,
      url,
          () async {
        var response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 401 || response.statusCode == 403) {
          print('🔁 Attempting token refresh...');
          final newToken = await _auth.refreshToken();
          if (newToken != null) {
            // Invalidate cache for this URL before retry? Possibly, but we'll keep it for now.
            response = await http.get(
              Uri.parse(url),
              headers: {'Authorization': 'Bearer $newToken'},
            );
          } else {
            print('❌ Refresh failed – logging out.');
            await _auth.clearAndNavigateToLogin(context);
            throw ApiException(
              statusCode: 401,
              message: 'Session expired. Please login again.',
            );
          }
        }
        return response;
      },
      forceRefresh: forceRefresh,
      ttlSeconds: ttlSeconds,
    );
  }

  // ============================================================
  // POST – invalidates cache for the URL prefix
  // ============================================================
  Future<http.Response> post(
      BuildContext context,
      String url, {
        Map<String, dynamic>? body,
      }) async {
    String? token = await _auth.getToken();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated');
    }

    // Invalidate cache for this URL prefix (e.g., /api/xxx)
    // Use the base path up to the last '/'
    final prefix = url.substring(0, url.lastIndexOf('/') + 1);
    invalidateCachePrefix(prefix);

    return _safeRequest(context, () async {
      var response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body != null ? jsonEncode(body) : null,
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        print('🔁 Attempting token refresh...');
        final newToken = await _auth.refreshToken();
        if (newToken != null) {
          response = await http.post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $newToken',
              'Content-Type': 'application/json',
            },
            body: body != null ? jsonEncode(body) : null,
          );
        } else {
          print('❌ Refresh failed – logging out.');
          await _auth.clearAndNavigateToLogin(context);
          throw ApiException(
            statusCode: 401,
            message: 'Session expired. Please login again.',
          );
        }
      }
      return response;
    });
  }

  // ============================================================
  // PUT – invalidates cache for the URL prefix
  // ============================================================
  Future<http.Response> put(
      BuildContext context,
      String url, {
        Map<String, dynamic>? body,
      }) async {
    String? token = await _auth.getToken();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated');
    }

    final prefix = url.substring(0, url.lastIndexOf('/') + 1);
    invalidateCachePrefix(prefix);

    return _safeRequest(context, () async {
      var response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body != null ? jsonEncode(body) : null,
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        print('🔁 Attempting token refresh...');
        final newToken = await _auth.refreshToken();
        if (newToken != null) {
          response = await http.put(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $newToken',
              'Content-Type': 'application/json',
            },
            body: body != null ? jsonEncode(body) : null,
          );
        } else {
          print('❌ Refresh failed – logging out.');
          await _auth.clearAndNavigateToLogin(context);
          throw ApiException(
            statusCode: 401,
            message: 'Session expired. Please login again.',
          );
        }
      }
      return response;
    });
  }

  // ============================================================
  // DELETE – invalidates cache for the URL prefix
  // ============================================================
  Future<http.Response> delete(BuildContext context, String url) async {
    String? token = await _auth.getToken();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated');
    }

    final prefix = url.substring(0, url.lastIndexOf('/') + 1);
    invalidateCachePrefix(prefix);

    return _safeRequest(context, () async {
      var response = await http.delete(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        print('🔁 Attempting token refresh...');
        final newToken = await _auth.refreshToken();
        if (newToken != null) {
          response = await http.delete(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $newToken'},
          );
        } else {
          print('❌ Refresh failed – logging out.');
          await _auth.clearAndNavigateToLogin(context);
          throw ApiException(
            statusCode: 401,
            message: 'Session expired. Please login again.',
          );
        }
      }
      return response;
    });
  }

  // ============================================================
  // CORE REQUEST HANDLER (without caching, for mutations)
  // ============================================================
  Future<http.Response> _safeRequest(
      BuildContext context,
      Future<http.Response> Function() requestFn,
      ) async {
    if (!await _connectivity.checkConnectivity()) {
      throw ApiException(
        statusCode: null,
        message: 'No internet connection. Please check your network.',
      );
    }

    try {
      final response = await requestFn();

      if (response.statusCode >= 400) {
        String errorMessage = '';
        try {
          final body = jsonDecode(response.body);
          errorMessage = body['message'] ?? body['error'] ?? 'An error occurred.';
        } catch (_) {
          errorMessage = 'Server error (${response.statusCode}).';
        }

        if (response.statusCode == 429) {
          throw ApiException(
            statusCode: 429,
            message: errorMessage.isNotEmpty
                ? errorMessage
                : 'Too many requests. Please try again later.',
          );
        }

        throw ApiException(
          statusCode: response.statusCode,
          message: errorMessage,
        );
      }
      return response;
    } on ApiException {
      rethrow;
    } on SocketException catch (_) {
      throw ApiException(
        statusCode: null,
        message: 'No internet connection. Please check your network.',
      );
    } on TimeoutException catch (_) {
      throw ApiException(
        statusCode: null,
        message: 'Connection timed out. Please try again.',
      );
    } catch (e) {
      throw ApiException(
        statusCode: null,
        message: 'An unexpected error occurred.',
        originalError: e,
      );
    }
  }

  // ============================================================
  // MULTIPART POST (file upload) – with basic error handling
  // ============================================================
  Future<http.StreamedResponse> multipartPost(
      BuildContext context,
      String url,
      Map<String, String> fields, {
        required String fileField,
        required String filePath,
      }) async {
    String? token = await _auth.getToken();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated');
    }

    if (!await _connectivity.checkConnectivity()) {
      throw ApiException(
        statusCode: null,
        message: 'No internet connection. Please check your network.',
      );
    }

    final prefix = url.substring(0, url.lastIndexOf('/') + 1);
    invalidateCachePrefix(prefix);

    var request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll(fields)
      ..files.add(await http.MultipartFile.fromPath(fileField, filePath));

    try {
      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 401 ||
          streamedResponse.statusCode == 403) {
        print('🔁 Attempting token refresh...');
        final newToken = await _auth.refreshToken();
        if (newToken != null) {
          var retryRequest = http.MultipartRequest('POST', Uri.parse(url))
            ..headers['Authorization'] = 'Bearer $newToken'
            ..fields.addAll(fields)
            ..files.add(await http.MultipartFile.fromPath(fileField, filePath));
          streamedResponse = await retryRequest.send();
        } else {
          print('❌ Refresh failed – logging out.');
          await _auth.clearAndNavigateToLogin(context);
          throw ApiException(
            statusCode: 401,
            message: 'Session expired. Please login again.',
          );
        }
      }
      return streamedResponse;
    } on SocketException catch (_) {
      throw ApiException(
        statusCode: null,
        message: 'No internet connection. Please check your network.',
      );
    } on TimeoutException catch (_) {
      throw ApiException(
        statusCode: null,
        message: 'Connection timed out. Please try again.',
      );
    } catch (e) {
      throw ApiException(
        statusCode: null,
        message: 'An unexpected error occurred during upload.',
        originalError: e,
      );
    }
  }
}