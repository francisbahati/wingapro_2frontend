// lib/screens/payment/payment_deposit_withdraw_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';

enum TransactionType { deposit, withdraw }

// ---------------------------------------------------------------------
// Payment Service – supports polling and returns transaction reference
// ---------------------------------------------------------------------
class PaymentService {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();

  // Get current wallet balance
  Future<double> getBalance(BuildContext context) async {
    final token = await _auth.getToken();
    if (token == null) throw Exception('Not logged in');
    final response = await _api.get(
      context,
      '${ApiConfig.baseUrl}/api/wallet',
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return (data['balance'] ?? 0.0).toDouble();
      }
    }
    throw Exception('Failed to fetch balance');
  }

  // Submit deposit/withdrawal – returns the transaction reference for polling
  Future<String> submitTransaction({
    required BuildContext context,
    required TransactionType type,
    required double amount,
    required String phone,
  }) async {
    final token = await _auth.getToken();
    if (token == null) throw Exception('Not logged in');

    final role = await _auth.getUserRole();
    final bool isSeller = role == 'seller';
    final String basePath = isSeller ? '/api/seller' : '/api';
    final String endpoint = type == TransactionType.deposit
        ? '$basePath/wallet/deposit'
        : '$basePath/wallet/withdraw';

    final idempotencyKey = const Uuid().v4();

    final response = await _api.post(
      context,
      '${ApiConfig.baseUrl}$endpoint',
      body: {
        'amount': amount,
        'phone': phone,
        'idempotencyKey': idempotencyKey,
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      // Extract the transaction reference from the response
      final txRef = data['transaction']?['reference'];
      if (txRef == null) {
        throw Exception('No transaction reference returned');
      }
      return txRef.toString();
    } else {
      throw Exception(data['message'] ?? 'Transaction failed');
    }
  }

  // Poll payment status – with timeout on each request
  Future<Map<String, dynamic>> pollPaymentStatus({
    required BuildContext context,
    required String reference,
    int maxAttempts = 60,             // 60 attempts * 5 seconds = 5 minutes
    Duration interval = const Duration(seconds: 5),
    Duration requestTimeout = const Duration(seconds: 10),
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      attempts++;
      try {
        final token = await _auth.getToken();
        if (token == null) throw Exception('Not logged in');

        // 🔥 CRITICAL FIX: Add timeout to prevent indefinite hanging
        final response = await _api.get(
          context,
          '${ApiConfig.baseUrl}/api/payments/$reference',
        ).timeout(requestTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            final tx = data['transaction'];
            final status = tx['status'] ?? 'pending';
            debugPrint('Poll #$attempts: status = $status');
            if (status == 'completed' || status == 'failed') {
              return {
                'status': status,
                'amount': tx['amount'] ?? 0.0,
                'failureReason': tx['failureReason'] ?? null,
              };
            }
          }
        }
      } on TimeoutException catch (_) {
        debugPrint('Poll #$attempts timed out, will retry...');
      } catch (e) {
        debugPrint('Poll error: $e');
      }
      // Wait before next attempt
      await Future.delayed(interval);
    }
    // Timeout – return a timeout status
    return {
      'status': 'timeout',
      'failureReason': 'Payment confirmation timed out. Please check your wallet later.',
    };
  }
}

// ---------------------------------------------------------------------
// Main Widget
// ---------------------------------------------------------------------
class PaymentDepositWithdrawScreen extends StatefulWidget {
  final bool allowWithdraw;

  const PaymentDepositWithdrawScreen({super.key, this.allowWithdraw = true});

  @override
  State<PaymentDepositWithdrawScreen> createState() =>
      _PaymentDepositWithdrawScreenState();
}

