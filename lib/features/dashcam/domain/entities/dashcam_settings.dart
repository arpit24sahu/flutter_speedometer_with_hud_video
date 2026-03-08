class DashcamSettings {
  final int maxStorageGb;
  final int segmentDurationSeconds;
  final bool enableMic;
  final bool enableGps;
  final bool enableGShock;
  final String speedUnit;
  final String videoQuality;
  final int frameRate;
  final int speedLimit;
  
  const DashcamSettings({
    this.maxStorageGb = 20,
    this.segmentDurationSeconds = 120,
    this.enableMic = true,
    this.enableGps = true,
    this.enableGShock = true,
    this.speedUnit = 'km/h',
    this.videoQuality = '4K',
    this.frameRate = 60,
    this.speedLimit = 60,
  });

  DashcamSettings copyWith({
    int? maxStorageGb,
    int? segmentDurationSeconds,
    bool? enableMic,
    bool? enableGps,
    bool? enableGShock,
    String? speedUnit,
    String? videoQuality,
    int? frameRate,
    int? speedLimit,
  }) {
    return DashcamSettings(
      maxStorageGb: maxStorageGb ?? this.maxStorageGb,
      segmentDurationSeconds: segmentDurationSeconds ?? this.segmentDurationSeconds,
      enableMic: enableMic ?? this.enableMic,
      enableGps: enableGps ?? this.enableGps,
      enableGShock: enableGShock ?? this.enableGShock,
      speedUnit: speedUnit ?? this.speedUnit,
      videoQuality: videoQuality ?? this.videoQuality,
      frameRate: frameRate ?? this.frameRate,
      speedLimit: speedLimit ?? this.speedLimit,
    );
  }

  Map<dynamic, dynamic> toMap() => {
    'maxStorageGb': maxStorageGb,
    'segmentDurationSeconds': segmentDurationSeconds,
    'enableMic': enableMic,
    'enableGps': enableGps,
    'enableGShock': enableGShock,
    'speedUnit': speedUnit,
    'videoQuality': videoQuality,
    'frameRate': frameRate,
    'speedLimit': speedLimit,
  };
  
  factory DashcamSettings.fromMap(Map<dynamic, dynamic> map) {
    return DashcamSettings(
      maxStorageGb: map['maxStorageGb'] as int? ?? 20,
      segmentDurationSeconds: map['segmentDurationSeconds'] as int? ?? 120,
      enableMic: map['enableMic'] as bool? ?? true,
      enableGps: map['enableGps'] as bool? ?? true,
      enableGShock: map['enableGShock'] as bool? ?? true,
      speedUnit: map['speedUnit'] as String? ?? 'km/h',
      videoQuality: map['videoQuality'] as String? ?? '4K',
      frameRate: map['frameRate'] as int? ?? 60,
      speedLimit: map['speedLimit'] as int? ?? 60,
    );
  }
}
