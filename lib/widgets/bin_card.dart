// lib/widgets/bin_card.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/models.dart';

class BinCard extends StatelessWidget {
  final BinModel bin;
  const BinCard({super.key, required this.bin});

  Color get _statusColor {
    switch (bin.status) {
      case 'full':
        return Colors.red;
      case 'almost_full':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String get _statusLabel {
    switch (bin.status) {
      case 'full':
        return 'FULL';
      case 'almost_full':
        return 'ALMOST FULL';
      default:
        return 'NORMAL';
    }
  }

  IconData get _statusIcon {
    switch (bin.status) {
      case 'full':
        return Icons.warning_amber_rounded;
      case 'almost_full':
        return Icons.warning_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status color bar ──────────────────────────────────────────────
          Container(
            height: 5,
            color: _statusColor,
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bin ID + status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bin #${bin.binId}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border:
                        Border.all(color: _statusColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, size: 12, color: _statusColor),
                          const SizedBox(width: 3),
                          Text(_statusLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _statusColor,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(bin.location,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Fill percentage bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fill Level',
                            style:
                            TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('${bin.fillPercentage}%',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _statusColor)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bin.fillPercentage / 100,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(_statusColor),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Bin visual icon
                _BinVisual(
                    fillPercentage: bin.fillPercentage,
                    color: _statusColor),

                const SizedBox(height: 10),

                // Device info
                if (bin.deviceName != null)
                  Row(
                    children: [
                      Icon(Icons.phone_android,
                          size: 12,
                          color: bin.deviceStatus == 'active'
                              ? Colors.green
                              : Colors.grey),
                      const SizedBox(width: 4),
                      Text(bin.deviceName!,
                          style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),

                // Last updated
                if (bin.lastUpdated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 11, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(bin.lastUpdated!),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return timestamp;
    }
  }
}

// ── Mini bin visual ───────────────────────────────────────────────────────────
class _BinVisual extends StatelessWidget {
  final int fillPercentage;
  final Color color;
  const _BinVisual({required this.fillPercentage, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 44,
        height: 54,
        child: CustomPaint(
          painter: _BinPainter(fillPercentage / 100, color),
        ),
      ),
    );
  }
}

class _BinPainter extends CustomPainter {
  final double fill;
  final Color color;
  _BinPainter(this.fill, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Bin body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 8, size.width - 8, size.height - 8),
      const Radius.circular(3),
    );

    // Fill area
    final fillHeight = (size.height - 8) * fill;
    final fillTop = 8 + (size.height - 8) - fillHeight;
    final fillRect = Rect.fromLTWH(4, fillTop, size.width - 8, fillHeight);

    canvas.drawRect(fillRect, fillPaint);
    canvas.drawRRect(body, borderPaint);

    // Lid
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 4, size.width, 6),
        const Radius.circular(2),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_BinPainter old) =>
      old.fill != fill || old.color != color;
}