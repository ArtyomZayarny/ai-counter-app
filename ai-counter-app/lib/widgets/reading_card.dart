import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reading.dart';

class ReadingCard extends StatelessWidget {
  final Reading reading;
  final VoidCallback? onDelete;

  const ReadingCard({super.key, required this.reading, this.onDelete});

  @override
  Widget build(BuildContext context) {
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
            color: Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_fire_department,
              color: Colors.orange, size: 28),
        ),
        title: Text(
          reading.formattedValue,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          DateFormat('dd MMM yyyy, HH:mm').format(reading.recordedAt),
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
