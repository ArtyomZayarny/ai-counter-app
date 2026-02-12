import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_service.dart';
import 'providers/auth_provider.dart';

enum _ScreenState { initializing, preview, captured, loading, result, error }

class ScanScreen extends StatefulWidget {
  final String meterId;

  const ScanScreen({super.key, required this.meterId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  _ScreenState _state = _ScreenState.initializing;
  String _result = '';
  String _error = '';
  XFile? _capturedFile;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _state = _ScreenState.error;
          _error = 'No camera available';
        });
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() => _state = _ScreenState.preview);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScreenState.error;
          _error = 'Camera error: $e';
        });
      }
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final file = await _controller!.takePicture();
      setState(() {
        _capturedFile = file;
        _state = _ScreenState.captured;
      });
    } catch (e) {
      setState(() {
        _state = _ScreenState.error;
        _error = 'Capture failed: $e';
      });
    }
  }

  void _retake() {
    setState(() {
      _capturedFile = null;
      _state = _ScreenState.preview;
    });
  }

  Future<void> _confirm() async {
    if (_capturedFile == null) return;
    setState(() => _state = _ScreenState.loading);

    try {
      final response =
          await recognizeMeter(File(_capturedFile!.path), widget.meterId);
      setState(() {
        _state = _ScreenState.result;
        _result = response['result'] as String;
        _saved = true;
      });
    } on UnauthorizedException {
      if (mounted) context.read<AuthProvider>().handle401();
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

  void _reset() {
    setState(() {
      _capturedFile = null;
      _state = _ScreenState.preview;
      _saved = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gas Meter')),
      body: switch (_state) {
        _ScreenState.initializing => const Center(
            child: CircularProgressIndicator(),
          ),
        _ScreenState.preview => _buildPreview(),
        _ScreenState.captured => _buildCaptured(),
        _ScreenState.loading => _buildLoading(),
        _ScreenState.result => _buildResult(),
        _ScreenState.error => _buildError(),
      },
    );
  }

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: FloatingActionButton.large(
              onPressed: _capture,
              child: const Icon(Icons.camera_alt, size: 36),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptured() {
    return Column(
      children: [
        Expanded(
          child: Image.file(
            File(_capturedFile!.path),
            fit: BoxFit.contain,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Recognizing...', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
            if (_saved) ...[
              const SizedBox(height: 12),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Saved!',
                      style: TextStyle(color: Colors.green, fontSize: 16)),
                ],
              ),
            ],
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
        ),
      ),
    );
  }
}
