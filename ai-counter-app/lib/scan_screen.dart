import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';

enum _ScreenState { idle, loading, result, error }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();

  _ScreenState _state = _ScreenState.idle;
  String _result = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    // Open camera immediately when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (picked == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _state = _ScreenState.loading);

    try {
      final result = await recognizeMeter(File(picked.path));
      setState(() {
        _state = _ScreenState.result;
        _result = result;
      });
    } on RecognitionException catch (e) {
      setState(() {
        _state = _ScreenState.error;
        _error = e.message;
      });
    } on TimeoutException {
      setState(() {
        _state = _ScreenState.error;
        _error = 'Request timed out';
      });
    } catch (e) {
      setState(() {
        _state = _ScreenState.error;
        _error = 'Unexpected error: $e';
      });
    }
  }

  void _reset() => setState(() => _state = _ScreenState.idle);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gas Meter')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_state) {
            _ScreenState.idle => _buildIdle(),
            _ScreenState.loading => _buildLoading(),
            _ScreenState.result => _buildResult(),
            _ScreenState.error => _buildError(),
          },
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return FilledButton.icon(
      onPressed: _scan,
      icon: const Icon(Icons.camera_alt, size: 28),
      label: const Text('Scan Meter', style: TextStyle(fontSize: 20)),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 24),
        Text('Recognizing...', style: TextStyle(fontSize: 18)),
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Meter Reading', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Text(
          _result,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh),
          label: const Text('Scan Again'),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          _error,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
        ),
      ],
    );
  }
}
