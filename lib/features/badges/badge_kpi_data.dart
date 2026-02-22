class BadgeKpiData {
  // Recording stats
  int videosRecorded;
  int videosExported;
  int videosShared;
  
  // Streak tracking
  int currentStreak;
  int longestStreak;
  DateTime? lastRecordingDate;
  
  // Speed achievements
  double maxSpeedAchieved;
  
  // Premium
  bool isPremiumUser;
  
  // Leaderboard stats (future)
  int dailyLeaderboardAppearances;
  int dailyLeaderboardFirstPlaces;
  
  // History tracking for streaks
  List<String> recordingDates; // Store as 'yyyy-MM-dd' strings

  BadgeKpiData({
    this.videosRecorded = 0,
    this.videosExported = 0,
    this.videosShared = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastRecordingDate,
    this.maxSpeedAchieved = 0.0,
    this.isPremiumUser = false,
    this.dailyLeaderboardAppearances = 0,
    this.dailyLeaderboardFirstPlaces = 0,
    List<String>? recordingDates,
  }) : recordingDates = recordingDates ?? [];

  Map<String, dynamic> toJson() => {
        'videosRecorded': videosRecorded,
        'videosExported': videosExported,
        'videosShared': videosShared,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastRecordingDate': lastRecordingDate?.toIso8601String(),
        'maxSpeedAchieved': maxSpeedAchieved,
        'isPremiumUser': isPremiumUser,
        'dailyLeaderboardAppearances': dailyLeaderboardAppearances,
        'dailyLeaderboardFirstPlaces': dailyLeaderboardFirstPlaces,
        'recordingDates': recordingDates,
      };

  factory BadgeKpiData.fromJson(Map<String, dynamic> json) => BadgeKpiData(
        videosRecorded: json['videosRecorded'] as int? ?? 0,
        videosExported: json['videosExported'] as int? ?? 0,
        videosShared: json['videosShared'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        longestStreak: json['longestStreak'] as int? ?? 0,
        lastRecordingDate: json['lastRecordingDate'] != null 
            ? DateTime.parse(json['lastRecordingDate'] as String) 
            : null,
        maxSpeedAchieved: (json['maxSpeedAchieved'] as num?)?.toDouble() ?? 0.0,
        isPremiumUser: json['isPremiumUser'] as bool? ?? false,
        dailyLeaderboardAppearances: json['dailyLeaderboardAppearances'] as int? ?? 0,
        dailyLeaderboardFirstPlaces: json['dailyLeaderboardFirstPlaces'] as int? ?? 0,
        recordingDates: (json['recordingDates'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
      );

  BadgeKpiData copyWith({
    int? videosRecorded,
    int? videosExported,
    int? videosShared,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastRecordingDate,
    double? maxSpeedAchieved,
    bool? isPremiumUser,
    int? dailyLeaderboardAppearances,
    int? dailyLeaderboardFirstPlaces,
    List<String>? recordingDates,
  }) {
    return BadgeKpiData(
      videosRecorded: videosRecorded ?? this.videosRecorded,
      videosExported: videosExported ?? this.videosExported,
      videosShared: videosShared ?? this.videosShared,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastRecordingDate: lastRecordingDate ?? this.lastRecordingDate,
      maxSpeedAchieved: maxSpeedAchieved ?? this.maxSpeedAchieved,
      isPremiumUser: isPremiumUser ?? this.isPremiumUser,
      dailyLeaderboardAppearances: dailyLeaderboardAppearances ?? this.dailyLeaderboardAppearances,
      dailyLeaderboardFirstPlaces: dailyLeaderboardFirstPlaces ?? this.dailyLeaderboardFirstPlaces,
      recordingDates: recordingDates ?? this.recordingDates,
    );
  }

  @override
  String toString() {
    return 'BadgeKpiData(videosRecorded: $videosRecorded, videosExported: $videosExported, '
        'videosShared: $videosShared, currentStreak: $currentStreak, '
        'maxSpeedAchieved: $maxSpeedAchieved, isPremium: $isPremiumUser)';
  }
}
