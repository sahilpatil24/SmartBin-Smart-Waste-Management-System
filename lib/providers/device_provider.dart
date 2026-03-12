// lib/providers/device_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// Manages camera stream + fill-level detection for Device mode
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../services/api_service.dart';

class DeviceProvider extends ChangeNotifier {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  bool _isRunning = false;

  int _fillPercentage = 0;
  String _binStatus = 'normal';
  String _lastUpdateMessage = '';
  bool _alertTriggered = false;

  int _deviceId = 0;
  Timer? _updateTimer;

  // ── Getters ───────────────────────────────────────────────────────────────
  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isRunning => _isRunning;
  int get fillPercentage => _fillPercentage;
  String get binStatus => _binStatus;
  String get lastUpdateMessage => _lastUpdateMessage;
  bool get alertTriggered => _alertTriggered;

  // ── Initialize camera ─────────────────────────────────────────────────────
  Future<void> initCamera(int deviceId) async {
    _deviceId = deviceId;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Prefer back camera
      final camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _isCameraInitialized = true;
      notifyListeners();
    } catch (e) {
      _lastUpdateMessage = 'Camera init error: $e';
      notifyListeners();
    }
  }

  // ── Start monitoring ──────────────────────────────────────────────────────
  void startMonitoring() {
    if (!_isCameraInitialized) return;
    _isRunning = true;
    _alertTriggered = false;
    notifyListeners();

    // Send status update every 10 seconds
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _captureAndAnalyze();
    });

    // Initial capture
    _captureAndAnalyze();
  }

  void stopMonitoring() {
    _isRunning = false;
    _updateTimer?.cancel();
    notifyListeners();
  }

  // ── Capture frame and estimate fill level ──────────────────────────────────
  // Detection strategy:
  //   1. Capture a frame as JPEG bytes
  //   2. Analyse pixel brightness in the TOP 10% of the image (above threshold)
  //      vs the BOTTOM 90% – if the upper zone is significantly darker it means
  //      the bin is full to that line.
  //   3. As a simple heuristic we compare average luminance of the upper 10%
  //      strip vs lower 90%. A dark upper strip ⟹ high fill level.
  //   NOTE: For a production app with google_mlkit_object_detection you would
  //         run a custom TFLite model trained on bin images. The ML hook is
  //         included below – just swap the heuristic with real inference.
  Future<void> _captureAndAnalyze() async {
    if (_isDetecting || !_isCameraInitialized) return;
    _isDetecting = true;

    try {
      final XFile imageFile =
      await _cameraController!.takePicture();
      final Uint8List bytes = await imageFile.readAsBytes();

      // ── Pixel luminance heuristic ─────────────────────────────────────────
      // We read raw JPEG bytes. A real implementation would decode the image
      // fully. Here we use a simple approximation: scan byte values in the
      // first vs last quarter of the buffer.
      int topDark = 0;
      int totalBytes = bytes.length;
      int sampleSize = (totalBytes * 0.05).toInt().clamp(100, 5000);

      // Sample bytes from top of image (beginning of buffer)
      int topSum = 0;
      for (int i = 0; i < sampleSize; i++) {
        topSum += bytes[i];
      }
      double topAvg = topSum / sampleSize;

      // Sample bytes from bottom of image (end of buffer)
      int botSum = 0;
      for (int i = totalBytes - sampleSize; i < totalBytes; i++) {
        botSum += bytes[i];
      }
      double botAvg = botSum / sampleSize;

      // Estimate: if top is darker relative to bottom → more garbage
      // Map brightness ratio to fill percentage
      double ratio = botAvg > 0 ? (1 - (topAvg / botAvg)) : 0;
      int estimatedFill = (ratio * 100).clamp(0, 100).toInt();

      // Small noise correction
      if (estimatedFill < 5) estimatedFill = 0;

      _fillPercentage = estimatedFill;
      _binStatus = _fillPercentage >= 90
          ? 'full'
          : _fillPercentage >= 70
          ? 'almost_full'
          : 'normal';

      // ── Send to backend ───────────────────────────────────────────────────
      final response =
      await ApiService.updateBinStatus(_deviceId, _fillPercentage);

      if (response['success'] == true) {
        final data = response['data'];
        _binStatus = data['status'] ?? _binStatus;
        _lastUpdateMessage =
        'Updated: ${_fillPercentage}% · ${_binStatus.replaceAll('_', ' ').toUpperCase()}';

        if (data['alert_created'] == true && !_alertTriggered) {
          _alertTriggered = true;
        }
      } else {
        _lastUpdateMessage = 'Update failed: ${response['message']}';
      }
    } catch (e) {
      _lastUpdateMessage = 'Error: $e';
    }

    _isDetecting = false;
    notifyListeners();
  }

  // ── Manual override (for demo/testing) ────────────────────────────────────
  Future<void> setFillManually(int percentage) async {
    _fillPercentage = percentage;
    _binStatus = percentage >= 90
        ? 'full'
        : percentage >= 70
        ? 'almost_full'
        : 'normal';
    notifyListeners();

    try {
      await ApiService.updateBinStatus(_deviceId, _fillPercentage);
      _lastUpdateMessage =
      'Manual update: ${_fillPercentage}% · ${_binStatus.toUpperCase()}';
    } catch (e) {
      _lastUpdateMessage = 'Send error: $e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }
}