import 'dart:convert';

class Kit {
  final String id;
  final String sex;
  final String color;
  final double weight;
  String status; // Keep as mutable for direct updates
  final String? details;
  final double? price;

  Kit({
    required this.id,
    required this.sex,
    required this.color,
    required this.weight,
    required this.status,
    this.details,
    this.price,
  });

  bool get isArchived => [
        'Sold',
        'Butchered',
        'Dead',
        'Cull',
      ].contains(status);

  Kit copyWith({
    String? id,
    String? sex,
    String? color,
    double? weight,
    String? status,
    String? details,
    double? price,
  }) {
    return Kit(
      id: id ?? this.id,
      sex: sex ?? this.sex,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      status: status ?? this.status,
      details: details ?? this.details,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sex': sex,
      'color': color,
      'weight': weight,
      'status': status,
      'details': details,
      'price': price,
    };
  }

  factory Kit.fromMap(Map<String, dynamic> map) {
    return Kit(
      id: map['id'] as String? ?? '0', // ✅ Handle null
      sex: map['sex'] as String? ?? 'U', // ✅ Handle null
      color: map['color'] as String? ?? 'Unknown', // ✅ Handle null
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0, // ✅ Handle null
      status: map['status'] as String? ?? 'Nursing', // ✅ Handle null
      details: map['details'] as String?,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
    );
  }
  String toJson() => json.encode(toMap());

  factory Kit.fromJson(String source) => Kit.fromMap(json.decode(source));
}

class Litter {
  final String id;
  final String doeId;
  final String doeName;
  final String buckId;
  final String buckName;
  final DateTime breedDate;
  final DateTime? dueDate;
  final DateTime? kindleDate;
  final int? totalKits;
  final int? aliveKits;
  final int? deadKits;
  final DateTime? weanDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime dob;
  String location; // Keep as mutable
  String cage; // Keep as mutable
  final String breed;
  final String status;
  final List<Kit> kits;
  final String sire;
  final String dam;

  Litter({
    required this.id,
    required this.doeId,
    required this.doeName,
    required this.buckId,
    required this.buckName,
    required this.breedDate,
    this.dueDate,
    this.kindleDate,
    this.totalKits,
    this.aliveKits,
    this.deadKits,
    this.weanDate,
    this.notes,
    DateTime? createdAt,
    required this.dob,
    required this.location,
    required this.cage,
    required this.breed,
    required this.status,
    this.kits = const [],
    required this.sire,
    required this.dam,
  }) : createdAt = createdAt ?? DateTime.now();

  // Computed properties
  int get ageDays => DateTime.now().difference(dob).inDays;

  String get ageDisplay {
    if (ageDays < 7) return '${ageDays}d';
    if (ageDays < 28) return '${(ageDays / 7).floor()}w';
    if (ageDays < 365) return '${(ageDays / 30).floor()}mo';
    return '${(ageDays / 365).floor()}yr';
  }

  double get totalWeight => kits.fold(0.0, (sum, kit) => sum + kit.weight);

  int get maleCount => kits.where((k) => k.sex == 'M' && !k.isArchived).length;

  int get femaleCount => kits.where((k) => k.sex == 'F' && !k.isArchived).length;

  int get totalKitsCount => kits.where((k) => !k.isArchived).length;

  List<String> get distinctStatuses {
    return kits.map((k) => k.status).toSet().toList();
  }

