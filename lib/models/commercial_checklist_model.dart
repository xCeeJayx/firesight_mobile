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
    final secOcc = spec['sectionalOccupancy'] as Map<String, dynamic>? ?? (json['sectionalOccupancy'] as Map<String, dynamic>? ?? {});
    final sig = json['signatories'] as Map<String, dynamic>? ?? (json['signatories'] is Map ? Map<String, dynamic>.from(json['signatories']) : {});

    return CommercialChecklistModel(
      ioNumber: (json['ioNumber'] ?? json['inspection_order_no'] ?? gen['ioNumber'] ?? '').toString(),
      dateIssued: (json['dateIssued'] ?? json['date_issued'] ?? gen['dateIssued'] ?? '').toString(),
      dateInspected: (json['dateInspected'] ?? json['date_inspected'] ?? gen['dateInspected'] ?? '').toString(),
      inspectionNature: json['inspectionNature']?.toString() ?? json['inspection_nature']?.toString() ?? json['nature']?.toString(),
      verificationType: json['verificationType']?.toString() ?? json['verification_type']?.toString(),
      natureOthersSpecify: (json['natureOthersSpecify'] ?? json['nature_others_specify'] ?? '').toString(),
      fsccrRequired: json['fsccrRequired']?.toString() ?? json['fsccr_required']?.toString(),
      fsmrRequired: json['fsmrRequired']?.toString() ?? json['fsmr_required']?.toString(),
      buildingName: (gen['buildingName'] ?? json['buildingName'] ?? json['building_name'] ?? json['business_name'] ?? '').toString(),
      address: (gen['address'] ?? json['address'] ?? '').toString(),
      businessName: (gen['businessName'] ?? json['businessName'] ?? json['business_name'] ?? '').toString(),
      natureOfBusiness: (gen['natureOfBusiness'] ?? json['natureOfBusiness'] ?? json['nature_of_business'] ?? '').toString(),
      ownerRepresentative: (gen['ownerRepresentative'] ?? json['ownerRepresentative'] ?? json['owner_name'] ?? json['owner_representative'] ?? '').toString(),
      contactNo: (gen['contactNo'] ?? json['contactNo'] ?? json['contact_no'] ?? json['contact'] ?? '').toString(),
      fsecNo: (gen['fsecNo'] ?? json['fsecNo'] ?? json['fsec_no'] ?? '').toString(),
      fsecDateIssued: (gen['fsecDateIssued'] ?? json['fsecDateIssued'] ?? json['fsec_date_issued'] ?? '').toString(),
      buildingPermitNo: (gen['buildingPermitNo'] ?? json['buildingPermitNo'] ?? json['building_permit_no'] ?? '').toString(),
      buildingPermitDateIssued: (gen['buildingPermitDateIssued'] ?? json['buildingPermitDateIssued'] ?? json['building_permit_date_issued'] ?? '').toString(),
      fsicNoLatest: (gen['fsicNoLatest'] ?? json['fsicNoLatest'] ?? json['fsic_no_latest'] ?? json['fsic_no'] ?? '').toString(),
      fsicDateIssued: (gen['fsicDateIssued'] ?? json['fsicDateIssued'] ?? json['fsic_date_issued'] ?? '').toString(),
      fireDrillCertNo: (gen['fireDrillCertNo'] ?? json['fireDrillCertNo'] ?? json['fire_drill_cert_no'] ?? '').toString(),
      fireDrillDateIssued: (gen['fireDrillDateIssued'] ?? json['fireDrillDateIssued'] ?? json['fire_drill_date_issued'] ?? '').toString(),
      businessPermitNo: (gen['businessPermitNo'] ?? json['businessPermitNo'] ?? json['business_permit_no'] ?? '').toString(),
      businessPermitDateIssued: (gen['businessPermitDateIssued'] ?? json['businessPermitDateIssued'] ?? json['business_permit_date_issued'] ?? '').toString(),
      fireInsurancePolicyNo: (gen['fireInsurancePolicyNo'] ?? json['fireInsurancePolicyNo'] ?? json['fire_insurance_policy_no'] ?? '').toString(),
      fireInsuranceDateIssued: (gen['fireInsuranceDateIssued'] ?? json['fireInsuranceDateIssued'] ?? json['fire_insurance_date_issued'] ?? '').toString(),
      constructionType: spec['constructionType']?.toString() ?? json['constructionType']?.toString() ?? json['construction_type']?.toString(),
      interiorFinishWalls: spec['interiorFinishWalls']?.toString() ?? json['interiorFinishWalls']?.toString() ?? json['interior_finish_walls']?.toString(),
      interiorFinishFloor: spec['interiorFinishFloor']?.toString() ?? json['interiorFinishFloor']?.toString() ?? json['interior_finish_floor']?.toString(),
      basementUsage: (secOcc['basement'] ?? json['basementUsage'] ?? json['basement'] ?? '').toString(),
      groundFloorUsage: (secOcc['groundFloor'] ?? json['groundFloorUsage'] ?? json['ground_floor'] ?? '').toString(),
      secondFloorUsage: (secOcc['secondFloor'] ?? json['secondFloorUsage'] ?? json['second_floor'] ?? '').toString(),
      thirdFloorUsage: (secOcc['thirdFloor'] ?? json['thirdFloorUsage'] ?? json['third_floor'] ?? '').toString(),
      fourthFloorUsage: (secOcc['fourthFloor'] ?? json['fourthFloorUsage'] ?? json['fourth_floor'] ?? '').toString(),
      nthFloorUsage: (secOcc['nthFloor'] ?? json['nthFloorUsage'] ?? json['nth_floor'] ?? '').toString(),
      occupancyClassification: spec['occupancyClassification']?.toString() ?? json['occupancyClassification']?.toString() ?? json['occupancy_type']?.toString() ?? json['occupancy']?.toString(),
      occupantLoad: (spec['occupantLoad'] ?? json['occupantLoad'] ?? json['occupant_load'] ?? '').toString(),
      numberOfStories: (spec['numberOfStories'] ?? json['numberOfStories'] ?? json['number_of_stories'] ?? json['stories'] ?? '').toString(),
      buildingHeight: (spec['buildingHeight'] ?? json['buildingHeight'] ?? json['building_height'] ?? '').toString(),
      isHighrise: spec['isHighrise']?.toString() ?? json['isHighrise']?.toString() ?? json['is_highrise']?.toString(),
      egressAccessStatus: Map<String, String>.from(json['egressAccessStatus'] ?? json['egress_access_status'] ?? {}),
      exitComponentsStatus: Map<String, String>.from(json['exitComponentsStatus'] ?? json['exit_components_status'] ?? {}),
      egressRequirementsStatus: Map<String, String>.from(json['egressRequirementsStatus'] ?? json['egress_requirements_status'] ?? {}),
      exitSignageStatus: Map<String, String>.from(json['exitSignageStatus'] ?? json['exit_signage_status'] ?? {}),
      hazardStatus: Map<String, String>.from(json['hazardStatus'] ?? json['hazard_status'] ?? {}),
      fireProtectionStatus: Map<String, String>.from(json['fireProtectionStatus'] ?? json['fire_protection_status'] ?? {}),
      itemDimensions: Map<String, String>.from(json['itemDimensions'] ?? json['item_dimensions'] ?? {}),
      defectsSummary: (json['defectsSummary'] ?? json['defects_summary'] ?? '').toString(),
      recommendationAction: json['recommendationAction']?.toString() ?? json['recommendation']?.toString() ?? json['compliance_status']?.toString(),
      inspectorName: (sig['inspectorName'] ?? json['inspectorName'] ?? json['inspector_name'] ?? '').toString(),
      teamLeaderName: (sig['teamLeaderName'] ?? json['teamLeaderName'] ?? json['team_leader_name'] ?? '').toString(),
      fireMarshalName: (sig['fireMarshalName'] ?? json['fireMarshalName'] ?? json['fire_marshal_name'] ?? '').toString(),
    );
  }
}
