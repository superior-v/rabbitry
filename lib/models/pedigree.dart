class PedigreeRabbit {
  final String id;
  final String name;
  final String? breed;
  final String? color;
  final String? weight;
  final String? registrationNumber;
  final String? earNumber;
  final int? legs;
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
    this.breed,
    this.color,
    this.weight,
    this.registrationNumber,
    this.earNumber,
    this.legs,
    this.dateOfBirth,
    this.sex,
    this.profileImage,
    this.sire,
    this.dam,
    this.generation = 0,
    this.isExternal = false,
  });

  void updateProfileImage(String? imagePath) {
    profileImage = imagePath;
  }

  PedigreeRabbit copyWith({
    String? id,
    String? name,
    String? breed,
    String? color,
    String? weight,
    String? registrationNumber,
    String? earNumber,
    int? legs,
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
      breed: breed ?? this.breed,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      earNumber: earNumber ?? this.earNumber,
      legs: legs ?? this.legs,
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
      'breed': breed,
      'color': color,
      'weight': weight,
      'registrationNumber': registrationNumber,
      'earNumber': earNumber,
      'legs': legs,
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
      breed: json['breed'],
      color: json['color'],
      weight: json['weight'],
      registrationNumber: json['registrationNumber'],
      earNumber: json['earNumber'],
      legs: json['legs'] is int ? json['legs'] : int.tryParse(json['legs']?.toString() ?? ''),
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