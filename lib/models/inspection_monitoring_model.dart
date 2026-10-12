import 'package:flutter/material.dart';

/// Representation of a field monitoring session in public.inspection_monitoring_sessions
class InspectionMonitoringModel {
  final String id;
  final String? inspectorId;
  final String inspectorName;
  final String inspectorRank;
  final String? inspectorBadge;
  final String visitType;
  final String ioReferenceNo;
  final String? relatedOrderNo;
  final String barangay;
  final String? locationAddress;
  final String? establishmentName;
  final String? establishmentId;
  final String status;
  final DateTime startTime;
  final double? startLatitude;
  final double? startLongitude;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? lastLocationUpdate;
  final DateTime? endTime;
  final double? endLatitude;
  final double? endLongitude;
  final int? durationMinutes;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InspectionMonitoringModel({
    required this.id,
    this.inspectorId,
    required this.inspectorName,
    this.inspectorRank = 'FO1',
    this.inspectorBadge,
    required this.visitType,
    required this.ioReferenceNo,
    this.relatedOrderNo,
    required this.barangay,
    this.locationAddress,
    this.establishmentName,
    this.establishmentId,
    this.status = 'ON SITE',
    required this.startTime,
    this.startLatitude,
    this.startLongitude,
    this.currentLatitude,
    this.currentLongitude,
    this.lastLocationUpdate,
    this.endTime,
    this.endLatitude,
    this.endLongitude,
    this.durationMinutes,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  factory InspectionMonitoringModel.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toLocal();
      final str = value.toString().trim();
      if (str.isEmpty) return null;
      final parsed = DateTime.tryParse(str);
      if (parsed == null) return null;
      return parsed.toLocal();
    }

    return InspectionMonitoringModel(
      id: json['id']?.toString() ?? '',
      inspectorId: json['inspector_id']?.toString(),
      inspectorName: json['inspector_name']?.toString() ?? 'Fire Inspector',
      inspectorRank: json['inspector_rank']?.toString() ?? 'FO1',
      inspectorBadge: json['inspector_badge']?.toString(),
      visitType: json['visit_type']?.toString() ?? 'Regular / Initial Inspection',
      ioReferenceNo: json['io_reference_no']?.toString() ?? 'N/A',
      relatedOrderNo: json['related_order_no']?.toString(),
      barangay: json['barangay']?.toString() ?? 'Poblacion',
      locationAddress: json['location_address']?.toString(),
      establishmentName: json['establishment_name']?.toString(),
      establishmentId: json['establishment_id']?.toString(),
      status: json['status']?.toString() ?? 'ON SITE',
      startTime: parseDate(json['start_time']) ?? DateTime.now(),
      startLatitude: parseCoord(json['start_latitude']),
      startLongitude: parseCoord(json['start_longitude']),
      currentLatitude: parseCoord(json['current_latitude']),
      currentLongitude: parseCoord(json['current_longitude']),
      lastLocationUpdate: parseDate(json['last_location_update']),
      endTime: parseDate(json['end_time']),
      endLatitude: parseCoord(json['end_latitude']),
      endLongitude: parseCoord(json['end_longitude']),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      remarks: json['remarks']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspector_id': inspectorId,
      'inspector_name': inspectorName,
      'inspector_rank': inspectorRank,
      'inspector_badge': inspectorBadge,
      'visit_type': visitType,
      'io_reference_no': ioReferenceNo,
      'related_order_no': relatedOrderNo,
      'barangay': barangay,
      'location_address': locationAddress,
      'establishment_name': establishmentName,
      'establishment_id': establishmentId,
      'status': status,
      'start_time': startTime.toUtc().toIso8601String(),
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'last_location_update': lastLocationUpdate?.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'duration_minutes': durationMinutes,
      'remarks': remarks,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  InspectionMonitoringModel copyWith({
    String? id,
    String? inspectorId,
    String? inspectorName,
    String? inspectorRank,
    String? inspectorBadge,
    String? visitType,
    String? ioReferenceNo,
    String? relatedOrderNo,
    String? barangay,
    String? locationAddress,
    String? establishmentName,
    String? establishmentId,
    String? status,
    DateTime? startTime,
    double? startLatitude,
    double? startLongitude,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? lastLocationUpdate,
    DateTime? endTime,
    double? endLatitude,
    double? endLongitude,
    int? durationMinutes,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InspectionMonitoringModel(
      id: id ?? this.id,
      inspectorId: inspectorId ?? this.inspectorId,
      inspectorName: inspectorName ?? this.inspectorName,
      inspectorRank: inspectorRank ?? this.inspectorRank,
      inspectorBadge: inspectorBadge ?? this.inspectorBadge,
      visitType: visitType ?? this.visitType,
      ioReferenceNo: ioReferenceNo ?? this.ioReferenceNo,
      relatedOrderNo: relatedOrderNo ?? this.relatedOrderNo,
      barangay: barangay ?? this.barangay,
      locationAddress: locationAddress ?? this.locationAddress,
      establishmentName: establishmentName ?? this.establishmentName,
      establishmentId: establishmentId ?? this.establishmentId,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      endTime: endTime ?? this.endTime,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isOnSite => status.toUpperCase() == 'ON SITE';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';

  /// Relative elapsed duration while active
  String get elapsedDurationString {
    final now = DateTime.now();
    final diff = now.difference(startTime);
    if (diff.isNegative) {
      return '0m';
    }
    final hours = diff.inHours;
    final minutes = (diff.inMinutes % 60).abs();
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${diff.inMinutes}m';
  }

  /// Final completed duration string
  String get formattedDuration {
    if (durationMinutes != null && durationMinutes! > 0) {
      final hours = durationMinutes! ~/ 60;
      final mins = durationMinutes! % 60;
      if (hours > 0) {
        return '${hours}h ${mins}m';
      }
      return '$durationMinutes mins';
    }
    if (endTime != null) {
      final diff = endTime!.difference(startTime);
      if (diff.isNegative) {
        return '1 min';
      }
      final hours = diff.inHours;
      final mins = (diff.inMinutes % 60).abs();
      if (hours > 0) {
        return '${hours}h ${mins}m';
      }
      return '${diff.inMinutes} mins';
    }
    return elapsedDurationString;
  }

  String get formattedStartTime {
    final hour = startTime.hour == 0 ? 12 : (startTime.hour > 12 ? startTime.hour - 12 : startTime.hour);
    final minute = startTime.minute.toString().padLeft(2, '0');
    final period = startTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String get formattedDate {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = monthNames[startTime.month - 1];
    return '$m ${startTime.day}, ${startTime.year}';
  }

  Color get visitTypeColor {
    final vt = visitType.toLowerCase();
    if (vt.contains('regular') || vt.contains('initial')) {
      return const Color(0xFF0284C7); // Blue
    } else if (vt.contains('ntc verification') || vt.contains('reinspection')) {
      return const Color(0xFFEA580C); // Orange
    } else if (vt.contains('ntcv')) {
      return const Color(0xFFD97706); // Amber
    } else if (vt.contains('abatement')) {
      return const Color(0xFFDC2626); // Red
    } else if (vt.contains('closure') || vt.contains('stoppage')) {
      return const Color(0xFF991B1B); // Dark Red
    }
    return const Color(0xFF7C3AED); // Purple
  }

  IconData get visitTypeIcon {
    final vt = visitType.toLowerCase();
    if (vt.contains('regular') || vt.contains('initial')) {
      return Icons.assignment_outlined;
    } else if (vt.contains('ntc verification') || vt.contains('reinspection')) {
      return Icons.fact_check_outlined;
    } else if (vt.contains('ntcv')) {
      return Icons.warning_amber_rounded;
    } else if (vt.contains('abatement')) {
      return Icons.report_problem_outlined;
    } else if (vt.contains('closure') || vt.contains('stoppage')) {
      return Icons.lock_outline_rounded;
    }
    return Icons.badge_outlined;
  }
}
