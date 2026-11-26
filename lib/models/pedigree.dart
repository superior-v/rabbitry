class PedigreeRabbit {
  final String id;
  final String name;
  final String? breederPrefix;
  final String? breed;
  final String? color;
  final String? weight;
  final String? registrationNumber;
  final String? grandChampionNumber;
  final String? earNumber;
  final int? legs;
  final String? winnings;
  final DateTime? dateOfBirth;
  final String? sex;
  String? profileImage;
  PedigreeRabbit? sire;
  PedigreeRabbit? dam;
  final int generation;
  final bool isExternal;

  PedigreeRabbit({
    required this.id,
    required this.name,
    this.breederPrefix,
    this.breed,
    this.color,
    this.weight,
    this.registrationNumber,
    this.grandChampionNumber,
    this.earNumber,
    this.legs,
    this.winnings,
    this.dateOfBirth,
    this.sex,
    this.profileImage,
    this.sire,
    this.dam,
    this.generation = 0,
    this.isExternal = false,
  });

  /// Prefix (possessive) + name, e.g. "ABC's Bella".
  String get displayName {
    final p = possessivePrefix(breederPrefix);
    return p.isEmpty ? name : '$p $name';
  }

  void updateProfileImage(String? imagePath) {
    profileImage = imagePath;
  }

  PedigreeRabbit copyWith({
    String? id,
    String? name,
    String? breederPrefix,
    String? breed,
    String? color,
    String? weight,
    String? registrationNumber,
    String? grandChampionNumber,
    String? earNumber,
    int? legs,
    String? winnings,
    DateTime? dateOfBirth,
    String? sex,
    String? profileImage,
    PedigreeRabbit? sire,
    PedigreeRabbit? dam,
    int? generation,
    bool? isExternal,
  }) {
    return PedigreeRabbit(
      id: id ?? this.id,
      name: name ?? this.name,
      breederPrefix: breederPrefix ?? this.breederPrefix,
      breed: breed ?? this.breed,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      grandChampionNumber: grandChampionNumber ?? this.grandChampionNumber,
      earNumber: earNumber ?? this.earNumber,
      legs: legs ?? this.legs,
      winnings: winnings ?? this.winnings,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      sex: sex ?? this.sex,
      profileImage: profileImage ?? this.profileImage,
      sire: sire ?? this.sire,
      dam: dam ?? this.dam,
      generation: generation ?? this.generation,
      isExternal: isExternal ?? this.isExternal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'breederPrefix': breederPrefix,
      'breed': breed,
      'color': color,
      'weight': weight,
      'registrationNumber': registrationNumber,
      'grandChampionNumber': grandChampionNumber,
      'earNumber': earNumber,
      'legs': legs,
      'winnings': winnings,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'sex': sex,
      'profileImage': profileImage,
      'sire': sire?.toJson(),
      'dam': dam?.toJson(),
      'generation': generation,
      'isExternal': isExternal,
    };
  }

  factory PedigreeRabbit.fromJson(Map<String, dynamic> json) {
    return PedigreeRabbit(
      id: json['id'],
      name: json['name'],
      breederPrefix: json['breederPrefix'],
      breed: json['breed'],
      color: json['color'],
      weight: json['weight'],
      registrationNumber: json['registrationNumber'],
      grandChampionNumber: json['grandChampionNumber'],
      earNumber: json['earNumber'],
      legs: json['legs'] is int ? json['legs'] : int.tryParse(json['legs']?.toString() ?? ''),
      winnings: json['winnings'],
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.tryParse(json['dateOfBirth']) : null,
      sex: json['sex'],
      profileImage: json['profileImage'],
      sire: json['sire'] != null ? PedigreeRabbit.fromJson(json['sire']) : null,
      dam: json['dam'] != null ? PedigreeRabbit.fromJson(json['dam']) : null,
      generation: json['generation'] ?? 0,
      isExternal: json['isExternal'] ?? false,
    );
  }
}

/// "SBS" -> "SBS's" (left as-is when it already ends in 's).
String possessivePrefix(String? prefix) {
  final p = (prefix ?? '').trim();
  if (p.isEmpty) return '';
  final l = p.toLowerCase();
  if (l.endsWith("'s") || l.endsWith('’s')) return p;
  return "$p's";
}
