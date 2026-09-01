// lib/widgets/order_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isCompact;

  const OrderCard({
    super.key,
    required this.order,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = order['status'] ?? 'pending';
    final orderStatus = order['orderStatus'] ?? 'payment_received';

    Color statusColor;
    String displayStatus;

    // Use orderStatus if available, otherwise fallback to status
    final effectiveStatus = orderStatus != 'payment_received' ? orderStatus : status;

    switch (effectiveStatus) {
      case 'completed':
        statusColor = Colors.green;
        displayStatus = 'Completed';
        break;
      case 'payment_received':
        statusColor = Colors.blue;
        displayStatus = 'Payment Received';
        break;
      case 'waiting_approval':
        statusColor = Colors.orange;
        displayStatus = 'Waiting Approval';
        break;
      case 'approved':
        statusColor = Colors.purple;
        displayStatus = 'Approved';
        break;
      case 'waiting_delivery':
        statusColor = Colors.teal;
        displayStatus = 'Waiting Delivery';
        break;
      case 'pending':
        statusColor = Colors.orange;
        displayStatus = 'Pending';
        break;
      case 'failed':
        statusColor = Colors.red;
        displayStatus = 'Failed';
        break;
      default:
        statusColor = Colors.grey;
        displayStatus = effectiveStatus;
    }

    final packageName = order['Package']?['name'] ?? order['package']?['name'] ?? 'Package';
    final amount = order['amount'] ?? 0;
    final network = order['network'] ?? 'N/A';
    final recipientName = order['recipientName'] ?? 'N/A';
    final recipientPhone = order['recipientPhone'] ?? 'N/A';
    final createdAt = order['createdAt'] ?? DateTime.now().toIso8601String();

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withOpacity(isDark ? 0.08 : 0.2),
          width: 1.5,
        ),
      ),
      child: isCompact
          ? _buildCompactTile(
        context,
        statusColor,
        displayStatus,
        packageName,
        amount,
        createdAt,
      )
          : _buildFullTile(
        context,
        statusColor,
        displayStatus,
        packageName,
        amount,
        network,
        recipientName,
        recipientPhone,
        createdAt,
      ),
    );
  }

  Widget _buildFullTile(
      BuildContext context,
      Color statusColor,
      String statusText,
      String packageName,
      dynamic amount,
      String network,
      String recipientName,
      String recipientPhone,
      String createdAt,
      ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  packageName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                recipientName,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.phone, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                recipientPhone,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.network_cell, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                network,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.attach_money, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'TZS $amount',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A2E5C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(createdAt)),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTile(
      BuildContext context,
      Color statusColor,
      String statusText,
      String packageName,
      dynamic amount,
      String createdAt,
      ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.2),
        child: Text(
          statusText[0].toUpperCase(),
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        packageName,
        style: const TextStyle(fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'TZS $amount • ${DateFormat('dd/MM/yy').format(DateTime.parse(createdAt))}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}