import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'badge_id.dart';
import 'badge_model.dart';
import 'badge_definitions.dart';
import 'badge_kpi_data.dart';

/// Service to manage badge achievements and KPI tracking
class BadgeService extends ChangeNotifier {
  static const String _kpiBoxName = 'badge_kpi_box';
  static const String _badgeBoxName = 'badge_achievements_box';
  static const String _kpiKey = 'user_kpi_data';
  static const String _badgeKey = 'badge_achievements';

  Box? _kpiBox;
  Box? _badgeBox;
  
  BadgeKpiData _kpiData = BadgeKpiData();
  Map<BadgeId, DateTime?> _badgeAchievements = {};
  
  bool _isInitialized = false;
  
  /// List of newly unlocked badges (to show notifications)
  final List<BadgeId> _newlyUnlockedBadges = [];

  BadgeService();

  // Getters
  bool get isInitialized => _isInitialized;
  BadgeKpiData get kpiData => _kpiData;
  Map<BadgeId, DateTime?> get badgeAchievements => Map.unmodifiable(_badgeAchievements);
  List<BadgeId> get newlyUnlockedBadges => List.unmodifiable(_newlyUnlockedBadges);

  /// Initialize the service and load data from Hive
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Open Hive boxes
      _kpiBox = await Hive.openBox(_kpiBoxName);
      _badgeBox = await Hive.openBox(_badgeBoxName);

      // Load KPI data
      await _loadKpiData();

      // Load badge achievements
      await _loadBadgeAchievements();

