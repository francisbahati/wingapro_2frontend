// lib/services/error_handler.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

/// Custom exception for API errors.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic originalError;

  ApiException({this.statusCode, required this.message, this.originalError});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Holds user‑friendly error details.
class ErrorInfo {
  final String title;
  final String message;
  final String type; // 'network', 'session', 'permission', 'validation', 'server', 'unknown'
  final VoidCallback? action;

  ErrorInfo({
    required this.title,
    required this.message,
    required this.type,
    this.action,
  });
}

/// Centralised error handler.
class ErrorHandler {
  static ErrorInfo handle(
      dynamic error, {
        VoidCallback? onRetry,
        VoidCallback? onLogout,
      }) {
    // Network errors
    if (error is SocketException || error is HttpException || error is TimeoutException) {
      return ErrorInfo(
        title: 'No Internet Connection',
        message: 'Please check your network and try again.',
        type: 'network',
        action: onRetry,
      );
    }

    if (error is ApiException) {
      final statusCode = error.statusCode;
      final message = error.message;

      switch (statusCode) {
        case 400:
          return ErrorInfo(
            title: 'Invalid Input',
            message: message.isNotEmpty ? message : 'Please check your input and try again.',
            type: 'validation',
            action: onRetry,
          );
        case 401:
          return ErrorInfo(
            title: 'Session Expired',
            message: 'Your session has expired. Please login again.',
            type: 'session',
            action: onLogout ?? _logoutAndNavigate,
          );
        case 403:
          return ErrorInfo(
            title: 'Permission Denied',
            message: 'You do not have permission to perform this action.',
            type: 'permission',
            action: onRetry,
          );
        case 404:
          return ErrorInfo(
            title: 'Not Found',
            message: 'The requested resource was not found.',
            type: 'unknown',
            action: onRetry,
          );
        case 500:
        case 502:
        case 503:
          return ErrorInfo(
            title: 'Server Error',
            message: 'Something went wrong on our end. Please try again later.',
            type: 'server',
            action: onRetry,
          );
        default:
          return ErrorInfo(
            title: 'Error',
            message: message.isNotEmpty ? message : 'An unexpected error occurred.',
            type: 'unknown',
            action: onRetry,
          );
      }
    }

    return ErrorInfo(
      title: 'Something Went Wrong',
      message: 'An unexpected error occurred. Please try again.',
      type: 'unknown',
      action: onRetry,
    );
  }

  static void showSnackbar(BuildContext context, ErrorInfo info) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(info.message),
        backgroundColor: info.type == 'session' ? Colors.orange : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        action: info.action != null
            ? SnackBarAction(
          label: 'Retry',
          onPressed: info.action!,
          textColor: Colors.white,
        )
            : null,
      ),
    );
  }

  static VoidCallback? _logoutCallback;
  static void setLogoutCallback(VoidCallback callback) => _logoutCallback = callback;
  static void _logoutAndNavigate() {
    if (_logoutCallback != null) _logoutCallback!();
  }
}