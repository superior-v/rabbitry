class PedigreeRabbit {
  final String id;
  final String name;
  final String? breed;
  final String? color;
  final String? weight;
  final String? registrationNumber;
  final String? sex;
  String? profileImage; // Remove 'final' to make it mutable
  PedigreeRabbit? sire;
  PedigreeRabbit? dam;
  final int generation;

  PedigreeRabbit({
    required this.id,
    required this.name,
    this.breed,
    this.color,
    this.weight,
    this.registrationNumber,
    this.sex,
    this.profileImage,
    this.sire,
    this.dam,
    this.generation = 0,
  });

  // Add method to update profile image
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
    String? sex,
    String? profileImage,
    PedigreeRabbit? sire,
    PedigreeRabbit? dam,
    int? generation,
  }) {
    return PedigreeRabbit(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      sex: sex ?? this.sex,
      profileImage: profileImage ?? this.profileImage,
      sire: sire ?? this.sire,
      dam: dam ?? this.dam,
      generation: generation ?? this.generation,
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
      'sex': sex,
      'profileImage': profileImage,
      'sire': sire?.toJson(),
      'dam': dam?.toJson(),
      'generation': generation,
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
      sex: json['sex'],
      profileImage: json['profileImage'],
      sire: json['sire'] != null ? PedigreeRabbit.fromJson(json['sire']) : null,
      dam: json['dam'] != null ? PedigreeRabbit.fromJson(json['dam']) : null,
      generation: json['generation'] ?? 0,
    );
  }
}