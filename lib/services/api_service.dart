// lib/services/api_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Centralised HTTP service for SmartBin REST API
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Change this to your server IP / domain ───────────────────────────────
  // static const String baseUrl = 'http://192.168.31.13:8080/smartbin';
  static const String baseUrl = "http://127.0.0.1:8080/smartbin";
  // ─────────────────────────────────────────────────────────────────────────

  static const Duration _timeout = Duration(seconds: 10);

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(

      String email, String password) async {

    final response = await http
        .post(
      Uri.parse('$baseUrl/login.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    )
        .timeout(_timeout);
    print("LOGIN URL: $baseUrl/login.php");
    print("RESPONSE: ${response.body}");

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Bins ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getBins({String? status}) async {
    String url = '$baseUrl/get_bins.php';
    if (status != null) url += '?status=$status';

    final response =
    await http.get(Uri.parse(url)).timeout(_timeout);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getBinDetail(int binId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/get_bins.php?bin_id=$binId'))
        .timeout(_timeout);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Device Updates ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateBinStatus(
      int deviceId, int fillPercentage) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/update_bin_status.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_id': deviceId,
        'fill_percentage': fillPercentage,
      }),
    )
        .timeout(_timeout);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Alerts ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAlerts(
      {bool includeResolved = false}) async {
    final url = includeResolved
        ? '$baseUrl/alerts.php?resolved=true'
        : '$baseUrl/alerts.php';

    final response =
    await http.get(Uri.parse(url)).timeout(_timeout);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> resolveAlert(int alertId) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/alerts.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'resolve', 'alert_id': alertId}),
    )
        .timeout(_timeout);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}