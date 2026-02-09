import 'package:flutter/material.dart';

enum RabbitType {
  doe,
  buck,
  kit,
  archive,
}

enum RabbitStatus {
  open, // Available for breeding
  palpateDue, // Needs palpation check (Day 14 check)
  pregnant, // Confirmed pregnant
  nursing, // Has active litter
  resting, // Post-weaning rest period
  active,
  inactive,
  growout, // Young rabbit growing to maturity
  quarantine, // In quarantine
  archived, // Sold/Dead/Culled/Butchered
}

enum ArchiveReason {
  sold,
  butchered,
  dead,
  cull,
}

extension ArchiveReasonExtension on ArchiveReason {
  String get label {
    switch (this) {
      case ArchiveReason.sold:
        return 'SOLD';
      case ArchiveReason.butchered:
        return 'BUTCHERED';
      case ArchiveReason.dead:
        return 'DEAD';
      case ArchiveReason.cull:
        return 'CULL';
    }
  }

  Color get color {
    switch (this) {
      case ArchiveReason.sold:
        return const Color(0xFF0F7B6C); // Green
      case ArchiveReason.butchered:
        return const Color(0xFF6B6B6B); // Gray
      case ArchiveReason.dead:
        return const Color(0xFF2C2C2C); // Black
      case ArchiveReason.cull:
        return const Color(0xFFE63946); // Red
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ArchiveReason.sold:
        return const Color(0xFFE8F5F3);
      case ArchiveReason.butchered:
        return const Color(0xFFF5F5F5);
      case ArchiveReason.dead:
        return const Color(0xFFE8E8E8);
      case ArchiveReason.cull:
        return const Color(0xFFFFEBEC);
    }
  }
}

class Rabbit {
  final String id;
  String name;
  final RabbitType type;
  RabbitStatus status;
  String breed;
  String? location;
  String? cage;
  final String? details;
  DateTime? dateOfBirth;
  String? color;
  double? weight;
  String? registrationNumber;
  String? sireId;
  String? damId;
  String? genetics;
  String? origin;
  List<String>? photos;
  String? notes;
  final DateTime createdAt;
  DateTime updatedAt;

  // Breeding related fields
  DateTime? lastBreedDate;
  String? lastBreedBuckId;
  DateTime? palpationDate;
  bool? palpationResult;
  DateTime? dueDate;
  DateTime? kindleDate;
  int? currentLitterSize;
  DateTime? weanDate;

  // Growout fields
  DateTime? maturityDate;

  // Quarantine fields
  DateTime? quarantineStartDate;
  DateTime? quarantineEndDate;
  String? quarantineReason;

  // Archive fields
  final ArchiveReason? archiveReason;
  final DateTime? archiveDate;
  final String? archiveNotes;

  // For SOLD status
  final double? salePrice;
  final String? buyerInfo;

  // For BUTCHERED status
  final double? butcherYield; // in lbs
  final double? butcherCost;

  // For DEAD status
  final String? deathCause;

  // For CULL status
  final String? cullReason;

