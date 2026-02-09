class Task {
  final String id;
  final String? rabbitId;
  final String? rabbitName;
  final String title;
  final String? description;
  final DateTime dueDate;
  final bool completed;
  final String category; // 'Husbandry', 'Health', 'Maintenance'
  final DateTime createdAt;

  Task({
    required this.id,
    this.rabbitId,
    this.rabbitName,
    required this.title,
    this.description,
    required this.dueDate,
    this.completed = false,
    required this.category,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rabbitId': rabbitId,
      'rabbitName': rabbitName,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'completed': completed ? 1 : 0,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      rabbitId: map['rabbitId'],
      rabbitName: map['rabbitName'],
      title: map['title'],
      description: map['description'],
      dueDate: DateTime.parse(map['dueDate']),
      completed: map['completed'] == 1,
      category: map['category'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Task copyWith({
    String? id,
    String? rabbitId,
    String? rabbitName,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? completed,
    String? category,
  }) {
    return Task(
      id: id ?? this.id,
      rabbitId: rabbitId ?? this.rabbitId,
      rabbitName: rabbitName ?? this.rabbitName,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      category: category ?? this.category,
      createdAt: this.createdAt,
    );
  }
}