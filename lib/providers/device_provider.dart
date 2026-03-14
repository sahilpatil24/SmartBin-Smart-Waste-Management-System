// lib/providers/device_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// DETECTION METHOD: takePicture() + real JPEG decoding (image package)
//
// Why image stream failed on Chrome:
//   startImageStream() with YUV420 is a native-only API.
//   Flutter Web (Chrome) does NOT deliver CameraImage frames — the stream
//   just never fires, causing the timeout. This is a known Flutter limitation.
//
// Fix:
//   Use takePicture() but PROPERLY decode the JPEG using the `image` package
//   which gives us real RGB pixel values. The old code was reading raw
//   compressed JPEG bytes (not pixels) which is why it was stuck at 10%.
//
// Requires in pubspec.yaml:
//   dependencies:
//     image: ^4.1.7
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../services/api_service.dart';

class DeviceProvider extends ChangeNotifier {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRunning = false;
  bool _isDetecting = false;

  int _fillPercentage = 0;
  String _binStatus = 'normal';
  String _lastUpdateMessage = '';
  bool _alertTriggered = false;

  // ── Calibration ───────────────────────────────────────────────────────────
  bool _isCalibrated = false;
  bool _isCalibrating = false;

  // Baseline: average luminance per cell in a grid over the image
  // We divide the bottom 60% into a 10×5 grid → 50 cells
  static const int _gridCols = 5;
  static const int _gridRows = 10;
  List<double> _baselineGrid = []; // 50 average luminance values

  // ── Stability buffer ──────────────────────────────────────────────────────
  final List<int> _recentReadings = [];
  static const int _bufferSize = 5;

  // ── Monitoring timer ──────────────────────────────────────────────────────
  Timer? _monitorTimer;

  int _deviceId = 0;

  // ── Getters ───────────────────────────────────────────────────────────────
  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isRunning => _isRunning;
  bool get isCalibrated => _isCalibrated;
  bool get isCalibrating => _isCalibrating;
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

