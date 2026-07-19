class CommercialChecklistModel {
  // I. REFERENCE
  String ioNumber;
  String dateIssued;
  String dateInspected;

  // II. NATURE OF INSPECTION CONDUCTED
  String? inspectionNature; // 'Construction', 'PEZA', 'Occupancy', 'BusinessPermit', 'Verification', 'Others'
  String? verificationType; // 'NTC', 'NTCV', 'Abatement', 'Closure'
  String? natureOthersSpecify;

  // III. REQUIREMENTS
  String? fsccrRequired; // 'Yes', 'No', 'N/A'
  String? fsmrRequired; // 'Yes', 'No', 'N/A'

  // IV. GENERAL INFORMATION
  String buildingName;
  String address;
  String businessName;
  String natureOfBusiness;
  String ownerRepresentative;
  String contactNo;

  // Occupancy Permits Info
  String fsecNo;
  String fsecDateIssued;
  String buildingPermitNo;
  String buildingPermitDateIssued;

  // Business Permit Info
  String fsicNoLatest;
  String fsicDateIssued;
  String fireDrillCertNo;
  String fireDrillDateIssued;
  String businessPermitNo;
  String businessPermitDateIssued;
  String fireInsurancePolicyNo;
  String fireInsuranceDateIssued;

  // BUILDING SPECIFICATIONS
  String? constructionType; // Type I to Type V
  String? interiorFinishWalls; // Class A, Class B, Class C
  String? interiorFinishFloor; // Class I, Class II

  // Sectional Occupancy
  String basementUsage;
  String groundFloorUsage;
  String secondFloorUsage;
  String thirdFloorUsage;
  String fourthFloorUsage;
  String nthFloorUsage;

  // General Occupancy Classification
  String? occupancyClassification; // Assembly, Educational, Day Care, Health Care, Detention, Residential, Residential Board and Care, Mercantile, Business, Industrial, Storage, Special Structure

  // Other Information
  String occupantLoad;
  String numberOfStories;
  String buildingHeight;
  String? isHighrise; // 'Yes', 'No'

  // V. MEANS OF EGRESS, VI. SIGNS, VII. HAZARD, VIII. FIRE PROTECTION (Item Statuses: 'Passed', 'Failed', 'N/A')
  Map<String, String> egressAccessStatus;
  Map<String, String> exitComponentsStatus;
  Map<String, String> egressRequirementsStatus;
  Map<String, String> exitSignageStatus;
  Map<String, String> hazardStatus;
  Map<String, String> fireProtectionStatus;

  // Dimensions & Width Inputs
  Map<String, String> itemDimensions;

  // IX. DEFECTS & RECOMMENDATIONS
  String defectsSummary;
  String? recommendationAction; // 'FSIC', 'NoticeToComply', 'NoticeToCorrectViolation', 'ClosureOrder', 'AbatementOrder', 'NOD'
  String inspectorName;
  String teamLeaderName;
  String fireMarshalName;

  CommercialChecklistModel({
    this.ioNumber = '',
    this.dateIssued = '',
    this.dateInspected = '',
    this.inspectionNature,
    this.verificationType,
    this.natureOthersSpecify = '',
    this.fsccrRequired,
    this.fsmrRequired,
    this.buildingName = '',
    this.address = '',
    this.businessName = '',
    this.natureOfBusiness = '',
    this.ownerRepresentative = '',
    this.contactNo = '',
    this.fsecNo = '',
    this.fsecDateIssued = '',
    this.buildingPermitNo = '',
    this.buildingPermitDateIssued = '',
    this.fsicNoLatest = '',
    this.fsicDateIssued = '',
    this.fireDrillCertNo = '',
    this.fireDrillDateIssued = '',
    this.businessPermitNo = '',
    this.businessPermitDateIssued = '',
    this.fireInsurancePolicyNo = '',
    this.fireInsuranceDateIssued = '',
    this.constructionType,
    this.interiorFinishWalls,
    this.interiorFinishFloor,
    this.basementUsage = '',
    this.groundFloorUsage = '',
    this.secondFloorUsage = '',
    this.thirdFloorUsage = '',
    this.fourthFloorUsage = '',
    this.nthFloorUsage = '',
    this.occupancyClassification,
    this.occupantLoad = '',
    this.numberOfStories = '',
    this.buildingHeight = '',
    this.isHighrise,
    Map<String, String>? egressAccessStatus,
    Map<String, String>? exitComponentsStatus,
    Map<String, String>? egressRequirementsStatus,
    Map<String, String>? exitSignageStatus,
    Map<String, String>? hazardStatus,
    Map<String, String>? fireProtectionStatus,
    Map<String, String>? itemDimensions,
    this.defectsSummary = '',
    this.recommendationAction,
    this.inspectorName = '',
    this.teamLeaderName = '',
    this.fireMarshalName = '',
  })  : egressAccessStatus = egressAccessStatus ?? {},
        exitComponentsStatus = exitComponentsStatus ?? {},
        egressRequirementsStatus = egressRequirementsStatus ?? {},
        exitSignageStatus = exitSignageStatus ?? {},
        hazardStatus = hazardStatus ?? {},
        fireProtectionStatus = fireProtectionStatus ?? {},
        itemDimensions = itemDimensions ?? {};

  Map<String, dynamic> toJson() {
    return {
      'ioNumber': ioNumber,
      'dateIssued': dateIssued,
      'dateInspected': dateInspected,
      'inspectionNature': inspectionNature,
      'verificationType': verificationType,
      'natureOthersSpecify': natureOthersSpecify,
      'fsccrRequired': fsccrRequired,
      'fsmrRequired': fsmrRequired,
      'generalInfo': {
        'buildingName': buildingName,
        'address': address,
        'businessName': businessName,
        'natureOfBusiness': natureOfBusiness,
        'ownerRepresentative': ownerRepresentative,
        'contactNo': contactNo,
        'fsecNo': fsecNo,
        'fsecDateIssued': fsecDateIssued,
        'buildingPermitNo': buildingPermitNo,
        'buildingPermitDateIssued': buildingPermitDateIssued,
        'fsicNoLatest': fsicNoLatest,
        'fsicDateIssued': fsicDateIssued,
        'fireDrillCertNo': fireDrillCertNo,
        'fireDrillDateIssued': fireDrillDateIssued,
        'businessPermitNo': businessPermitNo,
        'businessPermitDateIssued': businessPermitDateIssued,
        'fireInsurancePolicyNo': fireInsurancePolicyNo,
        'fireInsuranceDateIssued': fireInsuranceDateIssued,
      },
      'buildingSpecifications': {
        'constructionType': constructionType,
        'interiorFinishWalls': interiorFinishWalls,
        'interiorFinishFloor': interiorFinishFloor,
        'sectionalOccupancy': {
          'basement': basementUsage,
          'groundFloor': groundFloorUsage,
          'secondFloor': secondFloorUsage,
          'thirdFloor': thirdFloorUsage,
          'fourthFloor': fourthFloorUsage,
          'nthFloor': nthFloorUsage,
        },
        'occupancyClassification': occupancyClassification,
        'occupantLoad': occupantLoad,
        'numberOfStories': numberOfStories,
        'buildingHeight': buildingHeight,
        'isHighrise': isHighrise,
      },
      'egressAccessStatus': egressAccessStatus,
      'exitComponentsStatus': exitComponentsStatus,
      'egressRequirementsStatus': egressRequirementsStatus,
      'exitSignageStatus': exitSignageStatus,
      'hazardStatus': hazardStatus,
      'fireProtectionStatus': fireProtectionStatus,
      'itemDimensions': itemDimensions,
      'defectsSummary': defectsSummary,
      'recommendationAction': recommendationAction,
      'signatories': {
        'inspectorName': inspectorName,
        'teamLeaderName': teamLeaderName,
        'fireMarshalName': fireMarshalName,
      },
    };
  }

  factory CommercialChecklistModel.fromJson(Map<String, dynamic> json) {
    final gen = json['generalInfo'] as Map<String, dynamic>? ?? {};
    final spec = json['buildingSpecifications'] as Map<String, dynamic>? ?? {};
    final secOcc = spec['sectionalOccupancy'] as Map<String, dynamic>? ?? {};
    final sig = json['signatories'] as Map<String, dynamic>? ?? {};

    return CommercialChecklistModel(
      ioNumber: json['ioNumber'] ?? '',
      dateIssued: json['dateIssued'] ?? '',
      dateInspected: json['dateInspected'] ?? '',
      inspectionNature: json['inspectionNature'],
      verificationType: json['verificationType'],
      natureOthersSpecify: json['natureOthersSpecify'] ?? '',
      fsccrRequired: json['fsccrRequired'],
      fsmrRequired: json['fsmrRequired'],
      buildingName: gen['buildingName'] ?? '',
      address: gen['address'] ?? '',
      businessName: gen['businessName'] ?? '',
      natureOfBusiness: gen['natureOfBusiness'] ?? '',
      ownerRepresentative: gen['ownerRepresentative'] ?? '',
      contactNo: gen['contactNo'] ?? '',
      fsecNo: gen['fsecNo'] ?? '',
      fsecDateIssued: gen['fsecDateIssued'] ?? '',
      buildingPermitNo: gen['buildingPermitNo'] ?? '',
      buildingPermitDateIssued: gen['buildingPermitDateIssued'] ?? '',
      fsicNoLatest: gen['fsicNoLatest'] ?? '',
      fsicDateIssued: gen['fsicDateIssued'] ?? '',
      fireDrillCertNo: gen['fireDrillCertNo'] ?? '',
      fireDrillDateIssued: gen['fireDrillDateIssued'] ?? '',
      businessPermitNo: gen['businessPermitNo'] ?? '',
      businessPermitDateIssued: gen['businessPermitDateIssued'] ?? '',
      fireInsurancePolicyNo: gen['fireInsurancePolicyNo'] ?? '',
      fireInsuranceDateIssued: gen['fireInsuranceDateIssued'] ?? '',
      constructionType: spec['constructionType'],
      interiorFinishWalls: spec['interiorFinishWalls'],
      interiorFinishFloor: spec['interiorFinishFloor'],
      basementUsage: secOcc['basement'] ?? '',
      groundFloorUsage: secOcc['groundFloor'] ?? '',
      secondFloorUsage: secOcc['secondFloor'] ?? '',
      thirdFloorUsage: secOcc['thirdFloor'] ?? '',
      fourthFloorUsage: secOcc['fourthFloor'] ?? '',
      nthFloorUsage: secOcc['nthFloor'] ?? '',
      occupancyClassification: spec['occupancyClassification'],
      occupantLoad: spec['occupantLoad'] ?? '',
      numberOfStories: spec['numberOfStories'] ?? '',
      buildingHeight: spec['buildingHeight'] ?? '',
      isHighrise: spec['isHighrise'],
      egressAccessStatus: Map<String, String>.from(json['egressAccessStatus'] ?? {}),
      exitComponentsStatus: Map<String, String>.from(json['exitComponentsStatus'] ?? {}),
      egressRequirementsStatus: Map<String, String>.from(json['egressRequirementsStatus'] ?? {}),
      exitSignageStatus: Map<String, String>.from(json['exitSignageStatus'] ?? {}),
      hazardStatus: Map<String, String>.from(json['hazardStatus'] ?? {}),
      fireProtectionStatus: Map<String, String>.from(json['fireProtectionStatus'] ?? {}),
      itemDimensions: Map<String, String>.from(json['itemDimensions'] ?? {}),
      defectsSummary: json['defectsSummary'] ?? '',
      recommendationAction: json['recommendationAction'],
      inspectorName: sig['inspectorName'] ?? '',
      teamLeaderName: sig['teamLeaderName'] ?? '',
      fireMarshalName: sig['fireMarshalName'] ?? '',
    );
  }
}
