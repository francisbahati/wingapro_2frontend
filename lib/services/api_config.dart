import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    // Use environment variable or build flag
    const String? envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    // Fallback to the production URL
    return 'https://api.wingapro.com';
  }

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
  };
}