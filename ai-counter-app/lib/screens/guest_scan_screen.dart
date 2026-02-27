import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../api_service.dart';
import '../widgets/custom_loader.dart';
import 'auth/register_screen.dart';

enum _ScreenState { initializing, preview, captured, loading, result, error }

const _utilityTypes = ['gas', 'water', 'electricity'];
const _utilityLabels = ['Gas', 'Water', 'Electricity'];
const _utilityIcons = [Icons.local_fire_department, Icons.water_drop, Icons.bolt];

class GuestScanScreen extends StatefulWidget {
  const GuestScanScreen({super.key});

  @override
  State<GuestScanScreen> createState() => _GuestScanScreenState();
}

class _GuestScanScreenState extends State<GuestScanScreen> {
  CameraController? _controller;
  _ScreenState _state = _ScreenState.initializing;
  String _result = '';
  String _error = '';
  XFile? _capturedFile;
  int _selectedUtility = 0;

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
    } on CameraException catch (e) {
      if (mounted) {
        final denied = e.code == 'CameraAccessDenied' ||
            e.code == 'CameraAccessDeniedWithoutPrompt';
        setState(() {
          _state = _ScreenState.error;
          _error = denied
              ? 'Camera access denied. Please enable it in Settings.'
              : 'Camera is not available';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _state = _ScreenState.error;
          _error = 'Could not start camera';
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
    if (_capturedFile == null || _state != _ScreenState.captured) return;
    setState(() => _state = _ScreenState.loading);

    try {
      final response = await guestRecognizeMeter(
        File(_capturedFile!.path),
        utilityType: _utilityTypes[_selectedUtility],
      );
      setState(() {
        _state = _ScreenState.result;
        _result = response['result'] as String;
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
        _error = 'Something went wrong. Please try again';
      });
    }
  }

  void _reset() {
    setState(() {
      _capturedFile = null;
      _state = _ScreenState.preview;
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
      appBar: AppBar(title: const Text('Try AI Meter Reading')),
      body: switch (_state) {
        _ScreenState.initializing => const FullScreenLoader(
            message: 'Starting camera...',
          ),
        _ScreenState.preview => _buildPreview(),
        _ScreenState.captured => _buildCaptured(),
        _ScreenState.loading => _buildLoading(),
        _ScreenState.result => _buildResult(),
        _ScreenState.error => _buildError(),
      },
    );
  }

  Widget _buildUtilitySelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_utilityTypes.length, (i) {
          final selected = _selectedUtility == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedUtility = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _utilityIcons[i],
                    size: 16,
                    color: selected ? const Color(0xFF4F46E5) : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _utilityLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? const Color(0xFF4F46E5) : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(child: _buildUtilitySelector()),
        ),
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
    return const FullScreenLoader(message: 'Recognizing...');
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.person_add, color: Color(0xFF4F46E5), size: 24),
                  SizedBox(height: 8),
                  Text(
                    'Create a free account to save readings,\ntrack usage, and calculate bills',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF4F46E5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  (route) => route.isFirst,
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Create Account'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 12),
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
