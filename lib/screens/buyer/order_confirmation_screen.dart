// lib/screens/buyer/order_confirmation_screen.dart
import 'package:flutter/material.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final int purchaseId;
  final String packageName;

  const OrderConfirmationScreen({
    super.key,
    required this.purchaseId,
    required this.packageName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/trophy.png',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.emoji_events, size: 120,
                    color: Colors.amber),
              ),
              const SizedBox(height: 24),
              Text(
                '🎉 Imefanikiwa kununua kifurushi cha $packageName kutoka Winga Pro!',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Asante kwa kutumia huduma zetu.',
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2E5C),
                ),
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}