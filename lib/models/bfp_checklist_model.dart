enum CheckStatus {
  pass,
  fail,
  notApplicable,
}

extension CheckStatusExtension on CheckStatus {
  String get name {
    switch (this) {
      case CheckStatus.pass:
        return 'pass';
      case CheckStatus.fail:
        return 'fail';
      case CheckStatus.notApplicable:
        return 'notApplicable';
    }
  }

  static CheckStatus? fromString(String? value) {
    switch (value) {
      case 'pass':
        return CheckStatus.pass;
      case 'fail':
        return CheckStatus.fail;
      case 'notApplicable':
        return CheckStatus.notApplicable;
      default:
        return null; // Represents Unanswered
    }
  }
}

class BfpChecklistModel {
  GeneralInformation generalInfo;
  MeansOfEgress meansOfEgress;
  FireProtectionSystems fireProtectionSystems;

  BfpChecklistModel({
    GeneralInformation? generalInfo,
    MeansOfEgress? meansOfEgress,
    FireProtectionSystems? fireProtectionSystems,
  })  : generalInfo = generalInfo ?? GeneralInformation(),
        meansOfEgress = meansOfEgress ?? MeansOfEgress(),
        fireProtectionSystems = fireProtectionSystems ?? FireProtectionSystems();

  factory BfpChecklistModel.fromJson(Map<String, dynamic> json) {
    return BfpChecklistModel(
      generalInfo: json['generalInfo'] != null
          ? GeneralInformation.fromJson(json['generalInfo'])
          : null,
      meansOfEgress: json['meansOfEgress'] != null
          ? MeansOfEgress.fromJson(json['meansOfEgress'])
          : null,
      fireProtectionSystems: json['fireProtectionSystems'] != null
          ? FireProtectionSystems.fromJson(json['fireProtectionSystems'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generalInfo': generalInfo.toJson(),
      'meansOfEgress': meansOfEgress.toJson(),
      'fireProtectionSystems': fireProtectionSystems.toJson(),
    };
  }
}

class GeneralInformation {
  String? businessName;
  String? ownersName;
  String? ioTrackingNumber;
  String? contactNumber;
  // Scalable design: Add more fields here from Section IV of the checklist

  GeneralInformation({
    this.businessName,
    this.ownersName,
    this.ioTrackingNumber,
    this.contactNumber,
  });

  factory GeneralInformation.fromJson(Map<String, dynamic> json) {
    return GeneralInformation(
      businessName: json['businessName'],
      ownersName: json['ownersName'],
      ioTrackingNumber: json['ioTrackingNumber'],
      contactNumber: json['contactNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'ownersName': ownersName,
      'ioTrackingNumber': ioTrackingNumber,
      'contactNumber': contactNumber,
    };
  }
}

class MeansOfEgress {
  CheckStatus? exitDoorsWidth;
  CheckStatus? corridorsClearance;
  CheckStatus? stairwayClearance;
  // Scalable design: Add more fields here from Section V of the checklist

  MeansOfEgress({
    this.exitDoorsWidth,
    this.corridorsClearance,
    this.stairwayClearance,
  });

  factory MeansOfEgress.fromJson(Map<String, dynamic> json) {
    return MeansOfEgress(
      exitDoorsWidth: CheckStatusExtension.fromString(json['exitDoorsWidth']),
      corridorsClearance: CheckStatusExtension.fromString(json['corridorsClearance']),
      stairwayClearance: CheckStatusExtension.fromString(json['stairwayClearance']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exitDoorsWidth': exitDoorsWidth?.name,
      'corridorsClearance': corridorsClearance?.name,
      'stairwayClearance': stairwayClearance?.name,
    };
  }
}

class FireProtectionSystems {
  CheckStatus? fireAlarms;
  CheckStatus? extinguisherPressureLogs;
  CheckStatus? sprinklerInfrastructure;
  // Scalable design: Add more fields here from Section VIII of the checklist

  FireProtectionSystems({
    this.fireAlarms,
    this.extinguisherPressureLogs,
    this.sprinklerInfrastructure,
  });

  factory FireProtectionSystems.fromJson(Map<String, dynamic> json) {
    return FireProtectionSystems(
      fireAlarms: CheckStatusExtension.fromString(json['fireAlarms']),
      extinguisherPressureLogs: CheckStatusExtension.fromString(json['extinguisherPressureLogs']),
      sprinklerInfrastructure: CheckStatusExtension.fromString(json['sprinklerInfrastructure']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fireAlarms': fireAlarms?.name,
      'extinguisherPressureLogs': extinguisherPressureLogs?.name,
      'sprinklerInfrastructure': sprinklerInfrastructure?.name,
    };
  }
}
