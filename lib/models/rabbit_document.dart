class RabbitDocument {
  final String id;
  final String rabbitId;
  final String name;
  final String filePath;
  final String fileType; // image, pdf, file
  final int fileSize; // bytes
  final String createdAt;

  RabbitDocument({
    required this.id,
    required this.rabbitId,
    required this.name,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rabbitId': rabbitId,
      'name': name,
      'filePath': filePath,
      'fileType': fileType,
      'fileSize': fileSize,
      'createdAt': createdAt,
    };
  }

  factory RabbitDocument.fromMap(Map<String, dynamic> map) {
    return RabbitDocument(
      id: map['id'] as String,
      rabbitId: map['rabbitId'] as String,
      name: map['name'] as String,
      filePath: map['filePath'] as String,
      fileType: (map['fileType'] as String?) ?? 'file',
      fileSize: (map['fileSize'] as int?) ?? 0,
      createdAt: map['createdAt'] as String,
    );
  }

  RabbitDocument copyWith({
    String? id,
    String? rabbitId,
    String? name,
    String? filePath,
    String? fileType,
    int? fileSize,
    String? createdAt,
  }) {
    return RabbitDocument(
      id: id ?? this.id,
      rabbitId: rabbitId ?? this.rabbitId,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
