// lib/providers/bin_provider.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class BinProvider extends ChangeNotifier {
  List<BinModel> _bins = [];
  List<AlertModel> _alerts = [];
  bool _loading = false;
  String _error = '';
  Map<String, int> _summary = {};
  Timer? _autoRefreshTimer;

  List<BinModel> get bins => _bins;
  List<AlertModel> get alerts => _alerts;
  bool get loading => _loading;
  String get error => _error;
  Map<String, int> get summary => _summary;
  int get unresolvedAlerts => _alerts.where((a) => !a.resolved).length;

  // ── Fetch all bins ────────────────────────────────────────────────────────
  Future<void> fetchBins() async {
    _loading = true;
    _error = '';
    notifyListeners();

    try {
      final response = await ApiService.getBins();
      if (response['success'] == true) {
        final data = response['data'];
        _bins = (data['bins'] as List)
            .map((b) => BinModel.fromJson(b))
            .toList();
        _summary = Map<String, int>.from(data['summary'] ?? {});
      } else {
        _error = response['message'] ?? 'Failed to load bins';
      }
    } catch (e) {
      _error = 'Network error: $e';
    }

    _loading = false;
    notifyListeners();
  }

  // ── Fetch alerts ──────────────────────────────────────────────────────────
  Future<void> fetchAlerts() async {
    try {
      final response = await ApiService.getAlerts();
      if (response['success'] == true) {
        _alerts = (response['data']['alerts'] as List)
            .map((a) => AlertModel.fromJson(a))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Resolve alert ─────────────────────────────────────────────────────────
  Future<void> resolveAlert(int alertId) async {
    try {
      final response = await ApiService.resolveAlert(alertId);
      if (response['success'] == true) {
        _alerts = _alerts.map((a) {
          if (a.alertId == alertId) {
            return AlertModel.fromJson({
              ...{
                'alert_id': a.alertId,
                'bin_id': a.binId,
                'alert_type': a.alertType,
                'message': a.message,
                'resolved': true,
                'created_at': a.createdAt,
                'bin_location': a.binLocation,
                'fill_percentage': a.fillPercentage,
                'bin_status': a.binStatus,
              }
            });
          }
          return a;
        }).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Auto-refresh (30s) ────────────────────────────────────────────────────
  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchBins();
      fetchAlerts();
    });
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}