  // CopyWith method for immutable updates
  Litter copyWith({
    String? id,
    String? doeId,
    String? doeName,
    String? buckId,
    String? buckName,
    DateTime? breedDate,
    DateTime? dueDate,
    DateTime? kindleDate,
    int? totalKits,
    int? aliveKits,
    int? deadKits,
    DateTime? weanDate,
    String? notes,
    DateTime? createdAt,
    DateTime? dob,
    String? location,
    String? cage,
    String? breed,
    String? status,
    List<Kit>? kits,
    String? sire,
    String? dam,
  }) {
    return Litter(
      id: id ?? this.id,
      doeId: doeId ?? this.doeId,
      doeName: doeName ?? this.doeName,
      buckId: buckId ?? this.buckId,
      buckName: buckName ?? this.buckName,
      breedDate: breedDate ?? this.breedDate,
      dueDate: dueDate ?? this.dueDate,
      kindleDate: kindleDate ?? this.kindleDate,
      totalKits: totalKits ?? this.totalKits,
      aliveKits: aliveKits ?? this.aliveKits,
      deadKits: deadKits ?? this.deadKits,
      weanDate: weanDate ?? this.weanDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      dob: dob ?? this.dob,
      location: location ?? this.location,
      cage: cage ?? this.cage,
      breed: breed ?? this.breed,
      status: status ?? this.status,
      kits: kits ?? this.kits,
      sire: sire ?? this.sire,
      dam: dam ?? this.dam,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doeId': doeId,
      'doeName': doeName,
      'buckId': buckId,
      'buckName': buckName,
      'breedDate': breedDate.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'kindleDate': kindleDate?.toIso8601String(),
      'totalBorn': totalKits ?? 0,
      'aliveBorn': aliveKits ?? 0,
      'deadBorn': deadKits ?? 0,
      'currentAlive': aliveKits ?? 0,
      'weanDate': weanDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      // ✅ ENSURE THESE ARE INCLUDED
      'dob': dob.toIso8601String(),
      'location': location,
      'cage': cage,
      'breed': breed,
      'status': status,
      'sire': sire,
      'dam': dam,
      'kits': jsonEncode(kits.map((k) => k.toMap()).toList()),
    };
  }

  factory Litter.fromMap(Map<String, dynamic> map) {
    List<Kit> kitsList = [];
    if (map['kits'] != null) {
      try {
        if (map['kits'] is String && (map['kits'] as String).isNotEmpty) {
          // Handle JSON string from database
          final kitsJson = jsonDecode(map['kits']) as List;
          kitsList = kitsJson.map((k) => Kit.fromMap(k as Map<String, dynamic>)).toList();
        } else if (map['kits'] is List) {
          // Handle List directly (for in-memory objects)
          kitsList = (map['kits'] as List).map((k) => Kit.fromMap(k as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        print('❌ Error parsing kits JSON: $e');
      }
    }

    // ✅ Parse dob with fallback to kindleDate or breedDate
    DateTime parsedDob;
    try {
      if (map['dob'] != null && map['dob'] != '') {
        parsedDob = DateTime.parse(map['dob'] as String);
      } else if (map['kindleDate'] != null && map['kindleDate'] != '') {
        parsedDob = DateTime.parse(map['kindleDate'] as String);
      } else {
        parsedDob = DateTime.parse(map['breedDate'] as String);
      }
    } catch (e) {
      print('❌ Error parsing dates for litter ${map['id']}, using current date');
      parsedDob = DateTime.now();
    }

    return Litter(
      id: map['id'] as String,
      doeId: map['doeId'] as String? ?? '',
      doeName: map['doeName'] as String? ?? 'Unknown',
      buckId: map['buckId'] as String? ?? '',
      buckName: map['buckName'] as String? ?? 'Unknown',
      breedDate: DateTime.parse(map['breedDate'] as String),
      dueDate: map['dueDate'] != null && map['dueDate'] != '' ? DateTime.parse(map['dueDate'] as String) : null,
      kindleDate: map['kindleDate'] != null && map['kindleDate'] != '' ? DateTime.parse(map['kindleDate'] as String) : null,
      totalKits: (map['totalBorn'] ?? map['totalKits'] ?? 0) as int,
      aliveKits: (map['currentAlive'] ?? map['aliveKits'] ?? 0) as int,
      deadKits: (map['deadBorn'] ?? map['deadKits'] ?? 0) as int,
      weanDate: map['weanDate'] != null && map['weanDate'] != '' ? DateTime.parse(map['weanDate'] as String) : null,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null && map['createdAt'] != '' ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      dob: parsedDob, // ✅ Use the parsed/fallback dob
      location: map['location'] as String? ?? 'Unknown', // ✅ Handle null
      cage: map['cage'] as String? ?? 'N/A', // ✅ Handle null
      breed: map['breed'] as String? ?? 'Unknown', // ✅ Handle null
      status: map['status'] as String? ?? 'nursing', // ✅ Handle null
      sire: map['sire'] as String? ?? (map['buckName'] as String? ?? 'Unknown'), // ✅ Fallback to buckName
      dam: map['dam'] as String? ?? (map['doeName'] as String? ?? 'Unknown'), // ✅ Fallback to doeName
      kits: kitsList,
    );
  }

  String toJson() => json.encode(toMap());

  factory Litter.fromJson(String source) => Litter.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Litter(id: $id, doeName: $doeName, buckName: $buckName, status: $status, kits: ${kits.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Litter && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
