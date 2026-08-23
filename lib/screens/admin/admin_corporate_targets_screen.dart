// lib/screens/admin/admin_corporate_targets_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class AdminCorporateTargetsScreen extends StatefulWidget {
  const AdminCorporateTargetsScreen({super.key});

  @override
  State<AdminCorporateTargetsScreen> createState() =>
      _AdminCorporateTargetsScreenState();
}

class _AdminCorporateTargetsScreenState
    extends State<AdminCorporateTargetsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  bool _isSaving = false;

  final TextEditingController _salesTargetController = TextEditingController();
  final TextEditingController _clientTargetController = TextEditingController();
  final TextEditingController _dealValueTargetController =
  TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTargets();
  }

  @override
  void dispose() {
    _salesTargetController.dispose();
    _clientTargetController.dispose();
    _dealValueTargetController.dispose();
    super.dispose();
  }

  Future<void> _fetchTargets() async {
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
        '${ApiConfig.baseUrl}/api/admin/corporate-targets',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final targets = data['targets'];
          _salesTargetController.text = targets['salesTarget']?.toString() ?? '100';
          _clientTargetController.text = targets['clientTarget']?.toString() ?? '50';
          _dealValueTargetController.text =
              targets['dealValueTarget']?.toString() ?? '1000000';
          setState(() => _isLoading = false);
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load targets',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchTargets);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTargets() async {
    final salesTarget = double.tryParse(_salesTargetController.text.trim());
    final clientTarget = double.tryParse(_clientTargetController.text.trim());
    final dealValueTarget =
    double.tryParse(_dealValueTargetController.text.trim());

    if (salesTarget == null || clientTarget == null || dealValueTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter valid numbers'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/admin/corporate-targets',
        body: {
          'salesTarget': salesTarget,
          'clientTarget': clientTarget,
          'dealValueTarget': dealValueTarget,
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Targets updated successfully'),
              backgroundColor: Colors.green),
        );
        _fetchTargets();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Failed to save targets',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Corporate Sales Targets'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchTargets,
            ),
          ],
        ),
        body: ErrorView(
          title: _errorTitle!,
          message: _errorMessage!,
          onRetry: _retryAction,
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Corporate Sales Targets'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTargets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Set Corporate Sales Targets',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These targets will be displayed in the Corporate Sales reports.',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white70
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _salesTargetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Sales Target (number of sales)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _clientTargetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Client Target (number of clients)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _dealValueTargetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Deal Value Target (TZS)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      prefixText: 'TZS ',
                    ),
                  ),
                  const SizedBox(height: 24),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: _saveTargets,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Targets'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}