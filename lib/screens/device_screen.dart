// lib/screens/device_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Device mode: camera preview with threshold line + fill estimation
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<AuthProvider>().user!;
      final dp = context.read<DeviceProvider>();
      await dp.initCamera(user.deviceId ?? 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const Icon(Icons.videocam, size: 22),
            const SizedBox(width: 8),
            Text('${user.deviceName ?? "SmartBin Device"}'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, dp, _) {
          return Column(
            children: [
              // ── Camera preview ──────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera feed
                    if (dp.isCameraInitialized &&
                        dp.cameraController != null)
                      CameraPreview(dp.cameraController!)
                    else
                      Container(
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text('Initializing camera...',
                                  style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),

                    // ── Threshold line at 90% from top ────────────────────
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ThresholdLinePainter(
                            fillPercentage: dp.fillPercentage),
                      ),
                    ),

                    // ── Fill overlay (semi-transparent) ───────────────────
                    if (dp.fillPercentage > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: MediaQuery.of(context).size.height *
                            0.4 *
                            (dp.fillPercentage / 100),
                        child: Container(
                          color: _fillColor(dp.fillPercentage)
                              .withOpacity(0.15),
                        ),
                      ),

                    // ── Running indicator ─────────────────────────────────
                    if (dp.isRunning)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: _PulsingDot()),
                              SizedBox(width: 6),
                              Text('MONITORING',
                                  style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),

                    // ── Alert banner ──────────────────────────────────────
                    if (dp.alertTriggered)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('⚠ BIN IS FULL — ALERT SENT',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Status panel ────────────────────────────────────────────
              Container(
                color: Colors.grey.shade900,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Fill percentage + status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatusTile(
                          label: 'Fill Level',
                          value: '${dp.fillPercentage}%',
                          color: _fillColor(dp.fillPercentage),
                          icon: Icons.water_drop_outlined,
                        ),
                        _StatusTile(
                          label: 'Status',
                          value: dp.binStatus
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          color: _fillColor(dp.fillPercentage),
                          icon: Icons.info_outline,
                        ),
                        _StatusTile(
                          label: 'Device ID',
                          value: '#${user.deviceId ?? "?"}',
                          color: Colors.blue,
                          icon: Icons.phone_android,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Fill bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: dp.fillPercentage / 100,
                        minHeight: 14,
                        backgroundColor: Colors.grey.shade700,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _fillColor(dp.fillPercentage)),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Last update message
                    if (dp.lastUpdateMessage.isNotEmpty)
                      Text(dp.lastUpdateMessage,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),

                    const SizedBox(height: 14),

                    // Start / Stop button
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: dp.isCameraInitialized
                                ? (dp.isRunning
                                ? dp.stopMonitoring
                                : dp.startMonitoring)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: dp.isRunning
                                  ? Colors.red.shade700
                                  : const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: Icon(dp.isRunning
                                ? Icons.stop
                                : Icons.play_arrow),
                            label: Text(dp.isRunning
                                ? 'Stop Monitoring'
                                : 'Start Monitoring'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Manual test slider
                    Row(
                      children: [
                        const Text('Test:',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: dp.fillPercentage.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 20,
                            label: '${dp.fillPercentage}%',
                            activeColor: _fillColor(dp.fillPercentage),
                            onChanged: (v) =>
                                dp.setFillManually(v.toInt()),
                          ),
                        ),
                        Text('${dp.fillPercentage}%',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _fillColor(int pct) {
    if (pct >= 90) return Colors.red;
    if (pct >= 70) return Colors.orange;
    return Colors.green;
  }
}

// ── Threshold line painter ────────────────────────────────────────────────────
class _ThresholdLinePainter extends CustomPainter {
  final int fillPercentage;
  _ThresholdLinePainter({required this.fillPercentage});

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed threshold at 10% from top (= 90% fill level marker)
    final double thresholdY = size.height * 0.10;

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Draw dashed line
    const dashWidth = 14.0;
    const gapWidth = 8.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, thresholdY), Offset(x + dashWidth, thresholdY), linePaint);
      x += dashWidth + gapWidth;
    }

    // Label background
    const label = '90% THRESHOLD';
    final textPainter = TextPainter(
      text: const TextSpan(
        text: label,
        style: TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.greenAccent),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(8, thresholdY - 16));

    // If garbage level crosses threshold, draw fill level line
    if (fillPercentage > 0) {
      final fillY = size.height * (1 - fillPercentage / 100);
      final fillPaint = Paint()
        ..color = fillPercentage >= 90
            ? Colors.red
            : fillPercentage >= 70
            ? Colors.orange
            : Colors.green
        ..strokeWidth = 2.0;

      canvas.drawLine(Offset(0, fillY), Offset(size.width, fillY), fillPaint);
    }
  }

  @override
  bool shouldRepaint(_ThresholdLinePainter old) =>
      old.fillPercentage != fillPercentage;
}

// ── Status tile widget ────────────────────────────────────────────────────────
class _StatusTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatusTile(
      {required this.label,
        required this.value,
        required this.color,
        required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}

// ── Pulsing dot animation ─────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
          decoration: const BoxDecoration(
              color: Colors.greenAccent, shape: BoxShape.circle)),
    );
  }
}