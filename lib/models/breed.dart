class Breed {
  final String id;
  final String name;
  final List<String> genetics; // e.g., ['Aa', 'Bb', 'C_']

  Breed({
    required this.id,
    required this.name,
    required this.genetics,
  });

  // Convert to Map for Database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'genetics': genetics.join(','), // Store as comma-separated string
    };
  }

  // Create from Map (Database)
  factory Breed.fromMap(Map<String, dynamic> map) {
    return Breed(
      id: map['id'],
      name: map['name'],
      genetics: (map['genetics'] as String).split(',').where((g) => g.isNotEmpty).toList(),
    );
  }
}
