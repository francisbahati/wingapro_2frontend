// lib/services/api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
        return 'https://api.wingapro.com';

     }

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
  };
}