class _PaymentDepositWithdrawScreenState
    extends State<PaymentDepositWithdrawScreen> {
  final PaymentService _paymentService = PaymentService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  TransactionType _selectedType = TransactionType.deposit;
  bool _isLoading = false;
  double _balance = 0.0;
  bool _isPolling = false; // to prevent multiple polls
  bool _cancelledPolling = false; // set on dispose

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Cancel any ongoing polling when the widget is disposed
    _cancelledPolling = true;
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final balance = await _paymentService.getBalance(context);
      if (mounted) setState(() => _balance = balance);
    } catch (e) {
      _showSnackBar('Error loading balance: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: 'TZS ',
      decimalDigits: 0,
    ).format(amount);
  }

  Widget _buildSegmentButton(TransactionType type, String label) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _amountController.clear();
          _phoneController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A2E5C) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // Background polling – updates balance when done, shows snackbar
  Future<void> _pollForCompletion(String reference) async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      final result = await _paymentService.pollPaymentStatus(
        context: context,
        reference: reference,
        // You can adjust these to your preference
        maxAttempts: 60,
        interval: const Duration(seconds: 5),
      );

      // If cancelled while polling, don't show any snackbar
      if (_cancelledPolling) return;

      if (result['status'] == 'completed') {
        // Refresh balance
        await _loadData();
        _showSnackBar(
          '${_selectedType == TransactionType.deposit ? 'Deposit' : 'Withdrawal'} completed successfully!',
          Colors.green,
        );
        // Clear fields on success
        _amountController.clear();
        _phoneController.clear();
      } else if (result['status'] == 'failed') {
        _showSnackBar(
          'Transaction failed: ${result['failureReason'] ?? 'Unknown error'}',
          Colors.red,
        );
      } else {
        // Timeout
        _showSnackBar(
          result['failureReason'] ??
              'Payment confirmation timed out. Please check your wallet later.',
          Colors.orange,
        );
      }
    } catch (e) {
      if (!_cancelledPolling) {
        _showSnackBar('Error checking payment status: $e', Colors.red);
      }
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _submitTransaction() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackBar('Please enter an amount', Colors.red);
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnackBar('Enter a valid positive amount', Colors.red);
      return;
    }

    if (_selectedType == TransactionType.withdraw && amount > _balance) {
      _showSnackBar(
        'Insufficient balance. Available: ${_formatAmount(_balance)}',
        Colors.red,
      );
      return;
    }

    final digits = _phoneController.text.trim();
    if (digits.isEmpty) {
      _showSnackBar('Please enter your phone number', Colors.red);
      return;
    }
    if (!RegExp(r'^\d{9}$').hasMatch(digits)) {
      _showSnackBar('Please enter exactly 9 digits', Colors.red);
      return;
    }

    final fullPhone = '255$digits';

    // Confirm dialog
    final confirmed = await _showConfirmationDialog(amount, fullPhone);
    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final reference = await _paymentService.submitTransaction(
        context: context,
        type: _selectedType,
        amount: amount,
        phone: fullPhone,
      );

      // Show confirmation snackbar
      _showSnackBar(
        'Payment initiated. Please check your phone and complete the STK push.',
        Colors.blue,
      );

      // Start background polling (no dialog)
      _pollForCompletion(reference);
    } catch (e) {
      _showSnackBar('Transaction failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showConfirmationDialog(double amount, String phone) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          _selectedType == TransactionType.deposit
              ? 'Confirm Deposit'
              : 'Confirm Withdrawal',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${_formatAmount(amount)}'),
            const SizedBox(height: 8),
            Text('Phone: +$phone'),
            const SizedBox(height: 16),
            Text(
              _selectedType == TransactionType.deposit
                  ? 'You will receive an STK push on your phone to confirm the deposit.'
                  : 'You will receive a confirmation SMS for the withdrawal.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedType == TransactionType.deposit
                  ? Colors.green
                  : Colors.orange,
            ),
            child: Text(
                _selectedType == TransactionType.deposit ? 'Deposit' : 'Withdraw'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A2E5C), Color(0xFF1E88E5)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Balance Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A2E5C), Color(0xFF1E88E5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            SizedBox(height: 4),
                          ],
                        ),
                        Text(
                          _formatAmount(_balance),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Transaction Form
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.allowWithdraw) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildSegmentButton(
                                  TransactionType.deposit,
                                  'Deposit',
                                ),
                              ),
                              Expanded(
                                child: _buildSegmentButton(
                                  TransactionType.withdraw,
                                  'Withdraw',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Amount
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount (TZS)',
                            prefixIcon: const Icon(
                              Icons.attach_money,
                              color: Color(0xFF0A2E5C),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF0A2E5C),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Phone number (network auto-detected from prefix)
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.number,
                          maxLength: 9,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '+255',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 60,
                              minHeight: 40,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF0A2E5C),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            hintText: '743115286',
                            counterText: '',
                            helperText:
                            'Enter 9 digits after the country code',
                            helperStyle: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            if (!RegExp(r'^\d{9}$').hasMatch(value.trim())) {
                              return 'Enter exactly 9 digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'You will receive an STK push on your phone to complete the transaction.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedType ==
                                  TransactionType.deposit
                                  ? const Color(0xFF0A2E5C)
                                  : Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : Text(
                              _selectedType == TransactionType.deposit
                                  ? 'Initiate Deposit'
                                  : 'Initiate Withdrawal',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  _selectedType == TransactionType.deposit
                      ? 'Your payment will be processed securely. '
                      'You will be prompted to confirm via SMS/STK Push.'
                      : 'Withdrawal may take a few minutes. '
                      'Ensure your phone number is correct.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}