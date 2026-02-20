import 'package:flutter/material.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/badges/stats_page.dart';
import 'package:speedometer/services/notification_service.dart';
import 'badge_bottom_sheet.dart';
import 'badge_service.dart';
import 'badge_id.dart';
import 'badge_definitions.dart';
import 'badge_model.dart';
import 'badge_unlock_dialog.dart';
import 'badges_page.dart';
import 'badge_status_page.dart';
import '../../core/dialogs/dialog_manager.dart';
import '../../core/dialogs/app_dialog_item.dart';

/// Comprehensive manager for badge system
/// Handles initialization, navigation, notifications, and UI presentation
class BadgeManager {
  final BadgeService badgeService;
  final GlobalKey<NavigatorState> navigatorKey;

  BadgeManager({required this.badgeService, required this.navigatorKey}) {
    _setupListener();
  }

  // ==================== INITIALIZATION ====================

  /// Initialize the badge manager (call in main.dart)
  static Future<BadgeManager> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    // Initialize badge service
    final badgeService = BadgeService();
    await badgeService.initialize();

    return BadgeManager(badgeService: badgeService, navigatorKey: navigatorKey);
  }

  // ==================== LISTENER SETUP ====================

  /// Setup listener for badge unlocks
  void _setupListener() {
    badgeService.addListener(_handleBadgeServiceUpdate);
  }

  /// Handle badge service updates
  void _handleBadgeServiceUpdate() {
    final newlyUnlocked = badgeService.newlyUnlockedBadges;

    if (newlyUnlocked.isNotEmpty) {
      // Map to actual badge objects and sort them by level (easy first) to ensure
      // they are enqueued into the DialogManager in the desired order.
      final badgesToUnlock =
          newlyUnlocked
              .map((id) => BadgeDefinitions.getBadgeById(id))
              .whereType<AppBadge>()
              .toList()
            ..sort((a, b) => a.level.compareTo(b.level));

      for (final badge in badgesToUnlock) {
        _onBadgeUnlocked(badge.id);
      }

      badgeService.clearNewlyUnlockedBadges();
    }
  }

  /// Called when a badge is unlocked
  void _onBadgeUnlocked(BadgeId badgeId) {
    final badge = BadgeDefinitions.getBadgeById(badgeId);
    if (badge == null) return;

    // Track analytics event
    AnalyticsService().trackEvent(
      AnalyticsEvents.badgeUnlocked,
      properties: {
        AnalyticsParams.badgeId: badgeId.name,
        AnalyticsParams.badgeName: badge.name,
        AnalyticsParams.badgeDescription: badge.description,
        AnalyticsParams.badgeTier: badge.tier,
        AnalyticsParams.badgeLevel: badge.level,
      },
    );

    // Show notification
    _showBadgeNotification(badge);

    // Show in-app dialog if app is active
    _showBadgeUnlockDialog(badge);
  }

  // ==================== NOTIFICATIONS ====================

  /// Show notification for unlocked badge
  Future<void> _showBadgeNotification(AppBadge badge) async {
    await NotificationService().showNotification(
      id: badge.id.index,
      title: '🏆 Badge Unlocked!',
      body: '${badge.name}: ${badge.description}',
    );
  }

  // ==================== IN-APP DIALOGS ====================

  /// Show in-app dialog for unlocked badge
  void _showBadgeUnlockDialog(AppBadge badge) {
    DialogManager().showDialog(
      AppDialogItem(
        dialogWidget: BadgeUnlockDialog(
          badge: badge,
          onViewBadges: () {
            // Small delay so the dialog dismiss finishes first
            Future.delayed(const Duration(milliseconds: 50), () {
              showBadgeStatusPage();
            });
          },
        ),
        soundPath: 'assets/sound/tip.mp3',
        barrierDismissible: true,
        priority: badge.level, // lower levels will be shown first
      ),
    );
  }

  // ==================== NAVIGATION ====================

  /// Navigate to badges page
  Future<void> navigateToBadgesPage({bool fullScreen = true}) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (fullScreen) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BadgesPage(badgeService: badgeService),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => BadgesPage(badgeService: badgeService),
        ),
      );
    }
  }

  /// Navigate to stats page
  Future<void> navigateToStatsPage({bool fullScreen = true}) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (fullScreen) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StatsPage(badgeService: badgeService),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => StatsPage(badgeService: badgeService),
        ),
      );
    }
  }

  // ==================== BOTTOM SHEETS ====================

  /// Show badges in bottom sheet
  Future<void> showBadgesBottomSheet({
    BadgeCategory? category,
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => BadgeBottomSheet(badgeService: badgeService, category: category),
    );
  }

  /// Show the new Badge Status Page in a bottom sheet
  Future<void> showBadgeStatusPage() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const BadgeStatusPage(),
                ),
          ),
    );
  }

  /// Show stats in bottom sheet
  Future<void> showStatsBottomSheet({
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => StatsPage(
            badgeService: badgeService,
            scrollController: scrollController,
            isBottomSheet: true,
          ),
        ),
      ),
    );
  }

  /// Show specific badge details in bottom sheet
  Future<void> showBadgeDetailsBottomSheet(BadgeId badgeId) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final badge = BadgeDefinitions.getBadgeById(badgeId);
    if (badge == null) return;

    final isUnlocked = badgeService.isBadgeUnlocked(badgeId);
    final unlockDate = badgeService.getBadgeUnlockDate(badgeId);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Badge icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isUnlocked ? badge.color.withOpacity(0.2) : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                badge.icon,
                size: 50,
                color: isUnlocked ? badge.color : Colors.grey,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Badge name
            Text(
              badge.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Badge description
            Text(
              badge.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            // Unlock status
            if (isUnlocked) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Unlocked ${_formatDate(unlockDate!)}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Not yet unlocked',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==================== KPI UPDATES ====================

  /// Record video (call from your video recording flow)
  Future<void> recordVideo({double? maxSpeed}) async {
    await badgeService.onVideoRecorded(maxSpeed: maxSpeed);
  }

  /// Export video (call from your export flow)
  Future<void> exportVideo() async {
    await badgeService.onVideoExported();
  }

  /// Share video (call from your share flow)
  Future<void> shareVideo() async {
    await badgeService.onVideoShared();
  }

  /// Update max speed (call when detecting new speed)
  Future<void> updateSpeed(double speed) async {
    await badgeService.onSpeedAchieved(speed);
  }

  /// Purchase premium (call from your IAP flow)
  Future<void> purchasePremium() async {
    await badgeService.onPremiumPurchased();
  }

  /// Leaderboard appearance (call when user appears on leaderboard)
  Future<void> leaderboardAppearance({bool isFirstPlace = false}) async {
    await badgeService.onDailyLeaderboardAppearance(isFirstPlace: isFirstPlace);
  }

  // ==================== UTILITY METHODS ====================

  /// Get current stats for display
  Map<String, dynamic> getStats() {
    return badgeService.getStatsSummary();
  }

  /// Get all badges data for UI
  List<Map<String, dynamic>> getAllBadges() {
    return badgeService.getAllBadgesForUI();
  }

  /// Get badges by category
  Map<String, List<Map<String, dynamic>>> getBadgesByCategory() {
    return badgeService.getBadgesByCategory();
  }

  /// Check if badge is unlocked
  bool isBadgeUnlocked(BadgeId badgeId) {
    return badgeService.isBadgeUnlocked(badgeId);
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      return 'on ${date.day}/${date.month}/${date.year}';
    }
  }

  // ==================== CLEANUP ====================

  /// Dispose resources
  void dispose() {
    badgeService.removeListener(_handleBadgeServiceUpdate);
  }
}

/// Badge category enum for filtering
enum BadgeCategory {
  all,
  recording,
  export,
  streak,
  share,
  speed,
  premium,
  leaderboard,
}
