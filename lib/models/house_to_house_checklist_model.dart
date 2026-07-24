class HouseToHouseChecklistModel {
  String occupantName;
  String address;

  // 35 items keyed by item number (1 to 35) -> 'YES', 'NO', 'N/A'
  Map<int, String> itemStatuses;

  // Building Materials Matrix: element (e.g. 'Roof') -> material (e.g. 'Wood', 'Cement', 'Metal', 'Others')
  Map<String, String> buildingMaterials;

  String suggestions;
  String acknowledgedBy;

  HouseToHouseChecklistModel({
    this.occupantName = '',
    this.address = '',
    Map<int, String>? itemStatuses,
    Map<String, String>? buildingMaterials,
    this.suggestions = '',
    this.acknowledgedBy = '',
  })  : itemStatuses = itemStatuses ?? {},
        buildingMaterials = buildingMaterials ?? {};

  // Calculate Total YES Points
  int get totalYesPoints {
    return itemStatuses.values.where((status) => status == 'YES').length;
  }

  // Safety Interpretation based on total YES points
  String get interpretation {
    final points = totalYesPoints;
    if (points >= 24) {
      return 'Ligtas (Safe)';
    } else if (points >= 12) {
      return 'Maydapat ipangamba (Caution)';
    } else {
      return 'Labis na mapanganib (High Hazard)';
    }
  }

  // Alias for backwards compatibility
  String get safetyInterpretation => interpretation;

  // Hex color code matching risk interpretation
  String get riskColorCode {
    final points = totalYesPoints;
    if (points >= 24) {
      return '#2ECC71';
    } else if (points >= 12) {
      return '#F1C40F';
    } else {
      return '#E74C3C';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'occupantName': occupantName,
      'address': address,
      'itemStatuses': itemStatuses.map((k, v) => MapEntry(k.toString(), v)),
      'totalYesPoints': totalYesPoints,
      'interpretation': interpretation,
      'safetyInterpretation': safetyInterpretation,
      'riskColorCode': riskColorCode,
      'buildingMaterials': buildingMaterials,
      'suggestions': suggestions,
      'acknowledgedBy': acknowledgedBy,
    };
  }

  factory HouseToHouseChecklistModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['itemStatuses'] as Map<String, dynamic>? ?? {};
    final parsedItems = <int, String>{};
    rawItems.forEach((key, value) {
      final parsedKey = int.tryParse(key);
      if (parsedKey != null && value is String) {
        parsedItems[parsedKey] = value;
      }
    });

    return HouseToHouseChecklistModel(
      occupantName: json['occupantName'] ?? '',
      address: json['address'] ?? '',
      itemStatuses: parsedItems,
      buildingMaterials: Map<String, String>.from(json['buildingMaterials'] ?? {}),
      suggestions: json['suggestions'] ?? '',
      acknowledgedBy: json['acknowledgedBy'] ?? '',
    );
  }

  // Static list of items for UI rendering
  static const Map<int, String> checklistItems = {
    // A. KAAYUSAN SA BAHAY
    1: 'Maayos at Malinis',
    2: 'Nakatago ang mga flammable na bagay',
    3: 'Walang kalat malapit sa saksakan',
    4: 'Nasa tamang ayos ang bahay',
    5: 'Tamang pag-tapon ng basura',
    6: 'Nakaligpit ang mga gamit ng maayos',
    7: 'Alam ang [Stop, Drop, and Roll]',
    8: 'Mayroong Evacuation Plan [Exit Drill in the Home]',
    9: 'May naninigarilyo',

    // B. KAAYUSAN NG ELECTRICAL
    10: 'May Circuit Breaker',
    11: 'Natakip ang lahat electrical panels, junction boxes, outlet at switches ng maayos',
    12: 'May extension cords',
    13: 'Maayos ang extension cords',
    14: 'Maayos na pag gamit ng outlet',
    15: 'Walang nakausling electrical cords',
    16: 'Maayos ang mga saksakan at switch ng ilaw',
    17: 'Direktang nakasaksak sa outlet ang mga appliances',
    18: 'Ang mga kable na gamit ay maayos sa tamang sukat',
    19: 'Nasa tamang sukat ang mga kable',
    20: 'Pag tanggal ng mga nakasaksak kapag hindi ginagamit',
    21: 'May electrical safety switch',

    // C. KAAYUSAN SA KUSINA
    22: 'Binabantayan ang lutuin sa kusina',
    23: 'Nasa tamang lalagyan ang LPG',
    24: 'Laging nakapatay ang LPG matapos gamitin',
    25: 'Walang tumatagas na tubig sa kusina',
    26: 'Walang anumang bagay sa kusina na pwedeng masunog',
    27: 'Pag-inspeksyon ng mga kagamitan sa kusina',
    28: 'May sapat na singawan ng usok sa kusina',
    29: 'Nasa tamang lalagyan ang mga kandila at lighter',

    // D. DAANAN O LABASAN SA BAHAY
    30: 'Walang anumang kalat sa pintuan at kusina',
    31: 'Malinis ang paligid ng bahay',
    32: 'Nakakalabas ng bahay kapag may sunog',
    33: 'Malapit sa kalsada',
    34: 'Maluwag sa loob ng bahay',
    35: 'Madaliwalas sa loob ng tahanan',
  };

  static const List<String> buildingElements = [
    'Roof',
    'Ceiling',
    'Room Partitions',
    'Trusses',
    'Windows',
    'Corridor Walls',
    'Columns',
    'Main Door',
  ];

  static const List<String> materialOptions = [
    'Wood',
    'Cement',
    'Metal',
    'Others',
  ];
}