      _isInitialized = true;
      debugPrint('BadgeService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing BadgeService: $e');
      rethrow;
    }
  }

  /// Load KPI data from Hive
  Future<void> _loadKpiData() async {
    try {
      final jsonString = _kpiBox?.get(_kpiKey) as String?;
      if (jsonString != null) {
        final Map<String, dynamic> jsonData = json.decode(jsonString);
        _kpiData = BadgeKpiData.fromJson(jsonData);
        debugPrint('KPI data loaded: $_kpiData');
      } else {
        debugPrint('No existing KPI data found, using defaults');
      }
    } catch (e) {
      debugPrint('Error loading KPI data: $e');
      _kpiData = BadgeKpiData();
    }
  }

  /// Save KPI data to Hive
  Future<void> _saveKpiData() async {
    try {
      final jsonString = json.encode(_kpiData.toJson());
      await _kpiBox?.put(_kpiKey, jsonString);
      debugPrint('KPI data saved');
    } catch (e) {
      debugPrint('Error saving KPI data: $e');
    }
  }

  /// Load badge achievements from Hive
  Future<void> _loadBadgeAchievements() async {
    try {
      final jsonString = _badgeBox?.get(_badgeKey) as String?;
      if (jsonString != null) {
        final Map<String, dynamic> jsonData = json.decode(jsonString);
        _badgeAchievements = jsonData.map((key, value) {
          final badgeId = BadgeId.values.firstWhere((e) => e.name == key);
          final dateTime = value != null ? DateTime.parse(value as String) : null;
          return MapEntry(badgeId, dateTime);
        });
        debugPrint('Badge achievements loaded: ${_badgeAchievements.length} badges');
      } else {
        // Initialize all badges as not achieved
        _badgeAchievements = {
          for (var badgeId in BadgeId.values) badgeId: null,
        };
        await _saveBadgeAchievements();
        debugPrint('Initialized badge achievements');
      }
    } catch (e) {
      debugPrint('Error loading badge achievements: $e');
      _badgeAchievements = {
        for (var badgeId in BadgeId.values) badgeId: null,
      };
    }
  }

  /// Save badge achievements to Hive
  Future<void> _saveBadgeAchievements() async {
    try {
      final jsonData = _badgeAchievements.map((key, value) {
        return MapEntry(key.name, value?.toIso8601String());
      });
      final jsonString = json.encode(jsonData);
      await _badgeBox?.put(_badgeKey, jsonString);
      debugPrint('Badge achievements saved');
    } catch (e) {
      debugPrint('Error saving badge achievements: $e');
    }
  }

  /// Check if a badge is unlocked
  bool isBadgeUnlocked(BadgeId badgeId) {
    return _badgeAchievements[badgeId] != null;
  }

  /// Get the unlock date of a badge
  DateTime? getBadgeUnlockDate(BadgeId badgeId) {
    return _badgeAchievements[badgeId];
  }

  /// Unlock a badge
  Future<void> _unlockBadge(BadgeId badgeId) async {
    if (_badgeAchievements[badgeId] == null) {
      _badgeAchievements[badgeId] = DateTime.now();
      _newlyUnlockedBadges.add(badgeId);
      await _saveBadgeAchievements();
      debugPrint('Badge unlocked: ${badgeId.name}');
      notifyListeners();
    }
  }

  /// Clear newly unlocked badges list (call after showing notifications)
  void clearNewlyUnlockedBadges() {
    _newlyUnlockedBadges.clear();
  }

  /// Check and unlock badges based on current KPI data
  Future<void> _checkAndUnlockBadges() async {
    // Recording badges
    if (_kpiData.videosRecorded >= 1) {
      await _unlockBadge(BadgeId.firstVideo);
    }
    if (_kpiData.videosRecorded >= 20) {
      await _unlockBadge(BadgeId.record20Videos);
    }
    if (_kpiData.videosRecorded >= 50) {
      await _unlockBadge(BadgeId.record50Videos);
    }

    // Export badges
    if (_kpiData.videosExported >= 1) {
      await _unlockBadge(BadgeId.export1Video);
    }
    if (_kpiData.videosExported >= 20) {
      await _unlockBadge(BadgeId.export20Videos);
    }
    if (_kpiData.videosExported >= 50) {
      await _unlockBadge(BadgeId.export50Videos);
    }

    // Streak badges
    if (_kpiData.longestStreak >= 3) {
      await _unlockBadge(BadgeId.streak3Days);
    }
    if (_kpiData.longestStreak >= 10) {
      await _unlockBadge(BadgeId.streak10Days);
    }
    if (_kpiData.longestStreak >= 25) {
      await _unlockBadge(BadgeId.streak25Days);
    }

    // Share badges
    if (_kpiData.videosShared >= 1) {
      await _unlockBadge(BadgeId.share1Video);
    }
    if (_kpiData.videosShared >= 10) {
      await _unlockBadge(BadgeId.share10Videos);
    }
    if (_kpiData.videosShared >= 25) {
      await _unlockBadge(BadgeId.share25Videos);
    }

    // Speed badges
    if (_kpiData.maxSpeedAchieved >= 50) {
      await _unlockBadge(BadgeId.speed50Kmph);
    }
    if (_kpiData.maxSpeedAchieved >= 80) {
      await _unlockBadge(BadgeId.speed80Kmph);
    }
    if (_kpiData.maxSpeedAchieved >= 100) {
      await _unlockBadge(BadgeId.speed100Kmph);
    }
    if (_kpiData.maxSpeedAchieved >= 120) {
      await _unlockBadge(BadgeId.speed120Kmph);
    }
    if (_kpiData.maxSpeedAchieved >= 150) {
      await _unlockBadge(BadgeId.speed150Kmph);
    }
    if (_kpiData.maxSpeedAchieved >= 200) {
      await _unlockBadge(BadgeId.speed200Kmph);
    }
    if (_kpiData.maxSpeedAchieved >= 250) {
      await _unlockBadge(BadgeId.speed250Kmph);
    }
    if (_kpiData.maxSpeedAchieved >= 500) {
      await _unlockBadge(BadgeId.speed500Kmph);
    }
    if (_kpiData.maxSpeedAchieved >= 800) {
      await _unlockBadge(BadgeId.speed800Kmph);
    }
    if (_kpiData.maxSpeedAchieved >= 1000) {
      await _unlockBadge(BadgeId.speed1000Kmph);
    }

    // Premium badge
    if (_kpiData.isPremiumUser) {
      await _unlockBadge(BadgeId.purchasePremium);
    }

    // Leaderboard badges
    if (_kpiData.dailyLeaderboardAppearances >= 1) {
      await _unlockBadge(BadgeId.dailyLeaderboard1Time);
    }
    if (_kpiData.dailyLeaderboardAppearances >= 10) {
      await _unlockBadge(BadgeId.dailyLeaderboard10Times);
    }
    if (_kpiData.dailyLeaderboardFirstPlaces >= 1) {
      await _unlockBadge(BadgeId.dailyLeaderboard1TimeFirst);
    }
    if (_kpiData.dailyLeaderboardFirstPlaces >= 10) {
      await _unlockBadge(BadgeId.dailyLeaderboard10TimesFirst);
    }
  }

  /// Update streak based on recording date
  void _updateStreak(DateTime recordingDate) {
    final today = DateTime.now();
    final todayString = _formatDate(today);
    final recordingDateString = _formatDate(recordingDate);

    // Add recording date if not already present
    if (!_kpiData.recordingDates.contains(recordingDateString)) {
      _kpiData.recordingDates.add(recordingDateString);
    }

    if (_kpiData.lastRecordingDate == null) {
      // First recording
      _kpiData.currentStreak = 1;
      _kpiData.longestStreak = 1;
      _kpiData.lastRecordingDate = recordingDate;
    } else {
      final lastDateString = _formatDate(_kpiData.lastRecordingDate!);
      final daysDifference = _calculateDaysDifference(lastDateString, recordingDateString);

      if (daysDifference == 0) {
        // Same day, no change to streak
        return;
      } else if (daysDifference == 1) {
        // Consecutive day, increment streak
        _kpiData.currentStreak += 1;
        if (_kpiData.currentStreak > _kpiData.longestStreak) {
          _kpiData.longestStreak = _kpiData.currentStreak;
        }
        _kpiData.lastRecordingDate = recordingDate;
      } else {
        // Streak broken, reset to 1
        _kpiData.currentStreak = 1;
        _kpiData.lastRecordingDate = recordingDate;
      }
    }
  }

  /// Format date as yyyy-MM-dd
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Calculate days difference between two date strings
  int _calculateDaysDifference(String date1String, String date2String) {
    final date1 = DateTime.parse(date1String);
    final date2 = DateTime.parse(date2String);
    final difference = date2.difference(date1);
    return difference.inDays;
  }

  // ========== PUBLIC METHODS TO UPDATE KPIs ==========

  /// Call this when user records a video
  Future<void> onVideoRecorded({double? maxSpeed}) async {
    _ensureInitialized();
    
    _kpiData.videosRecorded += 1;
    _updateStreak(DateTime.now());
    
    if (maxSpeed != null && maxSpeed > _kpiData.maxSpeedAchieved) {
      _kpiData.maxSpeedAchieved = maxSpeed;
    }
    
    await _saveKpiData();
    await _checkAndUnlockBadges();
  }

  /// Call this when user exports a video
  Future<void> onVideoExported() async {
    _ensureInitialized();
    
    _kpiData.videosExported += 1;
    
    await _saveKpiData();
    await _checkAndUnlockBadges();
  }

  /// Call this when user shares a video
  Future<void> onVideoShared() async {
    _ensureInitialized();
    
    _kpiData.videosShared += 1;
    
    await _saveKpiData();
    await _checkAndUnlockBadges();
  }

  /// Call this when user achieves a new max speed
  Future<void> onSpeedAchieved(double speed) async {
    _ensureInitialized();
    
    if (speed > _kpiData.maxSpeedAchieved) {
      _kpiData.maxSpeedAchieved = speed;
      await _saveKpiData();
      await _checkAndUnlockBadges();
    }
  }

  /// Call this when user purchases premium
  Future<void> onPremiumPurchased() async {
    _ensureInitialized();
    
    _kpiData.isPremiumUser = true;
    
    await _saveKpiData();
    await _checkAndUnlockBadges();
  }

  /// Call this when user appears on daily leaderboard
  Future<void> onDailyLeaderboardAppearance({bool isFirstPlace = false}) async {
    _ensureInitialized();
    
    _kpiData.dailyLeaderboardAppearances += 1;
    if (isFirstPlace) {
      _kpiData.dailyLeaderboardFirstPlaces += 1;
    }
    
    await _saveKpiData();
    await _checkAndUnlockBadges();
  }

  /// Manual method to recheck all badges (useful for debugging or data migration)
  Future<void> recheckAllBadges() async {
    _ensureInitialized();
    await _checkAndUnlockBadges();
  }

  // ========== UI DATA METHODS ==========

  /// Get all badges with their unlock status for UI
  List<Map<String, dynamic>> getAllBadgesForUI() {
    final sortedBadges = BadgeDefinitions.sortedBadges;
    
    return sortedBadges.map((badge) {
      final isUnlocked = isBadgeUnlocked(badge.id);
      final unlockDate = getBadgeUnlockDate(badge.id);
      
      return {
        'badge': badge.toJson(),
        'isUnlocked': isUnlocked,
        'unlockDate': unlockDate?.toIso8601String(),
        'progress': _calculateProgress(badge.id),
      };
    }).toList();
  }

  /// Get badges by category for UI
  Map<String, List<Map<String, dynamic>>> getBadgesByCategory() {
    return {
      'recording': _getBadgeCategoryForUI(BadgeDefinitions.getRecordingBadges()),
      'export': _getBadgeCategoryForUI(BadgeDefinitions.getExportBadges()),
      'streak': _getBadgeCategoryForUI(BadgeDefinitions.getStreakBadges()),
      'share': _getBadgeCategoryForUI(BadgeDefinitions.getShareBadges()),
      'speed': _getBadgeCategoryForUI(BadgeDefinitions.getSpeedBadges()),
      'premium': _getBadgeCategoryForUI([BadgeDefinitions.getBadgeById(BadgeId.purchasePremium)!]),
      'leaderboard': _getBadgeCategoryForUI(BadgeDefinitions.getLeaderboardBadges()),
    };
  }

  List<Map<String, dynamic>> _getBadgeCategoryForUI(List<AppBadge> badges) {
    return badges.map((badge) {
      final isUnlocked = isBadgeUnlocked(badge.id);
      final unlockDate = getBadgeUnlockDate(badge.id);
      
      return {
        'badge': badge.toJson(),
        'isUnlocked': isUnlocked,
        'unlockDate': unlockDate?.toIso8601String(),
        'progress': _calculateProgress(badge.id),
      };
    }).toList();
  }

  /// Calculate progress towards a badge (0.0 to 1.0)
  double _calculateProgress(BadgeId badgeId) {
    if (isBadgeUnlocked(badgeId)) return 1.0;

    switch (badgeId) {
      // Recording badges
      case BadgeId.firstVideo:
        return _kpiData.videosRecorded >= 1 ? 1.0 : _kpiData.videosRecorded / 1.0;
      case BadgeId.record20Videos:
        return (_kpiData.videosRecorded / 20).clamp(0.0, 1.0);
      case BadgeId.record50Videos:
        return (_kpiData.videosRecorded / 50).clamp(0.0, 1.0);

      // Export badges
      case BadgeId.export1Video:
        return _kpiData.videosExported >= 1 ? 1.0 : _kpiData.videosExported / 1.0;
      case BadgeId.export20Videos:
        return (_kpiData.videosExported / 20).clamp(0.0, 1.0);
      case BadgeId.export50Videos:
        return (_kpiData.videosExported / 50).clamp(0.0, 1.0);

      // Streak badges
      case BadgeId.streak3Days:
        return (_kpiData.longestStreak / 3).clamp(0.0, 1.0);
      case BadgeId.streak10Days:
        return (_kpiData.longestStreak / 10).clamp(0.0, 1.0);
      case BadgeId.streak25Days:
        return (_kpiData.longestStreak / 25).clamp(0.0, 1.0);

      // Share badges
      case BadgeId.share1Video:
        return _kpiData.videosShared >= 1 ? 1.0 : _kpiData.videosShared / 1.0;
      case BadgeId.share10Videos:
        return (_kpiData.videosShared / 10).clamp(0.0, 1.0);
      case BadgeId.share25Videos:
        return (_kpiData.videosShared / 25).clamp(0.0, 1.0);

      // Speed badges
      case BadgeId.speed50Kmph:
        return (_kpiData.maxSpeedAchieved / 50).clamp(0.0, 1.0);
      case BadgeId.speed80Kmph:
        return (_kpiData.maxSpeedAchieved / 80).clamp(0.0, 1.0);
      case BadgeId.speed100Kmph:
        return (_kpiData.maxSpeedAchieved / 100).clamp(0.0, 1.0);
      case BadgeId.speed120Kmph:
        return (_kpiData.maxSpeedAchieved / 120).clamp(0.0, 1.0);
      case BadgeId.speed150Kmph:
        return (_kpiData.maxSpeedAchieved / 150).clamp(0.0, 1.0);
      case BadgeId.speed200Kmph:
        return (_kpiData.maxSpeedAchieved / 200).clamp(0.0, 1.0);
      case BadgeId.speed250Kmph:
        return (_kpiData.maxSpeedAchieved / 250).clamp(0.0, 1.0);
      case BadgeId.speed500Kmph:
        return (_kpiData.maxSpeedAchieved / 500).clamp(0.0, 1.0);
      case BadgeId.speed800Kmph:
        return (_kpiData.maxSpeedAchieved / 800).clamp(0.0, 1.0);
      case BadgeId.speed1000Kmph:
        return (_kpiData.maxSpeedAchieved / 1000).clamp(0.0, 1.0);

      // Premium badge
      case BadgeId.purchasePremium:
        return _kpiData.isPremiumUser ? 1.0 : 0.0;

      // Leaderboard badges
      case BadgeId.dailyLeaderboard1Time:
        return _kpiData.dailyLeaderboardAppearances >= 1 ? 1.0 : 0.0;
      case BadgeId.dailyLeaderboard10Times:
        return (_kpiData.dailyLeaderboardAppearances / 10).clamp(0.0, 1.0);
      case BadgeId.dailyLeaderboard1TimeFirst:
        return _kpiData.dailyLeaderboardFirstPlaces >= 1 ? 1.0 : 0.0;
      case BadgeId.dailyLeaderboard10TimesFirst:
        return (_kpiData.dailyLeaderboardFirstPlaces / 10).clamp(0.0, 1.0);
    }
  }

  /// Get statistics summary for UI
  Map<String, dynamic> getStatsSummary() {
    final totalBadges = BadgeId.values.length;
    final unlockedBadges = _badgeAchievements.values.where((date) => date != null).length;
    
    return {
      'totalBadges': totalBadges,
      'unlockedBadges': unlockedBadges,
      'progress': totalBadges > 0 ? unlockedBadges / totalBadges : 0.0,
      'videosRecorded': _kpiData.videosRecorded,
      'videosExported': _kpiData.videosExported,
      'videosShared': _kpiData.videosShared,
      'currentStreak': _kpiData.currentStreak,
      'longestStreak': _kpiData.longestStreak,
      'maxSpeedAchieved': _kpiData.maxSpeedAchieved,
      'isPremiumUser': _kpiData.isPremiumUser,
    };
  }

  /// Get recently unlocked badges (last 7 days)
  List<Map<String, dynamic>> getRecentlyUnlockedBadges({int days = 7}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    final recentBadges = _badgeAchievements.entries
        .where((entry) => 
            entry.value != null && 
            entry.value!.isAfter(cutoffDate))
        .map((entry) {
          final badge = BadgeDefinitions.getBadgeById(entry.key);
          return {
            'badge': badge?.toJson(),
            'unlockDate': entry.value?.toIso8601String(),
          };
        })
        .toList();

    // Sort by unlock date (most recent first)
    recentBadges.sort((a, b) {
      final dateA = DateTime.parse(a['unlockDate'] as String);
      final dateB = DateTime.parse(b['unlockDate'] as String);
      return dateB.compareTo(dateA);
    });

    return recentBadges;
  }

  // ========== UTILITY METHODS ==========

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('BadgeService must be initialized before use. Call initialize() first.');
    }
  }

  /// Reset all data (for testing or user request)
  Future<void> resetAllData() async {
    _ensureInitialized();
    
    _kpiData = BadgeKpiData();
    _badgeAchievements = {
      for (var badgeId in BadgeId.values) badgeId: null,
    };
    _newlyUnlockedBadges.clear();
    
    await _saveKpiData();
    await _saveBadgeAchievements();
    
    notifyListeners();
    debugPrint('All badge data reset');
  }

  /// Close Hive boxes when service is disposed
  @override
  void dispose() {
    _kpiBox?.close();
    _badgeBox?.close();
    super.dispose();
  }
}