  Rabbit({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.breed,
    this.location,
    this.cage,
    this.details,
    this.dateOfBirth,
    this.color,
    this.weight,
    this.registrationNumber,
    this.sireId,
    this.damId,
    this.genetics,
    this.origin,
    this.photos,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastBreedDate,
    this.lastBreedBuckId,
    this.palpationDate,
    this.palpationResult,
    this.dueDate,
    this.kindleDate,
    this.currentLitterSize,
    this.weanDate,
    this.maturityDate,
    this.quarantineStartDate,
    this.quarantineEndDate,
    this.quarantineReason,
    this.archiveReason,
    this.archiveDate,
    this.archiveNotes,
    this.salePrice,
    this.buyerInfo,
    this.butcherYield,
    this.butcherCost,
    this.deathCause,
    this.cullReason,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate days until maturity (for growout)
  int? get daysUntilMature {
    if (maturityDate == null) return null;
    final days = maturityDate!.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }

  // Calculate days until due (for pregnant)
  int? get daysUntilDue {
    if (dueDate == null) return null;
    final days = dueDate!.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }

  // Calculate days in quarantine remaining
  int? get daysInQuarantineRemaining {
    if (quarantineEndDate == null) return null;
    final days = quarantineEndDate!.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }

  // Calculate age string
  String get age {
    if (dateOfBirth == null) return 'Unknown';
    final now = DateTime.now();
    final difference = now.difference(dateOfBirth!);
    final years = (difference.inDays / 365).floor();
    final months = ((difference.inDays % 365) / 30).floor();
    final weeks = ((difference.inDays % 30) / 7).floor();

    if (years > 0) {
      return '${years}y ${months}m';
    } else if (months > 0) {
      return '${months}m ${weeks}w';
    } else if (weeks > 0) {
      return '${weeks}w';
    } else {
      return '${difference.inDays}d';
    }
  }

  // Get status display text
  String get statusText {
    switch (status) {
      case RabbitStatus.open:
        return 'Open';
      case RabbitStatus.palpateDue:
        return 'Palpate Due';
      case RabbitStatus.pregnant:
        return 'Pregnant';
      case RabbitStatus.nursing:
        return 'Nursing';
      case RabbitStatus.resting:
        return 'Resting';
      case RabbitStatus.active:
        return 'Active';
      case RabbitStatus.inactive:
        return 'Inactive';
      case RabbitStatus.growout:
        return 'Grow Out';
      case RabbitStatus.quarantine:
        return 'Quarantine';
      case RabbitStatus.archived:
        return 'Archived';
    }
  }

  String? get statusDetails {
    switch (status) {
      case RabbitStatus.palpateDue:
        return 'Day 14 Check';

      case RabbitStatus.pregnant:
        if (daysUntilDue != null && dueDate != null) {
          return 'Due: ${dueDate!.day}/${dueDate!.month} • $daysUntilDue days left';
        }
        return null;

      case RabbitStatus.nursing:
        if (currentLitterSize != null && weanDate != null) {
          final weeksOld = DateTime.now().difference(kindleDate ?? DateTime.now()).inDays ~/ 7;
          return '$currentLitterSize Kits • $weeksOld weeks old';
        }
        return null;

      case RabbitStatus.resting:
        return 'Post-weaning rest period';

      case RabbitStatus.growout:
        if (daysUntilMature != null && daysUntilMature! > 0) {
          return '$daysUntilMature days to mature';
        }
        return 'Growing to maturity';

      case RabbitStatus.quarantine:
        if (daysInQuarantineRemaining != null && daysInQuarantineRemaining! > 0) {
          return '$daysInQuarantineRemaining days remaining';
        }
        if (quarantineReason != null) {
          return quarantineReason;
        }
        return 'In quarantine';

      default:
        return null;
    }
  }

  // Get status color
  int get statusColor {
    switch (status) {
      case RabbitStatus.open:
        return 0xFF0F7B6C;
      case RabbitStatus.palpateDue:
        return 0xFFCB8347;
      case RabbitStatus.pregnant:
        return 0xFF9C6ADE;
      case RabbitStatus.nursing:
        return 0xFF2E7BB5;
      case RabbitStatus.resting:
        return 0xFF787774;
      case RabbitStatus.active:
        return 0xFF0F7B6C;
      case RabbitStatus.inactive:
        return 0xFF9B9A97;
      case RabbitStatus.growout:
        return 0xFFCB8347;
      case RabbitStatus.quarantine:
        return 0xFFD44C47;
      case RabbitStatus.archived:
        return 0xFF9B9A97;
    }
  }

  // Get subtitle info based on status
  String get statusSubtitle {
    switch (status) {
      case RabbitStatus.palpateDue:
        return 'Day 14 Check';
      case RabbitStatus.pregnant:
        if (daysUntilDue != null) {
          return 'Due: ${dueDate?.day}/${dueDate?.month} • $daysUntilDue Days left';
        }
        return 'Pregnant';
      case RabbitStatus.nursing:
        if (currentLitterSize != null) {
          final weeksOld = weanDate != null ? ((weanDate!.difference(DateTime.now()).inDays.abs()) / 7).floor() : 0;
          return '$currentLitterSize Kits • ${weeksOld} Weeks old';
        }
        return 'Nursing';
      case RabbitStatus.growout:
        if (daysUntilMature != null) {
          return '$daysUntilMature days to mature';
        }
        return 'Growing';
      case RabbitStatus.quarantine:
        if (daysInQuarantineRemaining != null) {
          return '$daysInQuarantineRemaining days remaining';
        }
        return 'Quarantine';
      default:
        return breed;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'status': status.toString(),
      'breed': breed,
      'location': location,
      'cage': cage,
      'details': details,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'color': color,
      'weight': weight,
      'registrationNumber': registrationNumber,
      'sireId': sireId,
      'damId': damId,
      'genetics': genetics,
      'origin': origin,
      'photos': photos?.join(','),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastBreedDate': lastBreedDate?.toIso8601String(),
      'lastBreedBuckId': lastBreedBuckId,
      'palpationDate': palpationDate?.toIso8601String(),
      'palpationResult': palpationResult == true ? 1 : (palpationResult == false ? 0 : null),
      'dueDate': dueDate?.toIso8601String(),
      'kindleDate': kindleDate?.toIso8601String(),
      'currentLitterSize': currentLitterSize,
      'weanDate': weanDate?.toIso8601String(),
      'maturityDate': maturityDate?.toIso8601String(),
      'quarantineStartDate': quarantineStartDate?.toIso8601String(),
      'quarantineEndDate': quarantineEndDate?.toIso8601String(),
      'quarantineReason': quarantineReason,
      'archiveReason': archiveReason?.toString(),
      'archiveDate': archiveDate?.toIso8601String(),
      'archiveNotes': archiveNotes,
      'salePrice': salePrice,
      'buyerInfo': buyerInfo,
      'butcherYield': butcherYield,
      'butcherCost': butcherCost,
      'deathCause': deathCause,
      'cullReason': cullReason,
    };
  }

  factory Rabbit.fromMap(Map<String, dynamic> map) {
    return Rabbit(
      id: map['id'],
      name: map['name'],
      type: RabbitType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => RabbitType.doe,
      ),
      status: RabbitStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => RabbitStatus.open,
      ),
      breed: map['breed'] ?? '',
      location: map['location'],
      cage: map['cage'],
      details: map['details'],
      dateOfBirth: map['dateOfBirth'] != null ? DateTime.parse(map['dateOfBirth']) : null,
      color: map['color'],
      weight: map['weight']?.toDouble(),
      registrationNumber: map['registrationNumber'],
      sireId: map['sireId'],
      damId: map['damId'],
      genetics: map['genetics'],
      origin: map['origin'],
      photos: map['photos'] != null && map['photos'].toString().isNotEmpty ? (map['photos'] as String).split(',') : null,
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      lastBreedDate: map['lastBreedDate'] != null ? DateTime.parse(map['lastBreedDate']) : null,
      lastBreedBuckId: map['lastBreedBuckId'],
      palpationDate: map['palpationDate'] != null ? DateTime.parse(map['palpationDate']) : null,
      palpationResult: map['palpationResult'] != null ? map['palpationResult'] == 1 : null,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      kindleDate: map['kindleDate'] != null ? DateTime.parse(map['kindleDate']) : null,
      currentLitterSize: map['currentLitterSize'],
      weanDate: map['weanDate'] != null ? DateTime.parse(map['weanDate']) : null,
      maturityDate: map['maturityDate'] != null ? DateTime.parse(map['maturityDate']) : null,
      quarantineStartDate: map['quarantineStartDate'] != null ? DateTime.parse(map['quarantineStartDate']) : null,
      quarantineEndDate: map['quarantineEndDate'] != null ? DateTime.parse(map['quarantineEndDate']) : null,
      quarantineReason: map['quarantineReason'],
      archiveReason: map['archiveReason'] != null
          ? ArchiveReason.values.firstWhere(
              (e) => e.toString() == map['archiveReason'],
              orElse: () => ArchiveReason.sold,
            )
          : null,
      archiveDate: map['archiveDate'] != null ? DateTime.parse(map['archiveDate']) : null,
      archiveNotes: map['archiveNotes'],
      salePrice: map['salePrice']?.toDouble(),
      buyerInfo: map['buyerInfo'],
      butcherYield: map['butcherYield']?.toDouble(),
      butcherCost: map['butcherCost']?.toDouble(),
      deathCause: map['deathCause'],
      cullReason: map['cullReason'],
    );
  }

