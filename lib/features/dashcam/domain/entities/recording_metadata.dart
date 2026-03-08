class RecordingMetadata {
  final String id;
  final String path;
  final int timestamp;
  final bool isLocked;

  RecordingMetadata({
    required this.id,
    required this.path,
    required this.timestamp,
    this.isLocked = false,
  });

  RecordingMetadata copyWith({bool? isLocked}) {
    return RecordingMetadata(
      id: id,
      path: path,
      timestamp: timestamp,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'timestamp': timestamp,
      'isLocked': isLocked,
    };
  }

  factory RecordingMetadata.fromMap(Map<dynamic, dynamic> map) {
    return RecordingMetadata(
      id: map['id'] as String,
      path: map['path'] as String,
      timestamp: map['timestamp'] as int,
      isLocked: map['isLocked'] as bool? ?? false,
    );
  }
}
