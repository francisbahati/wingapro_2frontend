// lib/services/banner_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'api_service.dart';

class BannerService {
  final AuthService _auth = AuthService();

  Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('Not logged in');

      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Image size must be less than 5MB');
      }

      final url = '${ApiConfig.baseUrl}/api/admin/banners/upload';
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 403) {
        final newToken = await _auth.refreshToken();
        if (newToken != null) {
          final retryRequest = http.MultipartRequest('POST', Uri.parse(url))
            ..headers['Authorization'] = 'Bearer $newToken'
            ..files.add(
              await http.MultipartFile.fromPath(
                'image',
                imageFile.path,
                contentType: MediaType('image', 'jpeg'),
              ),
            );
          final retryResponse = await retryRequest.send();
          final responseData = await retryResponse.stream.bytesToString();
          final data = jsonDecode(responseData);
          if (retryResponse.statusCode == 200 && data['success'] == true) {
            return data;
          } else {
            throw Exception(data['message'] ?? 'Upload failed after retry');
          }
        } else {
          throw Exception('Session expired. Please login again.');
        }
      }

      final responseData = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(responseData);
      if (streamedResponse.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Upload failed (HTTP ${streamedResponse.statusCode})');
      }
    } on Exception catch (e) {
      print('❌ BannerService.uploadImage error: $e');
      rethrow;
    }
  }
}