  Rabbit copyWith({
    String? name,
    RabbitType? type,
    RabbitStatus? status,
    String? breed,
    String? location,
    String? cage,
    DateTime? dateOfBirth,
    String? color,
    double? weight,
    String? registrationNumber,
    String? sireId,
    String? damId,
    String? genetics,
    String? origin,
    List<String>? photos,
    String? notes,
    DateTime? lastBreedDate,
    String? lastBreedBuckId,
    DateTime? palpationDate,
    bool? palpationResult,
    DateTime? dueDate,
    DateTime? kindleDate,
    int? currentLitterSize,
    DateTime? weanDate,
    DateTime? maturityDate,
    DateTime? quarantineStartDate,
    DateTime? quarantineEndDate,
    String? quarantineReason,
    ArchiveReason? archiveReason,
    DateTime? archiveDate,
    String? archiveNotes,
    double? salePrice,
    String? buyerInfo,
    double? butcherYield,
    double? butcherCost,
    String? deathCause,
    String? cullReason,
  }) {
    return Rabbit(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      breed: breed ?? this.breed,
      location: location ?? this.location,
      cage: cage ?? this.cage,
      details: details,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      sireId: sireId ?? this.sireId,
      damId: damId ?? this.damId,
      genetics: genetics ?? this.genetics,
      origin: origin ?? this.origin,
      photos: photos ?? this.photos,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastBreedDate: lastBreedDate ?? this.lastBreedDate,
      lastBreedBuckId: lastBreedBuckId ?? this.lastBreedBuckId,
      palpationDate: palpationDate ?? this.palpationDate,
      palpationResult: palpationResult ?? this.palpationResult,
      dueDate: dueDate ?? this.dueDate,
      kindleDate: kindleDate ?? this.kindleDate,
      currentLitterSize: currentLitterSize ?? this.currentLitterSize,
      weanDate: weanDate ?? this.weanDate,
      maturityDate: maturityDate ?? this.maturityDate,
      quarantineStartDate: quarantineStartDate ?? this.quarantineStartDate,
      quarantineEndDate: quarantineEndDate ?? this.quarantineEndDate,
      quarantineReason: quarantineReason ?? this.quarantineReason,
      archiveReason: archiveReason ?? this.archiveReason,
      archiveDate: archiveDate ?? this.archiveDate,
      archiveNotes: archiveNotes ?? this.archiveNotes,
      salePrice: salePrice ?? this.salePrice,
      buyerInfo: buyerInfo ?? this.buyerInfo,
      butcherYield: butcherYield ?? this.butcherYield,
      butcherCost: butcherCost ?? this.butcherCost,
      deathCause: deathCause ?? this.deathCause,
      cullReason: cullReason ?? this.cullReason,
    );
  }
}
