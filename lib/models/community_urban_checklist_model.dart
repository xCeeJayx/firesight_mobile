class CommunityUrbanChecklistModel {
  // Header Info
  String barangay;
  String date;
  String purokSitio;

  // General Community Profile
  int? householdCount;
  int? familyCount;
  int? individualCount;
  String? landArea;

  // I. Type of Community
  String? communityType; // Metropolitan/City Center, Exclusive Village, Suburban Subdivision, Town Center, Rural Community
  String? metroSubtype; // Condominium Complexes, Urban Centers/Business District, Slums/Informal Settlements
  String? ruralSubtype; // Common Rural Community, Island Barangay, GIDA

  // II. Geography (% percentages)
  String? thickForestPct;
  String? grassyFieldsPct;
  String? mountainsHillsPct;
  String? riverFloodPlainsPct;
  String? developedLandsPct;
  String? geoOthersPct;

  // Developed Lands breakdown (%)
  String? residentialZonesPct;
  String? commercialComplexPct;
  String? educationalCompoundsPct;
  String? industrialParkPct;
  String? parksOpenSpacesPct;
  String? devOthersPct;

  // III. Vulnerability Parameters (YES/NO/NA values: "YES", "NO", "N/A")
  Map<String, String> sec1Params; // 1a to 1h
  Map<String, String> sec2Params; // 2a to 2i
  Map<String, String> sec3Params; // 3a to 3f
  Map<String, String> sec4Params; // 4a to 4e
  Map<String, String> sec5Params; // 5a to 5f

  // Specific Sub-fields in Section 1
  String? buildingClusteredDistance; // '9 meters +', '4-8 meters', '0-3 meters'
  String? primaryRouteName;
  String? primaryRouteDist;
  String? primaryRouteEstTime;
  String? primaryRouteActualTime;
  String? secondaryRouteName;
  String? secondaryRouteDist;
  String? secondaryRouteEstTime;
  String? secondaryRouteActualTime;
  String? entryRespondingTrucks;
  String? entryRefillingTrucks;
  String? roadWidth;
  String? roadPavement;
  String? narrowAlleysWidth;
  String? narrowAlleysPavement;
  String? accessPassableFor;
  String? additionalEntryAlleys;
  String? hosesNeeded;
  String? waterSourceLocation;
  String? waterSourceDistance;
  String? rateOfDischarge;
  String? waterSourceStatus;

  // Prepared By / Signatures
  String? designatedBumbero;
  String? workshopTeamLeader;
  String? barangayCaptain;
  String? fireMarshal;

  CommunityUrbanChecklistModel({
    this.barangay = '',
    this.date = '',
    this.purokSitio = '',
    this.householdCount,
    this.familyCount,
    this.individualCount,
    this.landArea,
    this.communityType,
    this.metroSubtype,
    this.ruralSubtype,
    this.thickForestPct,
    this.grassyFieldsPct,
    this.mountainsHillsPct,
    this.riverFloodPlainsPct,
    this.developedLandsPct,
    this.geoOthersPct,
    this.residentialZonesPct,
    this.commercialComplexPct,
    this.educationalCompoundsPct,
    this.industrialParkPct,
    this.parksOpenSpacesPct,
    this.devOthersPct,
    Map<String, String>? sec1Params,
    Map<String, String>? sec2Params,
    Map<String, String>? sec3Params,
    Map<String, String>? sec4Params,
    Map<String, String>? sec5Params,
    this.buildingClusteredDistance,
    this.primaryRouteName,
    this.primaryRouteDist,
    this.primaryRouteEstTime,
    this.primaryRouteActualTime,
    this.secondaryRouteName,
    this.secondaryRouteDist,
    this.secondaryRouteEstTime,
    this.secondaryRouteActualTime,
    this.entryRespondingTrucks,
    this.entryRefillingTrucks,
    this.roadWidth,
    this.roadPavement,
    this.narrowAlleysWidth,
    this.narrowAlleysPavement,
    this.accessPassableFor,
    this.additionalEntryAlleys,
    this.hosesNeeded,
    this.waterSourceLocation,
    this.waterSourceDistance,
    this.rateOfDischarge,
    this.waterSourceStatus,
    this.designatedBumbero,
    this.workshopTeamLeader,
    this.barangayCaptain,
    this.fireMarshal,
  })  : sec1Params = sec1Params ?? {},
        sec2Params = sec2Params ?? {},
        sec3Params = sec3Params ?? {},
        sec4Params = sec4Params ?? {},
        sec5Params = sec5Params ?? {};

  // Scoring Logic
  int get calculateTotalScore {
    int score = 0;
    // Section 1: Each YES = 3 points
    for (final v in sec1Params.values) {
      if (v == 'YES') score += 3;
    }
    // Section 2: Each YES = 2 points
    for (final v in sec2Params.values) {
      if (v == 'YES') score += 2;
    }
    // Section 3: Each YES = 2 points
    for (final v in sec3Params.values) {
      if (v == 'YES') score += 2;
    }
    // Section 4: Each YES = 2 points
    for (final v in sec4Params.values) {
      if (v == 'YES') score += 2;
    }
    // Section 5: Each YES = 1 point
    for (final v in sec5Params.values) {
      if (v == 'YES') score += 1;
    }
    return score;
  }

  int get totalYesCount {
    int count = 0;
    count += sec1Params.values.where((v) => v == 'YES').length;
    count += sec2Params.values.where((v) => v == 'YES').length;
    count += sec3Params.values.where((v) => v == 'YES').length;
    count += sec4Params.values.where((v) => v == 'YES').length;
    count += sec5Params.values.where((v) => v == 'YES').length;
    return count;
  }

  int get vulnerabilityRating {
    final yesCount = totalYesCount;
    if (yesCount >= 40) {
      return 5;
    } else if (yesCount >= 20) {
      return 4;
    } else {
      return 3;
    }
  }

  String get vulnerabilityLabel {
    final rating = vulnerabilityRating;
    if (rating == 5) {
      return 'Rating 5: Highly Vulnerable';
    } else if (rating == 4) {
      return 'Rating 4: Moderately Vulnerable';
    } else {
      return 'Rating 3: Mildly Vulnerable';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'barangay': barangay,
      'date': date,
      'purokSitio': purokSitio,
      'householdCount': householdCount,
      'familyCount': familyCount,
      'individualCount': individualCount,
      'landArea': landArea,
      'communityType': communityType,
      'metroSubtype': metroSubtype,
      'ruralSubtype': ruralSubtype,
      'geography': {
        'thickForestPct': thickForestPct,
        'grassyFieldsPct': grassyFieldsPct,
        'mountainsHillsPct': mountainsHillsPct,
        'riverFloodPlainsPct': riverFloodPlainsPct,
        'developedLandsPct': developedLandsPct,
        'geoOthersPct': geoOthersPct,
        'residentialZonesPct': residentialZonesPct,
        'commercialComplexPct': commercialComplexPct,
        'educationalCompoundsPct': educationalCompoundsPct,
        'industrialParkPct': industrialParkPct,
        'parksOpenSpacesPct': parksOpenSpacesPct,
        'devOthersPct': devOthersPct,
      },
      'sec1Params': sec1Params,
      'sec2Params': sec2Params,
      'sec3Params': sec3Params,
      'sec4Params': sec4Params,
      'sec5Params': sec5Params,
      'subFields': {
        'buildingClusteredDistance': buildingClusteredDistance,
        'primaryRouteName': primaryRouteName,
        'primaryRouteDist': primaryRouteDist,
        'primaryRouteEstTime': primaryRouteEstTime,
        'primaryRouteActualTime': primaryRouteActualTime,
        'secondaryRouteName': secondaryRouteName,
        'secondaryRouteDist': secondaryRouteDist,
        'secondaryRouteEstTime': secondaryRouteEstTime,
        'secondaryRouteActualTime': secondaryRouteActualTime,
        'entryRespondingTrucks': entryRespondingTrucks,
        'entryRefillingTrucks': entryRefillingTrucks,
        'roadWidth': roadWidth,
        'roadPavement': roadPavement,
        'narrowAlleysWidth': narrowAlleysWidth,
        'narrowAlleysPavement': narrowAlleysPavement,
        'accessPassableFor': accessPassableFor,
        'additionalEntryAlleys': additionalEntryAlleys,
        'hosesNeeded': hosesNeeded,
        'waterSourceLocation': waterSourceLocation,
        'waterSourceDistance': waterSourceDistance,
        'rateOfDischarge': rateOfDischarge,
        'waterSourceStatus': waterSourceStatus,
      },
      'totalScore': calculateTotalScore,
      'totalYesCount': totalYesCount,
      'vulnerabilityRating': vulnerabilityRating,
      'vulnerabilityLabel': vulnerabilityLabel,
      'signatories': {
        'designatedBumbero': designatedBumbero,
        'workshopTeamLeader': workshopTeamLeader,
        'barangayCaptain': barangayCaptain,
        'fireMarshal': fireMarshal,
      },
    };
  }

  factory CommunityUrbanChecklistModel.fromJson(Map<String, dynamic> json) {
    final geo = json['geography'] as Map<String, dynamic>? ?? {};
    final sub = json['subFields'] as Map<String, dynamic>? ?? {};
    final sig = json['signatories'] as Map<String, dynamic>? ?? {};

    return CommunityUrbanChecklistModel(
      barangay: json['barangay'] ?? '',
      date: json['date'] ?? '',
      purokSitio: json['purokSitio'] ?? '',
      householdCount: json['householdCount'],
      familyCount: json['familyCount'],
      individualCount: json['individualCount'],
      landArea: json['landArea'],
      communityType: json['communityType'],
      metroSubtype: json['metroSubtype'],
      ruralSubtype: json['ruralSubtype'],
      thickForestPct: geo['thickForestPct'],
      grassyFieldsPct: geo['grassyFieldsPct'],
      mountainsHillsPct: geo['mountainsHillsPct'],
      riverFloodPlainsPct: geo['riverFloodPlainsPct'],
      developedLandsPct: geo['developedLandsPct'],
      geoOthersPct: geo['geoOthersPct'],
      residentialZonesPct: geo['residentialZonesPct'],
      commercialComplexPct: geo['commercialComplexPct'],
      educationalCompoundsPct: geo['educationalCompoundsPct'],
      industrialParkPct: geo['industrialParkPct'],
      parksOpenSpacesPct: geo['parksOpenSpacesPct'],
      devOthersPct: geo['devOthersPct'],
      sec1Params: Map<String, String>.from(json['sec1Params'] ?? {}),
      sec2Params: Map<String, String>.from(json['sec2Params'] ?? {}),
      sec3Params: Map<String, String>.from(json['sec3Params'] ?? {}),
      sec4Params: Map<String, String>.from(json['sec4Params'] ?? {}),
      sec5Params: Map<String, String>.from(json['sec5Params'] ?? {}),
      buildingClusteredDistance: sub['buildingClusteredDistance'],
      primaryRouteName: sub['primaryRouteName'],
      primaryRouteDist: sub['primaryRouteDist'],
      primaryRouteEstTime: sub['primaryRouteEstTime'],
      primaryRouteActualTime: sub['primaryRouteActualTime'],
      secondaryRouteName: sub['secondaryRouteName'],
      secondaryRouteDist: sub['secondaryRouteDist'],
      secondaryRouteEstTime: sub['secondaryRouteEstTime'],
      secondaryRouteActualTime: sub['secondaryRouteActualTime'],
      entryRespondingTrucks: sub['entryRespondingTrucks'],
      entryRefillingTrucks: sub['entryRefillingTrucks'],
      roadWidth: sub['roadWidth'],
      roadPavement: sub['roadPavement'],
      narrowAlleysWidth: sub['narrowAlleysWidth'],
      narrowAlleysPavement: sub['narrowAlleysPavement'],
      accessPassableFor: sub['accessPassableFor'],
      additionalEntryAlleys: sub['additionalEntryAlleys'],
      hosesNeeded: sub['hosesNeeded'],
      waterSourceLocation: sub['waterSourceLocation'],
      waterSourceDistance: sub['waterSourceDistance'],
      rateOfDischarge: sub['rateOfDischarge'],
      waterSourceStatus: sub['waterSourceStatus'],
      designatedBumbero: sig['designatedBumbero'],
      workshopTeamLeader: sig['workshopTeamLeader'],
      barangayCaptain: sig['barangayCaptain'],
      fireMarshal: sig['fireMarshal'],
    );
  }
}
