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
    return Scaffold(
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
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Asante kwa kutumia huduma zetu.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
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