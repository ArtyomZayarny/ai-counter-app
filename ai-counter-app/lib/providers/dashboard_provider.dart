import 'dart:io';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models/bill.dart';
import '../models/reading.dart';
import '../models/tariff.dart';

class DashboardProvider extends ChangeNotifier {
  final String meterId;

  List<Reading> readings = [];
  List<Bill> bills = [];
  List<Tariff> tariffs = [];
  bool loading = false;
  String? error;

  DashboardProvider(this.meterId);

  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        getReadings(meterId),
        getBills(meterId),
        getTariffs(meterId),
      ]);
      readings = results[0] as List<Reading>;
      bills = results[1] as List<Bill>;
      tariffs = results[2] as List<Tariff>;
    } on SocketException {
      error = 'No internet connection';
    } catch (e) {
      error = 'Something went wrong';
    }

    loading = false;
    notifyListeners();
  }

  Future<void> removeReading(String readingId) async {
    await deleteReading(readingId);
    readings.removeWhere((r) => r.id == readingId);
    notifyListeners();
  }

  Future<void> removeBill(String billId) async {
    await deleteBill(billId);
    bills.removeWhere((b) => b.id == billId);
    notifyListeners();
  }
}
