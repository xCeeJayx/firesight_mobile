enum UserRole {
  stationOfficer,
  fireInspector,
  communityRiskOfficer,
  publicGuest,
}

extension UserRoleExtension on UserRole {
  String toDbString() {
    switch (this) {
      case UserRole.stationOfficer:
        return 'station_officer';
      case UserRole.fireInspector:
        return 'fire_inspector';
      case UserRole.communityRiskOfficer:
        return 'community_risk_officer';
      case UserRole.publicGuest:
        return 'public_guest';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.stationOfficer:
        return 'Station Officer (Admin)';
      case UserRole.fireInspector:
        return 'FSIC Fire Inspector';
      case UserRole.communityRiskOfficer:
        return 'OLP Community Risk Officer';
      case UserRole.publicGuest:
        return 'Public Citizen Guest';
    }
  }

  String get defaultRoute {
    switch (this) {
      case UserRole.stationOfficer:
        return '/admin/dashboard';
      case UserRole.fireInspector:
        return '/inspector/dashboard';
      case UserRole.communityRiskOfficer:
        return '/risk-mapping/dashboard';
      case UserRole.publicGuest:
        return '/public/map';
    }
  }

  bool get isAdmin => this == UserRole.stationOfficer;
  bool get isFireInspector => this == UserRole.fireInspector;
  bool get isCommunityRiskOfficer => this == UserRole.communityRiskOfficer;
  bool get isPublicGuest => this == UserRole.publicGuest;

  bool canAccessFsic() => this == UserRole.stationOfficer || this == UserRole.fireInspector;
  bool canAccessOlp() => this == UserRole.stationOfficer || this == UserRole.communityRiskOfficer;
  bool canAccessAdmin() => this == UserRole.stationOfficer;

  static UserRole fromString(String? roleStr) {
    if (roleStr == null) return UserRole.publicGuest;
    final normalized = roleStr.trim().toLowerCase();
    switch (normalized) {
      case 'station_officer':
      case 'admin':
        return UserRole.stationOfficer;
      case 'fire_inspector':
      case 'inspector':
        return UserRole.fireInspector;
      case 'community_risk_officer':
      case 'risk_officer':
      case 'cro':
        return UserRole.communityRiskOfficer;
      case 'public_guest':
      case 'guest':
      default:
        return UserRole.publicGuest;
    }
  }
}
