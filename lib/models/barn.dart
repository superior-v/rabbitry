import 'dart:convert';

class BarnRow {
  final String name;
  final List<String> cages;

  BarnRow({
    required this.name,
    required this.cages,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cages': cages,
    };
  }

  factory BarnRow.fromMap(Map<String, dynamic> map) {
    return BarnRow(
      name: map['name'] as String,
      cages: List<String>.from(map['cages']),
    );
  }
}

class Barn {
  final String id;
  final String name;
  final List<BarnRow> rows;
  final String? notes;
  final DateTime createdAt;

  Barn({
    required this.id,
    required this.name,
    required this.rows,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert rows to JSON string for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rows': jsonEncode(rows.map((r) => r.toMap()).toList()), // Store as JSON string
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Barn.fromMap(Map<String, dynamic> map) {
    // Parse rows from JSON string
    List<BarnRow> parsedRows = [];
    if (map['rows'] != null) {
      try {
        final rowsData = jsonDecode(map['rows'] as String) as List;
        parsedRows = rowsData.map((r) => BarnRow.fromMap(r as Map<String, dynamic>)).toList();
      } catch (e) {
        print('Error parsing barn rows: $e');
      }
    }

    return Barn(
      id: map['id'] as String,
      name: map['name'] as String,
      rows: parsedRows,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
    );
  }
}
