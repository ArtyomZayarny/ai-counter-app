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

    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_fire_department,
            color: Colors.orange, size: 32),
        title: Text(
          '${bill.consumedUnits.toStringAsFixed(0)} m\u00B3  \u2022  ${bill.currency} ${bill.totalCost.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(periodStr),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