      final camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.low, // smaller = faster to decode
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _isCameraInitialized = true;
      _lastUpdateMessage = 'Camera ready. Point at EMPTY bin, then Calibrate.';
      notifyListeners();
    } catch (e) {
      _lastUpdateMessage = 'Camera init error: $e';
      notifyListeners();
    }
  }

  // ── CALIBRATE ─────────────────────────────────────────────────────────────
  Future<void> calibrate() async {
    if (!_isCameraInitialized || _isCalibrating) return;

    _isCalibrating = true;
    _isCalibrated = false;
    _lastUpdateMessage = 'Calibrating... hold camera still on EMPTY bin';
    notifyListeners();

    try {
      // Take 3 photos and average their grid luminance for a stable baseline
      List<List<double>> grids = [];

      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        final XFile file = await _cameraController!.takePicture();
        final Uint8List bytes = await file.readAsBytes();

        // PROPERLY decode JPEG to get real RGB pixels
        final decoded = await compute(_decodeAndGetGrid, bytes);
        if (decoded != null) grids.add(decoded);
      }

      if (grids.isEmpty) throw Exception('Could not decode any frames');

      // Average all grids cell by cell
      final cellCount = _gridRows * _gridCols;
      _baselineGrid = List.filled(cellCount, 0.0);
      for (final grid in grids) {
        for (int i = 0; i < cellCount; i++) {
          _baselineGrid[i] += grid[i];
        }
      }
      for (int i = 0; i < cellCount; i++) {
        _baselineGrid[i] /= grids.length;
      }

      _isCalibrated = true;
      _recentReadings.clear();
      _fillPercentage = 0;
      _lastUpdateMessage = '✓ Calibrated! Press Start Monitoring.';
    } catch (e) {
      _lastUpdateMessage = 'Calibration failed: $e';
    }

    _isCalibrating = false;
    notifyListeners();
  }

  // ── START monitoring ──────────────────────────────────────────────────────
  void startMonitoring() {
    if (!_isCameraInitialized || !_isCalibrated) return;
    _isRunning = true;
    _alertTriggered = false;
    _lastUpdateMessage = 'Monitoring...';
    notifyListeners();

    // Take a photo every 5 seconds and analyse it
    _monitorTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _captureAndAnalyze());
    _captureAndAnalyze(); // immediate first shot
  }

  void stopMonitoring() {
    _isRunning = false;
    _monitorTimer?.cancel();
    _lastUpdateMessage = 'Monitoring stopped.';
    notifyListeners();
  }

  // ── Capture + analyse one frame ───────────────────────────────────────────
  Future<void> _captureAndAnalyze() async {
    if (_isDetecting || !_isCameraInitialized || !_isCalibrated) return;
    _isDetecting = true;

    try {
      final XFile file = await _cameraController!.takePicture();
      final Uint8List bytes = await file.readAsBytes();

      // Decode on background isolate so UI doesn't freeze
      final currentGrid = await compute(_decodeAndGetGrid, bytes);

      if (currentGrid == null) throw Exception('Failed to decode image');

      // Compare each cell to baseline
      // Count how many cells in the bottom portion changed significantly
      final cellCount = _gridRows * _gridCols;
      int changedCells = 0;

      for (int i = 0; i < cellCount; i++) {
        final diff = (currentGrid[i] - _baselineGrid[i]).abs();
        // >15 luminance units difference = real change (not lighting noise)
        if (diff > 15) changedCells++;
      }

      final int rawFill =
      (changedCells / cellCount * 100).clamp(0, 100).toInt();

      // Rolling average for stability
      _recentReadings.add(rawFill);
      if (_recentReadings.length > _bufferSize) _recentReadings.removeAt(0);
      final smoothed =
          _recentReadings.reduce((a, b) => a + b) ~/ _recentReadings.length;

      _fillPercentage = smoothed;
      // ⚠ TESTING THRESHOLDS — alert fires at 50%
      // TODO: restore to 90/70 for production
      _binStatus = smoothed >= 70
          ? 'full'
          : smoothed >= 50
          ? 'almost_full'
          : 'normal';

      notifyListeners();

      // Send to backend
      final response =
      await ApiService.updateBinStatus(_deviceId, _fillPercentage);
      if (response['success'] == true) {
        final data = response['data'];
        _binStatus = data['status'] ?? _binStatus;
        _lastUpdateMessage =
        'Sent: ${_fillPercentage}% · ${_binStatus.replaceAll('_', ' ').toUpperCase()}';
        if (data['alert_created'] == true && !_alertTriggered) {
          _alertTriggered = true;
        }
      } else {
        _lastUpdateMessage = 'API error: ${response['message']}';
      }
    } catch (e) {
      _lastUpdateMessage = 'Detection error: $e';
    }

    _isDetecting = false;
    notifyListeners();
  }

  // ── Decode JPEG and compute luminance grid (runs in isolate) ──────────────
  // This is a top-level function so it can be used with compute()
  // Returns a flat list of [_gridRows * _gridCols] average luminance values
  // focusing on the BOTTOM 60% of the image (where trash accumulates)
  static List<double>? _decodeAndGetGrid(Uint8List bytes) {
    try {
      // This properly decodes JPEG to raw RGB pixels
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final w = image.width;
      final h = image.height;

      // Analyse only bottom 60% of the image
      final startY = (h * 0.40).toInt();
      final analysisH = h - startY;

      final cellW = w / _gridCols;
      final cellH = analysisH / _gridRows;

      final grid = List<double>.filled(_gridRows * _gridCols, 0.0);

      for (int row = 0; row < _gridRows; row++) {
        for (int col = 0; col < _gridCols; col++) {
          final x0 = (col * cellW).toInt();
          final x1 = ((col + 1) * cellW).toInt().clamp(0, w);
          final y0 = startY + (row * cellH).toInt();
          final y1 = (startY + (row + 1) * cellH).toInt().clamp(0, h);

          double lumSum = 0;
          int count = 0;

          // Sample every 2nd pixel for speed
          for (int py = y0; py < y1; py += 2) {
            for (int px = x0; px < x1; px += 2) {
              final pixel = image.getPixel(px, py);
              // Standard luminance formula: 0.299R + 0.587G + 0.114B
              final lum = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
              lumSum += lum;
              count++;
            }
          }

          grid[row * _gridCols + col] = count > 0 ? lumSum / count : 0;
        }
      }

      return grid;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ██ TEST METHOD — used by the commented-out slider in device_screen.dart
  // ██ Uncomment the slider block in device_screen.dart to enable manual testing
  // ═══════════════════════════════════════════════════════════════════════════
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
      'Manual: ${_fillPercentage}% · ${_binStatus.toUpperCase()}';
    } catch (e) {
      _lastUpdateMessage = 'Send error: $e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }
}