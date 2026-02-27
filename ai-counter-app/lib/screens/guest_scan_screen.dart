import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../widgets/custom_loader.dart';
import 'auth/register_screen.dart';

enum _ScreenState { initializing, preview, picker, captured, loading, result, error }

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
  bool _hasCamera = false;
  String _result = '';
  String _error = '';
  XFile? _capturedFile;
  int _selectedUtility = 0;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _hasCamera = false;
        if (mounted) setState(() => _state = _ScreenState.picker);
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      _hasCamera = true;
      if (mounted) setState(() => _state = _ScreenState.preview);
    } on CameraException catch (e) {
      _hasCamera = false;
      if (mounted) {
        final denied = e.code == 'CameraAccessDenied' ||
            e.code == 'CameraAccessDeniedWithoutPrompt';
        if (denied) {
          setState(() {
            _state = _ScreenState.error;
            _error = 'Camera access denied. Please enable it in Settings.';
          });
        } else {
          setState(() => _state = _ScreenState.picker);
        }
      }
    } catch (_) {
      _hasCamera = false;
      if (mounted) setState(() => _state = _ScreenState.picker);
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

  Future<void> _pickFromGallery() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (picked != null && mounted) {
      setState(() {
        _capturedFile = picked;
        _state = _ScreenState.captured;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (picked != null && mounted) {
      setState(() {
        _capturedFile = picked;
        _state = _ScreenState.captured;
      });
    }
  }

  void _retake() {
    _capturedFile = null;
    if (_hasCamera && _controller != null && _controller!.value.isInitialized) {
      setState(() => _state = _ScreenState.preview);
    } else {
      setState(() => _state = _ScreenState.picker);
    }
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
    _capturedFile = null;
    if (_hasCamera && _controller != null && _controller!.value.isInitialized) {
      setState(() => _state = _ScreenState.preview);
    } else {
      setState(() => _state = _ScreenState.picker);
    }
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
        _ScreenState.picker => _buildPicker(),
        _ScreenState.captured => _buildCaptured(),
        _ScreenState.loading => _buildLoading(),
        _ScreenState.result => _buildResult(),
        _ScreenState.error => _buildError(),
      },
    );
  }

  Widget _buildUtilitySelector({bool dark = true}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? Colors.black.withValues(alpha: 0.5) : const Color(0xFFF1F0FB),
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
                color: selected ? (dark ? Colors.white : const Color(0xFF4F46E5)) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _utilityIcons[i],
                    size: 16,
                    color: selected
                        ? (dark ? const Color(0xFF4F46E5) : Colors.white)
                        : (dark ? Colors.white70 : const Color(0xFF4F46E5).withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _utilityLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected
                          ? (dark ? const Color(0xFF4F46E5) : Colors.white)
                          : (dark ? Colors.white70 : const Color(0xFF4F46E5).withValues(alpha: 0.5)),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                heroTag: 'gallery',
                onPressed: _pickFromGallery,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                child: const Icon(Icons.photo_library, color: Colors.white),
              ),
              const SizedBox(width: 24),
              FloatingActionButton.large(
                heroTag: 'capture',
                onPressed: _capture,
                child: const Icon(Icons.camera_alt, size: 36),
              ),
              const SizedBox(width: 24),
              const SizedBox(width: 56), // Balance
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera, size: 64, color: Color(0xFF4F46E5)),
            const SizedBox(height: 16),
            const Text(
              'Select a meter photo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a photo or choose from your gallery',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildUtilitySelector(dark: false),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _pickFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
              ),
            ),
          ],
        ),
      ),
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
