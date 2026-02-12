import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_service.dart';
import '../models/meter.dart';
import '../models/reading.dart';

class CalculatorScreen extends StatefulWidget {
  final Meter meter;
  final List<Reading> readings;

  const CalculatorScreen(
      {super.key, required this.meter, required this.readings});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _tariffController = TextEditingController();
  Reading? _fromReading;
  Reading? _toReading;
  bool _saving = false;

  int? get _consumed {
    if (_fromReading == null || _toReading == null) return null;
    final diff = _toReading!.value - _fromReading!.value;
    if (diff >= 0) return diff;
    return null;
  }

  double? get _totalCost {
    final consumed = _consumed;
    final tariff = double.tryParse(_tariffController.text);
    if (consumed == null || tariff == null) return null;
    return consumed * tariff;
  }

  Future<void> _save() async {
    if (_fromReading == null ||
        _toReading == null ||
        _tariffController.text.isEmpty) return;

    final tariff = double.tryParse(_tariffController.text);
    if (tariff == null) return;

    setState(() => _saving = true);

    try {
      await createBill(
        meterId: widget.meter.id,
        readingFromId: _fromReading!.id,
        readingToId: _toReading!.id,
        tariffPerUnit: tariff,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _tariffController.dispose();
    super.dispose();
  }

  String _readingLabel(Reading r) {
    return '${r.formattedValue} (${DateFormat('dd MMM yyyy').format(r.recordedAt)})';
  }

  @override
  Widget build(BuildContext context) {
    final sortedReadings = List<Reading>.from(widget.readings)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tariffController,
              decoration: InputDecoration(
                labelText: 'Tariff (EUR per ${widget.meter.utilityType == 'electricity' ? 'kWh' : 'm\u00B3'})',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.euro),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<Reading>(
              decoration: const InputDecoration(
                labelText: 'From reading',
                border: OutlineInputBorder(),
              ),
              items: sortedReadings
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_readingLabel(r)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _fromReading = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Reading>(
              decoration: const InputDecoration(
                labelText: 'To reading',
                border: OutlineInputBorder(),
              ),
              items: sortedReadings
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_readingLabel(r)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _toReading = v),
            ),
            const SizedBox(height: 32),
            // Preview
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Consumed:',
                            style: TextStyle(fontSize: 16)),
                        Text(
                          _consumed != null
                              ? '$_consumed ${widget.meter.utilityType == 'electricity' ? 'kWh' : 'm\u00B3'}'
                              : '-- ${widget.meter.utilityType == 'electricity' ? 'kWh' : 'm\u00B3'}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total cost:',
                            style: TextStyle(fontSize: 16)),
                        Text(
                          _totalCost != null
                              ? 'EUR ${_totalCost!.toStringAsFixed(2)}'
                              : 'EUR --',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _consumed != null && _totalCost != null && !_saving
                  ? _save
                  : null,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Bill'),
            ),
          ],
        ),
      ),
    );
  }
}
