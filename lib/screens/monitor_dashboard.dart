// lib/screens/monitor_dashboard.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../providers/auth_provider.dart';
import '../providers/bin_provider.dart';
import '../models/models.dart';
import '../widgets/bin_card.dart';
import 'alerts_screen.dart';

class MonitorDashboard extends StatefulWidget {
  const MonitorDashboard({super.key});

  @override
  State<MonitorDashboard> createState() => _MonitorDashboardState();
}

class _MonitorDashboardState extends State<MonitorDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bp = context.read<BinProvider>();
      bp.fetchBins();
      bp.fetchAlerts();
      bp.startAutoRefresh();
    });
  }

  @override
  void dispose() {
    context.read<BinProvider>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, size: 24),
            SizedBox(width: 8),
            Text('SmartBin Monitor'),
          ],
        ),
        actions: [
          // Alert bell
          Consumer<BinProvider>(
            builder: (_, bp, __) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const AlertsScreen())),
                ),
                if (bp.unresolvedAlerts > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '${bp.unresolvedAlerts}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<BinProvider>().fetchBins();
              context.read<BinProvider>().fetchAlerts();
            },
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Consumer<BinProvider>(
        builder: (context, bp, _) {
          if (bp.loading && bp.bins.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading bins...'),
                ],
              ),
            );
          }

          if (bp.error.isNotEmpty && bp.bins.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(bp.error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: bp.fetchBins,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await bp.fetchBins();
              await bp.fetchAlerts();
            },
            child: CustomScrollView(
              slivers: [
                // ── Summary cards ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SummaryBar(summary: bp.summary),
                ),

                // ── Section header ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('All Bins (${bp.bins.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        if (bp.loading)
                          const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ),
                ),

                // ── Bin grid ───────────────────────────────────────────────
                bp.bins.isEmpty
                    ? const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 60, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No bins registered yet',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
                    : SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    itemBuilder: (context, index) =>
                        BinCard(bin: bp.bins[index]),
                    childCount: bp.bins.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Summary Bar Widget ────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final Map<String, int> summary;
  const _SummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF00897B).withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          _SummaryChip(
              label: 'Total',
              count: summary['total'] ?? 0,
              color: Colors.blueGrey),
          const SizedBox(width: 8),
          _SummaryChip(
              label: 'Normal',
              count: summary['normal'] ?? 0,
              color: Colors.green),
          const SizedBox(width: 8),
          _SummaryChip(
              label: 'Almost Full',
              count: summary['almost_full'] ?? 0,
              color: Colors.orange),
          const SizedBox(width: 8),
          _SummaryChip(
              label: 'Full',
              count: summary['full'] ?? 0,
              color: Colors.red),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: color),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}