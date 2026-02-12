import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/bill.dart';

class BillCard extends StatelessWidget {
  final Bill bill;
  final VoidCallback? onDelete;

  const BillCard({super.key, required this.bill, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final periodStr =
        '${DateFormat('dd MMM').format(bill.periodStart)} - ${DateFormat('dd MMM yyyy').format(bill.periodEnd)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long,
              color: Colors.greenAccent, size: 28),
        ),
        title: Text(
          '${bill.consumedUnits.toStringAsFixed(0)} m\u00B3  \u2022  ${bill.currency} ${bill.totalCost.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          periodStr,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.red.shade300),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
