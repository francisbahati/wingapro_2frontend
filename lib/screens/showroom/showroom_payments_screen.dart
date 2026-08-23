// lib/screens/showroom/showroom_payments_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class ShowroomPaymentsScreen extends StatefulWidget {
  const ShowroomPaymentsScreen({super.key});

  @override
  State<ShowroomPaymentsScreen> createState() => _ShowroomPaymentsScreenState();
}

class _ShowroomPaymentsScreenState extends State<ShowroomPaymentsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _purchases = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
  }

  Future<void> _fetchPurchases() async {
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
        '${ApiConfig.baseUrl}/api/showroom/sales',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _purchases = data['sales'] ?? []; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load purchases',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchPurchases);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmPayment(int purchaseId) async {
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/showroom/confirm-payment/$purchaseId',
        body: {'status': 'completed'},
      );
      if (response.statusCode == 200) {
        _fetchPurchases();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment confirmed'), backgroundColor: Colors.green),
        );
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to confirm',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorTitle != null) {
      return Scaffold(
        appBar: null,
        body: ErrorView(
          title: _errorTitle!,
          message: _errorMessage!,
          onRetry: _retryAction,
        ),
      );
    }

    return Scaffold(
      appBar: null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
          ? const Center(child: Text('No purchases to manage.'))
          : RefreshIndicator(
        onRefresh: _fetchPurchases,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _purchases.length,
          itemBuilder: (ctx, i) {
            final p = _purchases[i];
            final isPending = p['status'] == 'pending';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                    'Order #${p['id']} - ${p['User']?['username']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Package: ${p['Package']?['name']}'),
                    Text(
                        'Recipient: ${p['recipientName']} (${p['recipientPhone']})'),
                    Text('Network: ${p['network']}'),
                    Text('Status: ${p['status']}'),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('TZS ${p['amount']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    if (isPending)
                      ElevatedButton(
                        onPressed: () =>
                            _confirmPayment(p['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Confirm Payment'),
                      ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        ),
      ),
    );
  }
}