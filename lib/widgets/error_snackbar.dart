// lib/widgets/error_snackbar.dart
import 'package:flutter/material.dart';
import '../services/error_handler.dart';

/// Shows a red SnackBar with the error message extracted from any exception.
void showErrorSnackbar(BuildContext context, dynamic error) {
  String message = 'An unexpected error occurred.';
  if (error is ApiException) {
    message = error.message;
  } else if (error is Exception) {
    message = error.toString();
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}