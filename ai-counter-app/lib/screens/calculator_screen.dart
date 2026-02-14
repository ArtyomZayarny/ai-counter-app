import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_service.dart';
import '../models/meter.dart';
import '../models/reading.dart';
import '../services/secure_storage.dart';

class CalculatorScreen extends StatefulWidget {
  final Meter meter;
  final List<Reading> readings;

  const CalculatorScreen(
      {super.key, required this.meter, required this.readings});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const _currencies = <String, String>{
    'EUR': '€',
    'USD': '\$',
    'UAH': '₴',
    'RON': 'lei',
    'GBP': '£',
    'PLN': 'zł',
    'CZK': 'Kč',
    'CHF': 'Fr',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'HUF': 'Ft',
    'BGN': 'лв',
    'TRY': '₺',
    'GEL': '₾',
    'MDL': 'L',
  };

  final _tariffController = TextEditingController();
  Reading? _fromReading;
  Reading? _toReading;
  bool _saving = false;

  String _currencyCode = 'EUR';
  String _currencySymbol = '€';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final saved = await SecureStorage.getCurrency();
    if (saved != null && _currencies.containsKey(saved)) {
      setState(() {
        _currencyCode = saved;
        _currencySymbol = _currencies[saved]!;
      });
    } else {
      final format = NumberFormat.simpleCurrency(locale: Platform.localeName);
      final detected = format.currencyName ?? 'EUR';
      if (_currencies.containsKey(detected)) {
        setState(() {
          _currencyCode = detected;
          _currencySymbol = _currencies[detected]!;
        });
      }
    }
  }

  bool get _invalidDifference {
    if (_fromReading == null || _toReading == null) return false;
    return _toReading!.value - _fromReading!.value <= 0;
  }

  int? get _consumed {
    if (_fromReading == null || _toReading == null) return null;
    final diff = _toReading!.value - _fromReading!.value;
    if (diff > 0) return diff;
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
        currency: _currencyCode,
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
          const SnackBar(content: Text('Could not save bill. Try again.')),
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.meter.utilityType == 'electricity' ? 'kWh' : 'm\u00B3';
    final sortedReadings = List<Reading>.from(widget.readings)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Calculator',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SizedBox.expand(
        child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4F46E5),
              Color(0xFF6366F1),
              Color(0xFF818CF8),
              Color(0xFF3B82F6),
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: const Color(0xFF4F46E5),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _currencyCode,
                    decoration: _inputDecoration(
                      label: 'Currency',
                      icon: Icons.currency_exchange,
                    ),
                    dropdownColor: const Color(0xFF4F46E5),
                    style: const TextStyle(color: Colors.white),
                    iconEnabledColor: Colors.white.withValues(alpha: 0.7),
                    items: _currencies.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text('${e.key} (${e.value})',
                                  style:
                                      const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                    onChanged: (code) {
                      if (code == null) return;
                      setState(() {
                        _currencyCode = code;
                        _currencySymbol = _currencies[code]!;
                      });
                      SecureStorage.setCurrency(code);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tariffController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    label: 'Tariff ($_currencyCode per $unit)',
                    icon: Icons.payments_outlined,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: const Color(0xFF4F46E5),
                  ),
                  child: DropdownButtonFormField<Reading>(
                    decoration: _inputDecoration(
                      label: 'From reading',
                      icon: Icons.arrow_upward,
                    ),
                    dropdownColor: const Color(0xFF4F46E5),
                    style: const TextStyle(color: Colors.white),
                    iconEnabledColor: Colors.white.withValues(alpha: 0.7),
                    items: sortedReadings
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(_readingLabel(r),
                                  style:
                                      const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _fromReading = v),
                  ),
                ),
                const SizedBox(height: 16),
                Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: const Color(0xFF4F46E5),
                  ),
                  child: DropdownButtonFormField<Reading>(
                    decoration: _inputDecoration(
                      label: 'To reading',
                      icon: Icons.arrow_downward,
                    ),
                    dropdownColor: const Color(0xFF4F46E5),
                    style: const TextStyle(color: Colors.white),
                    iconEnabledColor: Colors.white.withValues(alpha: 0.7),
                    items: sortedReadings
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(_readingLabel(r),
                                  style:
                                      const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _toReading = v),
                  ),
                ),
                if (_invalidDifference)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current reading must be greater than previous reading',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                // Preview card — glassmorphic
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Consumed:',
                              style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      Colors.white.withValues(alpha: 0.8))),
                          Text(
                            _consumed != null
                                ? '$_consumed $unit'
                                : '-- $unit',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Divider(
                          color: Colors.white.withValues(alpha: 0.15),
                          height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total cost:',
                              style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      Colors.white.withValues(alpha: 0.8))),
                          Text(
                            _totalCost != null
                                ? '$_currencySymbol ${_totalCost!.toStringAsFixed(2)}'
                                : '$_currencySymbol --',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed:
                        _consumed != null && _totalCost != null && !_saving
                            ? _save
                            : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4F46E5),
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Bill'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
