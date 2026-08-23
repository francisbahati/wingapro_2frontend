// lib/screens/business_staff/business_staff_field_activities_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class BusinessStaffFieldActivitiesScreen extends StatefulWidget {
  const BusinessStaffFieldActivitiesScreen({super.key});

  @override
  State<BusinessStaffFieldActivitiesScreen> createState() =>
      _BusinessStaffFieldActivitiesScreenState();
}

class _BusinessStaffFieldActivitiesScreenState
    extends State<BusinessStaffFieldActivitiesScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _activities = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
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
        '${ApiConfig.baseUrl}/api/business-staff/field-activities',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _activities = data['activities']; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load activities',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchActivities);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _getCustomers() async {
    try {
      final token = await _auth.getToken();
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/business-staff/customers',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['customers'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<void> _showAddActivityDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customerNameController = TextEditingController();
    final customerPhoneController = TextEditingController();
    final locationController = TextEditingController();
    final customerTypeController = TextEditingController();
    final packageIdController = TextEditingController();
    String outcome = 'interested';
    DateTime visitDate = DateTime.now();
    final followUpActionController = TextEditingController();
    DateTime? followUpDate;
    final notesController = TextEditingController();
    bool _isSaving = false;

    final customers = await _getCustomers();

    showDialog(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Record Field Activity'),
          backgroundColor: isDark
              ? const Color(0xFF0A1A2B).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.15)
                  : Colors.grey.shade300.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: null,
                    hint: const Text('Select Customer *'),
                    items: customers.map((c) => DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text(c['username']),
                    )).toList(),
                    onChanged: (v) {
                      final customer = customers.firstWhere((c) => c['id'] == v);
                      customerNameController.text = customer['username'];
                      customerPhoneController.text = customer['phone'] ?? '';
                    },
                    decoration: InputDecoration(
                      labelText: 'Customer',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => v == null ? 'Select a customer' : null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Customer Phone *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerTypeController,
                    decoration: InputDecoration(
                      labelText: 'Customer Type',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: packageIdController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Package ID (optional)',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: outcome,
                    items: const [
                      DropdownMenuItem(value: 'bought', child: Text('Bought')),
                      DropdownMenuItem(
                          value: 'interested', child: Text('Interested')),
                      DropdownMenuItem(
                          value: 'not_interested', child: Text('Not Interested')),
                    ],
                    onChanged: (v) => setStateDialog(() => outcome = v!),
                    decoration: InputDecoration(
                      labelText: 'Outcome *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Visit Date'),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(visitDate)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await _showDateTimePicker(ctx);
                        if (picked != null) {
                          setStateDialog(() => visitDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: followUpActionController,
                    decoration: InputDecoration(
                      labelText: 'Follow-up Action',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Follow-up Date (optional)'),
                    subtitle: Text(followUpDate == null
                        ? 'Not set'
                        : DateFormat('dd/MM/yyyy').format(followUpDate!)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setStateDialog(() => followUpDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                if (customerNameController.text.trim().isEmpty ||
                    customerPhoneController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Customer name and phone are required'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                final selectedCustomer = customers.firstWhere(
                        (c) =>
                    c['username'] ==
                        customerNameController.text.trim(),
                    orElse: () => null);
                if (selectedCustomer == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please select a valid customer'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                setStateDialog(() => _isSaving = true);
                final body = {
                  'customerId': selectedCustomer['id'],
                  'customerName': customerNameController.text.trim(),
                  'customerPhone': customerPhoneController.text.trim(),
                  'location': locationController.text.trim(),
                  'customerType': customerTypeController.text.trim(),
                  'packageId': packageIdController.text.trim().isEmpty
                      ? null
                      : int.parse(packageIdController.text.trim()),
                  'outcome': outcome,
                  'visitDate': visitDate.toIso8601String(),
                  'followUpAction': followUpActionController.text.trim(),
                  'followUpDate': followUpDate?.toIso8601String(),
                  'notes': notesController.text.trim(),
                };
                try {
                  final token = await _auth.getToken();
                  final response = await _api.post(
                    ctx,
                    '${ApiConfig.baseUrl}/api/business-staff/field-activities',
                    body: body,
                  );
                  final data = jsonDecode(response.body);
                  if (response.statusCode == 201 &&
                      data['success'] == true) {
                    Navigator.pop(ctx);
                    _fetchActivities();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Activity recorded'),
                          backgroundColor: Colors.green),
                    );
                  } else {
                    throw ApiException(
                      statusCode: response.statusCode,
                      message: data['message'] ?? 'Failed to record',
                    );
                  }
                } catch (e) {
                  showErrorSnackbar(ctx, e);
                  setStateDialog(() => _isSaving = false);
                }
              },
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _showDateTimePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Field Activities'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
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
        title: const Text('Field Activities'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddActivityDialog,
        backgroundColor: const Color(0xFF0A2E5C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _activities.isEmpty
          ? const Center(child: Text('No field activities recorded yet.'))
          : RefreshIndicator(
        onRefresh: _fetchActivities,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _activities.length,
          itemBuilder: (ctx, i) {
            final a = _activities[i];
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.85)
                  : Colors.white.withOpacity(0.85),
              child: ListTile(
                title: Text(
                  a['customerName'] ?? 'Unknown',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phone: ${a['customerPhone']}'),
                    Text('Location: ${a['location'] ?? 'N/A'}'),
                    Text('Outcome: ${a['outcome']}'),
                    Text(
                        'Visit: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(a['visitDate']))}'),
                    if (a['followUpAction'] != null)
                      Text('Follow-up: ${a['followUpAction']}'),
                  ],
                ),
                isThreeLine: true,
                trailing: Chip(
                  label: Text(a['outcome']),
                  backgroundColor: a['outcome'] == 'bought'
                      ? Colors.green
                      : a['outcome'] == 'interested'
                      ? Colors.orange
                      : Colors.red,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}