// lib/screens/alerts_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bin_provider.dart';
import '../models/models.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all, color: Colors.white),
            label:
            const Text('Resolve All', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final bp = context.read<BinProvider>();
              // Resolve each alert
              for (final alert in bp.alerts.where((a) => !a.resolved)) {
                await bp.resolveAlert(alert.alertId);
              }
            },
          ),
        ],
      ),
      body: Consumer<BinProvider>(
        builder: (context, bp, _) {
          final activeAlerts = bp.alerts.where((a) => !a.resolved).toList();
          final resolvedAlerts = bp.alerts.where((a) => a.resolved).toList();

          if (bp.alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No alerts', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (activeAlerts.isNotEmpty) ...[
                _sectionHeader('Active Alerts (${activeAlerts.length})',
                    Colors.red),
                const SizedBox(height: 8),
                ...activeAlerts
                    .map((a) => _AlertCard(alert: a, onResolve: () async {
                  await context.read<BinProvider>().resolveAlert(a.alertId);
                })),
              ],
              if (resolvedAlerts.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionHeader(
                    'Resolved (${resolvedAlerts.length})', Colors.green),
                const SizedBox(height: 8),
                ...resolvedAlerts.map((a) => _AlertCard(alert: a)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: color,
            margin: const EdgeInsets.only(right: 8)),
        Text(text,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onResolve;
  const _AlertCard({required this.alert, this.onResolve});

  @override
  Widget build(BuildContext context) {
    final isActive = !alert.resolved;
    final color = alert.alertType == 'bin_full'
        ? Colors.red
        : alert.alertType == 'bin_almost_full'
        ? Colors.orange
        : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: isActive ? color : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.alertType.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive ? color : Colors.grey,
                        fontSize: 13),
                  ),
                ),
                if (isActive && onResolve != null)
                  TextButton(
                    onPressed: onResolve,
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 30)),
                    child: const Text('Resolve',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(alert.message,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(alert.binLocation ?? 'Unknown',
                    style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Text(alert.createdAt,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}