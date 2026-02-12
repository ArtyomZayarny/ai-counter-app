import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reading.dart';

class ReadingCard extends StatelessWidget {
  final Reading reading;
  final VoidCallback? onDelete;

  const ReadingCard({super.key, required this.reading, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_fire_department,
            color: Colors.orange, size: 32),
        title: Text(
          reading.formattedValue,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(reading.recordedAt)),
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
