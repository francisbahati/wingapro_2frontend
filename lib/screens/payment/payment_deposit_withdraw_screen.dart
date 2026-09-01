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
import '../../services/error_handler.dart';
import '../../services/notification_service.dart';
import '../../widgets/error_snackbar.dart';

enum TransactionType { deposit, withdraw }

class PaymentDepositWithdrawScreen extends StatefulWidget {
  final bool allowWithdraw;

  const PaymentDepositWithdrawScreen({super.key, this.allowWithdraw = true});

  @override
  State<PaymentDepositWithdrawScreen> createState() =>
      _PaymentDepositWithdrawScreenState();
}

class _PaymentDepositWithdrawScreenState
    extends State<PaymentDepositWithdrawScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  TransactionType _selectedType = TransactionType.deposit;
  bool _isLoading = false;
  double _balance = 0.0;
  bool _isPolling = false;
  bool _cancelledPolling = false;

  // For deposit polling (Snippe)
  Timer? _pollTimer;
  String? _currentReference;

  // Tanzanian phone regex
  final RegExp _phoneRegex = RegExp(r'^(0|255|\+255)?[67]\d{8}$');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _cancelPolling();
    _amountController.dispose();
    _phoneController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _cancelPolling() {
    _cancelledPolling = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadData() async {
    try {
      final token = await _auth.getToken();
      if (token == null) return;
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/wallet',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) setState(() => _balance = (data['balance'] ?? 0.0).toDouble());
        }
      }
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

    if (_selectedType == TransactionType.withdraw) {
      // 🔥 Minimum withdrawal check
      if (amount < 25000) {
        _showSnackBar('Minimum withdrawal is TZS 25,000', Colors.red);
        return;
      }
      if (amount > _balance) {
        _showSnackBar(
          'Insufficient balance. Available: ${_formatAmount(_balance)}',
          Colors.red,
        );
        return;
      }
      await _submitManualWithdrawal(amount);
    } else {
      await _submitDeposit(amount);
    }
  }

  Future<void> _submitDeposit(double amount) async {
    final digits = _phoneController.text.trim();
    if (digits.isEmpty) {
      _showSnackBar('Please enter your phone number', Colors.red);
      return;
    }
    // Validate phone format
    if (!_phoneRegex.hasMatch(digits)) {
      _showSnackBar(
        'Enter a valid Tanzanian mobile number (e.g., 0712345678)',
        Colors.red,
      );
      return;
    }
    // Clean to 255 format
    String cleaned = digits.replaceAll(RegExp(r'\s+'), '');
    String fullPhone;
    if (cleaned.startsWith('+255')) {
      fullPhone = cleaned.substring(1);
    } else if (cleaned.startsWith('0')) {
      fullPhone = '255' + cleaned.substring(1);
    } else if (cleaned.startsWith('255')) {
      fullPhone = cleaned;
    } else {
      // assume it's 9 digits, prepend 255
      fullPhone = '255' + cleaned;
    }

    final confirmed = await _showConfirmationDialog(amount, fullPhone, isDeposit: true);
    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      final response = await _api.post(
        context,
        '${ApiConfig.baseUrl}/api/wallet/deposit',
        body: {
          'amount': amount,
          'phone': fullPhone,
          'idempotencyKey': const Uuid().v4(),
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final txRef = data['transaction']?['reference'];
        if (txRef != null) {
          _showSnackBar(
            'Deposit initiated. Please check your phone and complete the STK push.',
            Colors.blue,
          );
          _pollForDepositCompletion(txRef);
        } else {
          throw Exception('No transaction reference returned');
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Deposit failed',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pollForDepositCompletion(String reference) async {
    _cancelledPolling = false;
    _currentReference = reference;
    int attempts = 0;
    const maxAttempts = 60;
    const interval = Duration(seconds: 5);

    _pollTimer = Timer.periodic(interval, (timer) async {
      attempts++;
      if (_cancelledPolling) {
        timer.cancel();
        return;
      }

      try {
        final token = await _auth.getToken();
        if (token == null) {
          timer.cancel();
          _cancelledPolling = true;
          return;
        }
        final response = await _api.get(
          context,
          '${ApiConfig.baseUrl}/api/payments/$reference',
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            final status = data['transaction']['status'];
            if (status == 'completed') {
              timer.cancel();
              _cancelledPolling = true;
              if (mounted) {
                setState(() => _isLoading = false);
                _showSnackBar('Deposit completed successfully!', Colors.green);
                _amountController.clear();
                _phoneController.clear();
                await _loadData();
              }
              return;
            } else if (status == 'failed') {
              timer.cancel();
              _cancelledPolling = true;
              if (mounted) {
                setState(() => _isLoading = false);
                _showSnackBar(
                  'Deposit failed: ${data['transaction']['failureReason'] ?? 'Unknown error'}',
                  Colors.red,
                );
              }
              return;
            }
          }
        }
      } catch (_) {}

      if (attempts >= maxAttempts) {
        timer.cancel();
        _cancelledPolling = true;
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar(
            'Deposit confirmation timed out. Please check your wallet later.',
            Colors.orange,
          );
        }
      }
    });
  }

  Future<void> _submitManualWithdrawal(double amount) async {
    String? phone;
    final digits = _phoneController.text.trim();
    if (digits.isNotEmpty) {
      if (!_phoneRegex.hasMatch(digits)) {
        _showSnackBar(
          'Enter a valid Tanzanian mobile number (e.g., 0712345678)',
          Colors.red,
        );
        return;
      }
      // Clean to 255 format
      String cleaned = digits.replaceAll(RegExp(r'\s+'), '');
      if (cleaned.startsWith('+255')) {
        phone = cleaned.substring(1);
      } else if (cleaned.startsWith('0')) {
        phone = '255' + cleaned.substring(1);
      } else if (cleaned.startsWith('255')) {
        phone = cleaned;
      } else {
        phone = '255' + cleaned;
      }
    }

    final confirmed = await _showConfirmationDialog(amount, phone ?? 'Registered phone', isDeposit: false);
    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final response = await _api.requestWithdrawal(
        context,
        amount: amount,
        phone: phone,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar(
          'Withdrawal request submitted. You will receive a notification when processed.',
          Colors.green,
        );
        _amountController.clear();
        _phoneController.clear();
        await _loadData();
        // Refresh notifications
        await NotificationService().fetchUnreadCount();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Withdrawal request failed',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showConfirmationDialog(double amount, String phone, {required bool isDeposit}) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isDeposit ? 'Confirm Deposit' : 'Confirm Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${_formatAmount(amount)}'),
            const SizedBox(height: 8),
            Text('Phone: $phone'),
            const SizedBox(height: 16),
            Text(
              isDeposit
                  ? 'You will receive an STK push on your phone to confirm the deposit.'
                  : 'Your withdrawal request will be reviewed and processed manually.',
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
              backgroundColor: isDeposit ? Colors.green : Colors.orange,
            ),
            child: Text(isDeposit ? 'Deposit' : 'Withdraw'),
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
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                              style: TextStyle(color: Colors.white70, fontSize: 14),
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

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 15,
                          decoration: InputDecoration(
                            labelText: 'Phone Number (optional for withdrawal)',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            hintText: '712345678',
                            counterText: '',
                            helperText:
                            'Enter a valid Tanzanian mobile number (e.g., 0712345678)',
                            helperStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 8),

                        Text(
                          _selectedType == TransactionType.deposit
                              ? 'You will receive an STK push on your phone to complete the deposit.'
                              : 'Your withdrawal request will be processed manually.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedType == TransactionType.deposit
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
                                  : 'Request Withdrawal',
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
                      : 'Withdrawal requests are reviewed by admin. '
                      'You will receive a notification when completed.',
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