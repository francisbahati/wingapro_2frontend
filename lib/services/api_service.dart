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

  // 🔥 NEW: Token refresh state
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;
  final List<Completer<http.Response>> _pendingRequests = [];

  // Default TTL for GET requests (5 minutes)
  static const int _defaultTtlSeconds = 300;

  // ============================================================
  // CACHE HELPERS
  // ============================================================

  String _buildCacheKey(String url) => url;

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

  void _setCached(String url, dynamic data, {int? ttlSeconds}) {
    final key = _buildCacheKey(url);
    _cache[key] = _CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      ttlSeconds: ttlSeconds ?? _defaultTtlSeconds,
    );
  }

  void invalidateCache(String url) {
    final key = _buildCacheKey(url);
    _cache.remove(key);
  }

  void invalidateCachePrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  void clearCache() {
    _cache.clear();
  }

  // ============================================================
  // 🔥 NEW: TOKEN REFRESH WITH QUEUE
  // ============================================================

  /// Refreshes the token once, and queues pending requests to retry after refresh.
  /// Returns the new token, or null if refresh failed.
  Future<String?> _refreshTokenWithQueue(BuildContext context) async {
    // If a refresh is already in progress, wait for it
    if (_isRefreshing) {
      return _refreshCompleter!.future;
    }

    // Start a new refresh
    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final newToken = await _auth.refreshToken();

      if (newToken != null) {
        // Refresh succeeded
        print('✅ Token refreshed successfully');
        _refreshCompleter!.complete(newToken);
      } else {
        // Refresh failed
        print('❌ Refresh failed – logging out');
        await _auth.clearAndNavigateToLogin(context);
        _refreshCompleter!.complete(null);
      }
    } catch (e) {
      print('❌ Refresh error: $e');
      await _auth.clearAndNavigateToLogin(context);
      _refreshCompleter!.complete(null);
    } finally {
      _isRefreshing = false;
    }

    return _refreshCompleter!.future;
  }

  /// Executes a request with automatic token refresh retry.
  /// If the first request fails with 401, it triggers a token refresh and retries.
  Future<http.Response> _executeWithAuthRetry(
      BuildContext context,
      Future<http.Response> Function(String token) requestFn,
      ) async {
    // First attempt with current token
    String? token = await _auth.getToken();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated');
    }

    try {
      var response = await requestFn(token);

      // If token is valid, return response
      if (response.statusCode != 401 && response.statusCode != 403) {
        return response;
      }

      // Token expired – trigger refresh
      print('🔑 Token expired, refreshing...');
      final newToken = await _refreshTokenWithQueue(context);

      if (newToken == null) {
        throw ApiException(statusCode: 401, message: 'Session expired. Please login again.');
      }

      // Retry the request with the new token
      print('🔄 Retrying request with new token...');
      return await requestFn(newToken);

    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: null,
        message: 'Request failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  // ============================================================
  // CORE REQUEST HANDLER WITH CACHING
  // ============================================================

  Future<http.Response> _safeRequestWithCache(
      BuildContext context,
      String url,
      Future<http.Response> Function(String token) requestFn, {
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
        final body = cachedData['body'] as String? ?? '';
        final statusCode = cachedData['statusCode'] as int? ?? 200;
        final headers = Map<String, String>.from(cachedData['headers'] ?? {});
        return http.Response(body, statusCode, headers: headers);
      }
    }

    try {
      // 🔥 Use the auth retry wrapper
      final response = await _executeWithAuthRetry(
        context,
            (token) async {
          final headers = {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          };
          return await http.get(Uri.parse(url), headers: headers);
        },
      );

      // 3. Cache successful responses (2xx)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final cacheData = {
          'body': response.body,
          'statusCode': response.statusCode,
          'headers': response.headers,
        };
        _setCached(url, cacheData, ttlSeconds: ttlSeconds);
      }

      // 4. Handle HTTP status codes
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
    return _safeRequestWithCache(
      context,
      url,
          (token) async {
        return await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );
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
    final prefix = url.substring(0, url.lastIndexOf('/') + 1);
    invalidateCachePrefix(prefix);

    return _executeWithAuthRetry(
      context,
          (token) async {
        return await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body != null ? jsonEncode(body) : null,
        );
      },
    );
  }

  // ============================================================
  // PUT – invalidates cache for the URL prefix
  // ============================================================
  Future<http.Response> put(
      BuildContext context,
      String url, {
        Map<String, dynamic>? body,
      }) async {
    final prefix = url.substring(0, url.lastIndexOf('/') + 1);
    invalidateCachePrefix(prefix);

    return _executeWithAuthRetry(
      context,
          (token) async {
        return await http.put(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body != null ? jsonEncode(body) : null,
        );
      },
    );
  }

  // ============================================================
  // DELETE – invalidates cache for the URL prefix
  // ============================================================
  Future<http.Response> delete(BuildContext context, String url) async {
    final prefix = url.substring(0, url.lastIndexOf('/') + 1);
    invalidateCachePrefix(prefix);

    return _executeWithAuthRetry(
      context,
          (token) async {
        return await http.delete(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );
      },
    );
  }

  // ============================================================
  // CORE REQUEST HANDLER (without caching, for mutations)
  // ============================================================
  Future<http.Response> _safeRequest(
      BuildContext context,
      Future<http.Response> Function(String token) requestFn,
      ) async {
    if (!await _connectivity.checkConnectivity()) {
      throw ApiException(
        statusCode: null,
        message: 'No internet connection. Please check your network.',
      );
    }

    try {
      final response = await _executeWithAuthRetry(context, requestFn);

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
  // WITHDRAWAL API METHODS
  // ============================================================

  Future<http.Response> requestWithdrawal(
      BuildContext context, {
        required double amount,
        String? phone,
      }) async {
    final body = <String, dynamic>{'amount': amount};
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;

    return post(
      context,
      '${ApiConfig.baseUrl}/api/withdraw/request',
      body: body,
    );
  }

  Future<http.Response> getWithdrawalHistory(
      BuildContext context, {
        String? status,
        int page = 1,
        int limit = 20,
      }) async {
    final queryParams = <String>[];
    if (status != null && status.isNotEmpty) queryParams.add('status=$status');
    queryParams.add('page=$page');
    queryParams.add('limit=$limit');

    final url = queryParams.isEmpty
        ? '${ApiConfig.baseUrl}/api/withdraw/history'
        : '${ApiConfig.baseUrl}/api/withdraw/history?${queryParams.join('&')}';

    return get(context, url);
  }

  Future<http.Response> getWithdrawalDetails(BuildContext context, int id) {
    return get(context, '${ApiConfig.baseUrl}/api/withdraw/$id');
  }

  // ============================================================
  // ADMIN WITHDRAWAL API METHODS
  // ============================================================

  Future<http.Response> adminGetWithdrawals(
      BuildContext context, {
        String? status,
        int page = 1,
        int limit = 20,
      }) async {
    final queryParams = <String>[];
    if (status != null && status.isNotEmpty) queryParams.add('status=$status');
    queryParams.add('page=$page');
    queryParams.add('limit=$limit');

    final url = queryParams.isEmpty
        ? '${ApiConfig.baseUrl}/api/admin/withdrawals'
        : '${ApiConfig.baseUrl}/api/admin/withdrawals?${queryParams.join('&')}';

    return get(context, url);
  }

  Future<http.Response> adminGetPendingWithdrawalCount(BuildContext context) {
    return get(context, '${ApiConfig.baseUrl}/api/admin/withdrawals/pending-count');
  }

  Future<http.Response> adminCompleteWithdrawal(
      BuildContext context,
      int id, {
        String? adminNotes,
      }) {
    final body = <String, dynamic>{};
    if (adminNotes != null && adminNotes.isNotEmpty) body['adminNotes'] = adminNotes;
    return put(
      context,
      '${ApiConfig.baseUrl}/api/admin/withdrawals/$id/complete',
      body: body,
    );
  }

  Future<http.Response> adminRejectWithdrawal(
      BuildContext context,
      int id, {
        required String rejectionReason,
      }) {
    return put(
      context,
      '${ApiConfig.baseUrl}/api/admin/withdrawals/$id/reject',
      body: {'rejectionReason': rejectionReason},
    );
  }

  // ============================================================
  // MULTIPART POST (file upload)
  // ============================================================
  Future<http.StreamedResponse> multipartPost(
      BuildContext context,
      String url,
      Map<String, String> fields, {
        required String fileField,
        required String filePath,
      }) async {
    if (!await _connectivity.checkConnectivity()) {
      throw ApiException(
        statusCode: null,
        message: 'No internet connection. Please check your network.',
      );
    }

    final prefix = url.substring(0, url.lastIndexOf('/') + 1);
    invalidateCachePrefix(prefix);

    return _executeMultipartWithAuthRetry(
      context,
          (token) async {
        var request = http.MultipartRequest('POST', Uri.parse(url))
          ..headers['Authorization'] = 'Bearer $token'
          ..fields.addAll(fields)
          ..files.add(await http.MultipartFile.fromPath(fileField, filePath));
        return await request.send();
      },
    );
  }

  Future<http.StreamedResponse> _executeMultipartWithAuthRetry(
      BuildContext context,
      Future<http.StreamedResponse> Function(String token) requestFn,
      ) async {
    String? token = await _auth.getToken();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated');
    }

    try {
      var response = await requestFn(token);

      if (response.statusCode != 401 && response.statusCode != 403) {
        return response;
      }

      // Token expired – refresh
      final newToken = await _refreshTokenWithQueue(context);
      if (newToken == null) {
        throw ApiException(statusCode: 401, message: 'Session expired');
      }

      // Retry with new token
      return await requestFn(newToken);

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
        message: 'An unexpected error occurred during upload.',
        originalError: e,
      );
    }
  }
}