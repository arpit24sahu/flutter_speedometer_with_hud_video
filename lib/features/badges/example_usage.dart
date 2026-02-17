import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:speedometer/services/notification_service.dart';
import 'badge_service.dart';
import 'badge_id.dart';
import 'badge_definitions.dart';

/// Example integration of BadgeService in your TurboGauge app
/// 
/// SETUP STEPS:
/// 
/// 1. Initialize Hive in main():
///    await Hive.initFlutter();
/// 
/// 2. Initialize BadgeService:
///    final badgeService = BadgeService();
///    await badgeService.initialize();
/// 
/// 3. Use Provider or any state management to make it available:
///    ChangeNotifierProvider(create: (_) => badgeService)
/// 
/// 4. Listen to badge unlocks and show notifications

class BadgeServiceExample {
  final BadgeService badgeService;

  BadgeServiceExample(this.badgeService) {
    // Listen to badge service changes
    badgeService.addListener(_onBadgeServiceUpdate);
  }

  /// Initialize awesome notifications for badges
  static Future<void> initializeNotifications() async {
    // Notification Service will be initialized in main i believe
  }

  /// Called when badge service notifies listeners
  void _onBadgeServiceUpdate() {
    final newlyUnlocked = badgeService.newlyUnlockedBadges;
    
    if (newlyUnlocked.isNotEmpty) {
      // Show notification for each newly unlocked badge
      for (final badgeId in newlyUnlocked) {
        _showBadgeUnlockedNotification(badgeId);
      }
      
      // Clear the list after showing notifications
      badgeService.clearNewlyUnlockedBadges();
    }
  }

  /// Show notification when a badge is unlocked
  void _showBadgeUnlockedNotification(BadgeId badgeId) {
    final badge = BadgeDefinitions.getBadgeById(badgeId);
    if (badge == null) return;

    NotificationService().showNotification(
      id: badgeId.index,
      title: '',
      body: '${badge.name}: ${badge.description}',

      // content: NotificationContent(
      //
      //   channelKey: 'badge_channel',
      //   title: '🏆 Badge Unlocked!',
      //
      //   notificationLayout: NotificationLayout.BigText,
      //   color: badge.color,
      //   backgroundColor: badge.color,
      // ),
    );
  }

  // ========== INTEGRATION EXAMPLES ==========

  /// Example: User records a video
  Future<void> onUserRecordsVideo(double maxSpeed) async {
    // Your existing video recording logic...
    
    // Update badge service
    await badgeService.onVideoRecorded(maxSpeed: maxSpeed);
    
    // Notification will be shown automatically via listener
  }

  /// Example: User exports a video
  Future<void> onUserExportsVideo() async {
    // Your existing export logic...
    
    // Update badge service
    await badgeService.onVideoExported();
  }

  /// Example: User shares a video
  Future<void> onUserSharesVideo() async {
    // Your existing share logic...
    
    // Update badge service
    await badgeService.onVideoShared();
  }

  /// Example: User hits a new speed
  Future<void> onUserHitsSpeed(double speed) async {
    // This can be called whenever you detect a new max speed
    await badgeService.onSpeedAchieved(speed);
  }

  /// Example: User purchases premium
  Future<void> onUserPurchasesPremium() async {
    // Your existing premium purchase logic...
    
    // Update badge service
    await badgeService.onPremiumPurchased();
  }

  /// Example: Get data for badges UI
  Widget buildBadgesScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: FutureBuilder(
        future: _getBadgesData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final badgesData = snapshot.data as List<Map<String, dynamic>>;
          
          return ListView.builder(
            itemCount: badgesData.length,
            itemBuilder: (context, index) {
              final badgeData = badgesData[index];
              final badgeJson = badgeData['badge'] as Map<String, dynamic>;
              final isUnlocked = badgeData['isUnlocked'] as bool;
              final progress = badgeData['progress'] as double;
              
              return ListTile(
                leading: Icon(
                  IconData(
                    badgeJson['icon'] as int,
                    fontFamily: 'MaterialIcons',
                  ),
                  color: isUnlocked 
                      ? Color(badgeJson['color'] as int)
                      : Colors.grey,
                ),
                title: Text(badgeJson['name'] as String),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(badgeJson['description'] as String),
                    if (!isUnlocked && progress > 0)
                      LinearProgressIndicator(value: progress),
                  ],
                ),
                trailing: isUnlocked 
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : Text('${(progress * 100).toInt()}%'),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getBadgesData() async {
    return badgeService.getAllBadgesForUI();
  }

  /// Example: Get stats summary for dashboard
  Widget buildStatsWidget() {
    final stats = badgeService.getStatsSummary();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Badges: ${stats['unlockedBadges']}/${stats['totalBadges']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: stats['progress'] as double),
            const SizedBox(height: 16),
            Text('Videos Recorded: ${stats['videosRecorded']}'),
            Text('Videos Exported: ${stats['videosExported']}'),
            Text('Current Streak: ${stats['currentStreak']} days'),
            Text('Max Speed: ${stats['maxSpeedAchieved']} km/h'),
          ],
        ),
      ),
    );
  }

  /// Example: Display badges by category
  Future<Map<String, List<Map<String, dynamic>>>> getBadgesByCategory() async {
    return badgeService.getBadgesByCategory();
  }

  void dispose() {
    badgeService.removeListener(_onBadgeServiceUpdate);
  }
}
