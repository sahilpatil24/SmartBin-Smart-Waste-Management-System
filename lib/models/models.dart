// lib/models/models.dart
// ─────────────────────────────────────────────────────────────────────────────

// ── User Model ───────────────────────────────────────────────────────────────
class UserModel {
  final int userId;
  final String name;
  final String email;
  final String role; // 'monitor' | 'device'
  final int? deviceId;
  final String? deviceName;
  final int? binId;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.deviceId,
    this.deviceName,
    this.binId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'monitor',
      deviceId: json['device_id'] != null
          ? int.tryParse(json['device_id'].toString())
          : null,
      deviceName: json['device_name'],
      binId: json['bin_id'] != null
          ? int.tryParse(json['bin_id'].toString())
          : null,
    );
  }

  bool get isMonitor => role == 'monitor';
  bool get isDevice => role == 'device';
}

// ── Bin Model ─────────────────────────────────────────────────────────────────
class BinModel {
  final int binId;
  final int? deviceId;
  final String location;
  final int fillPercentage;
  final String status; // 'normal' | 'almost_full' | 'full'
  final String? lastUpdated;
  final String? deviceName;
  final String? deviceStatus;

  BinModel({
    required this.binId,
    this.deviceId,
    required this.location,
    required this.fillPercentage,
    required this.status,
    this.lastUpdated,
    this.deviceName,
    this.deviceStatus,
  });

  factory BinModel.fromJson(Map<String, dynamic> json) {
    return BinModel(
      binId: int.tryParse(json['bin_id'].toString()) ?? 0,
      deviceId: json['device_id'] != null
          ? int.tryParse(json['device_id'].toString())
          : null,
      location: json['location'] ?? 'Unknown',
      fillPercentage: int.tryParse(json['fill_percentage'].toString()) ?? 0,
      status: json['status'] ?? 'normal',
      lastUpdated: json['last_updated'],
      deviceName: json['device_name'],
      deviceStatus: json['device_status'],
    );
  }

  bool get isFull => status == 'full';
  bool get isAlmostFull => status == 'almost_full';
  bool get isNormal => status == 'normal';
}

// ── Alert Model ───────────────────────────────────────────────────────────────
class AlertModel {
  final int alertId;
  final int binId;
  final String alertType;
  final String message;
  final bool resolved;
  final String createdAt;
  final String? binLocation;
  final int? fillPercentage;
  final String? binStatus;

  AlertModel({
    required this.alertId,
    required this.binId,
    required this.alertType,
    required this.message,
    required this.resolved,
    required this.createdAt,
    this.binLocation,
    this.fillPercentage,
    this.binStatus,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      alertId: int.tryParse(json['alert_id'].toString()) ?? 0,
      binId: int.tryParse(json['bin_id'].toString()) ?? 0,
      alertType: json['alert_type'] ?? '',
      message: json['message'] ?? '',
      resolved: json['resolved'] == true || json['resolved'] == 1,
      createdAt: json['created_at'] ?? '',
      binLocation: json['bin_location'],
      fillPercentage: json['fill_percentage'] != null
          ? int.tryParse(json['fill_percentage'].toString())
          : null,
      binStatus: json['bin_status'],
    );
  }
}