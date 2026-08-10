import 'package:flutter/material.dart';

/// Representation of an emergency report bound to public.emergency_reports
class EmergencyReportModel {
  final String id;
  final String? reporterName;
  final String? reporterContact;
  final String incidentType;
  final String barangay;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String? photoUrl;
  final String status;
  final DateTime? createdAt;

  const EmergencyReportModel({
    required this.id,
    this.reporterName,
    this.reporterContact,
    required this.incidentType,
    required this.barangay,
    this.address,
    this.latitude,
    this.longitude,
    this.description,
    this.photoUrl,
    this.status = 'Unverified',
    this.createdAt,
  });

  factory EmergencyReportModel.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    return EmergencyReportModel(
      id: json['id']?.toString() ?? '',
      reporterName: json['reporter_name']?.toString(),
      reporterContact: json['reporter_contact']?.toString(),
      incidentType: json['incident_type']?.toString() ?? 'Emergency Incident',
      barangay: json['barangay']?.toString() ?? 'Unknown Barangay',
      address: json['address']?.toString(),
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      description: json['description']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      status: json['status']?.toString() ?? 'Unverified',
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_name': reporterName,
      'reporter_contact': reporterContact,
      'incident_type': incidentType,
      'barangay': barangay,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'photo_url': photoUrl,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  EmergencyReportModel copyWith({
    String? id,
    String? reporterName,
    String? reporterContact,
    String? incidentType,
    String? barangay,
    String? address,
    double? latitude,
    double? longitude,
    String? description,
    String? photoUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return EmergencyReportModel(
      id: id ?? this.id,
      reporterName: reporterName ?? this.reporterName,
      reporterContact: reporterContact ?? this.reporterContact,
      incidentType: incidentType ?? this.incidentType,
      barangay: barangay ?? this.barangay,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Relative humanized time (e.g. "Just now", "5m ago", "2h ago", "Yesterday")
  String get formattedTimeAgo {
    if (createdAt == null) return 'Recent';
    final now = DateTime.now();
    final diff = now.difference(createdAt!);

    if (diff.inSeconds < 45) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt!.month}/${createdAt!.day}/${createdAt!.year}';
    }
  }

  /// Format exact timestamp (e.g. "Aug 10, 2026 • 12:15 PM")
  String get formattedDateTime {
    if (createdAt == null) return 'N/A';
    final c = createdAt!;
    final hour = c.hour == 0 ? 12 : (c.hour > 12 ? c.hour - 12 : c.hour);
    final minute = c.minute.toString().padLeft(2, '0');
    final period = c.hour >= 12 ? 'PM' : 'AM';
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = monthNames[c.month - 1];
    return '$month ${c.day}, ${c.year} • $hour:$minute $period';
  }

  /// Color associated with the incident type
  Color get incidentColor {
    final type = incidentType.toLowerCase();
    if (type.contains('structural') || type.contains('building fire')) {
      return const Color(0xFFDC2626); // BFP Red
    } else if (type.contains('grass') || type.contains('garbage')) {
      return const Color(0xFFEA580C); // Orange
    } else if (type.contains('electrical') || type.contains('spaghetti')) {
      return const Color(0xFFD97706); // Amber
    } else if (type.contains('hydrant')) {
      return const Color(0xFF2563EB); // Blue
    } else {
      return const Color(0xFF7C3AED); // Purple
    }
  }

  /// Icon associated with incident type
  IconData get incidentIcon {
    final type = incidentType.toLowerCase();
    if (type.contains('structural') || type.contains('building fire')) {
      return Icons.local_fire_department_rounded;
    } else if (type.contains('grass') || type.contains('garbage')) {
      return Icons.whatshot_rounded;
    } else if (type.contains('electrical') || type.contains('spaghetti')) {
      return Icons.electric_bolt_rounded;
    } else if (type.contains('hydrant')) {
      return Icons.water_drop_rounded;
    } else {
      return Icons.warning_amber_rounded;
    }
  }

  /// Status background color
  Color get statusBgColor {
    switch (status.toLowerCase()) {
      case 'verified':
        return const Color(0xFFDCFCE7); // Light green
      case 'responding':
      case 'dispatched':
        return const Color(0xFFFEF3C7); // Light amber
      case 'resolved':
        return const Color(0xFFE0E7FF); // Light indigo
      case 'false alarm':
        return const Color(0xFFF1F5F9); // Light slate
      case 'unverified':
      default:
        return const Color(0xFFFEE2E2); // Light red
    }
  }

  /// Status text color
  Color get statusTextColor {
    switch (status.toLowerCase()) {
      case 'verified':
        return const Color(0xFF15803D); // Green
      case 'responding':
      case 'dispatched':
        return const Color(0xFFB45309); // Amber
      case 'resolved':
        return const Color(0xFF4338CA); // Indigo
      case 'false alarm':
        return const Color(0xFF64748B); // Slate
      case 'unverified':
      default:
        return const Color(0xFFDC2626); // Red
    }
  }

  bool get isHighPriority {
    final s = status.toLowerCase();
    return s == 'unverified' || s == 'verified' || s == 'responding';
  }

  bool get isVerified {
    final s = status.toLowerCase();
    return s == 'verified' || s == 'responding' || s == 'dispatched';
  }
}
