# TurboGauge Badge System

A comprehensive gamification system for the TurboGauge app with badge achievements, KPI tracking, and progress monitoring.

## Features

- ✅ 25+ predefined badges across multiple categories
- ✅ Automatic badge unlock detection
- ✅ Progress tracking for each badge
- ✅ Streak calculation (consecutive recording days)
- ✅ Speed milestone tracking
- ✅ JSON-based Hive storage (no custom adapters needed)
- ✅ ChangeNotifier integration for UI updates
- ✅ Awesome Notifications support for badge unlocks
- ✅ Separation of concerns with clean architecture

## Files Structure

```
badge_system/
├── badge_id.dart              # Enum for all badge IDs
├── badge_model.dart           # Badge data model
├── badge_definitions.dart     # All badge definitions & categories
├── badge_kpi_data.dart        # User KPI/stats data model
├── badge_service.dart         # Main service with all logic
└── example_usage.dart         # Integration examples
```

## Installation

1. Add dependencies to `pubspec.yaml`:

```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  awesome_notifications: ^0.9.3+1
```

2. Initialize in your `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize badge service
  final badgeService = BadgeService();
  await badgeService.initialize();
  
  runApp(MyApp(badgeService: badgeService));
}
```

## Badge Categories

### Recording Badges
- **First Ride** - Record your first video
- **Video Enthusiast** - Record 20 videos
- **Video Master** - Record 50 videos

### Export Badges
- **First Export** - Export your first video
- **Export Pro** - Export 20 videos
- **Export Legend** - Export 50 videos

### Streak Badges
- **Consistent** - Record videos 3 days in a row
- **Dedicated** - Record videos 10 days in a row
- **Unstoppable** - Record videos 25 days in a row

### Share Badges
- **Social Starter** - Share your first video
- **Influencer** - Share 10 videos
- **Content Creator** - Share 25 videos

### Speed Badges
- **Speed Rookie** - Hit 50 km/h
- **Cruiser** - Hit 80 km/h
- **Century** - Hit 100 km/h
- **Fast & Furious** - Hit 120 km/h
- **Speed Demon** - Hit 150 km/h
- **Adrenaline Junkie** - Hit 200 km/h
- **Supersonic** - Hit 250 km/h
- **Jet Speed** - Hit 500 km/h
- **Hypersonic** - Hit 800 km/h
- **Breaking Sound** - Hit 1000 km/h

### Premium Badge
- **Premium Member** - Purchased premium subscription

### Leaderboard Badges (Future)
- **On the Board** - Appear on daily leaderboard once
- **Regular Contender** - Appear on daily leaderboard 10 times
- **Champion** - Rank 1st on daily leaderboard once
- **Legend** - Rank 1st on daily leaderboard 10 times

## Usage

### Initialize Service

```dart
final badgeService = BadgeService();
await badgeService.initialize();
```

### Update KPIs (Call these from your app)

```dart
// When user records a video
await badgeService.onVideoRecorded(maxSpeed: 120.5);

// When user exports a video
await badgeService.onVideoExported();

// When user shares a video
await badgeService.onVideoShared();

// When user hits a new speed
await badgeService.onSpeedAchieved(150.0);

// When user purchases premium
await badgeService.onPremiumPurchased();

// When user appears on leaderboard
await badgeService.onDailyLeaderboardAppearance(isFirstPlace: true);
```

### Listen to Badge Unlocks

```dart
badgeService.addListener(() {
  final newBadges = badgeService.newlyUnlockedBadges;
  
  for (final badgeId in newBadges) {
    // Show notification or UI celebration
    showBadgeUnlockedDialog(badgeId);
  }
  
  // Clear the list after handling
  badgeService.clearNewlyUnlockedBadges();
});
```

### Get Data for UI

```dart
// Get all badges with unlock status and progress
final allBadges = badgeService.getAllBadgesForUI();

// Get badges grouped by category
final categorizedBadges = badgeService.getBadgesByCategory();

// Get stats summary
final stats = badgeService.getStatsSummary();
// Returns: {
//   totalBadges: 25,
//   unlockedBadges: 8,
//   progress: 0.32,
//   videosRecorded: 15,
//   currentStreak: 5,
//   maxSpeedAchieved: 120.0,
//   ...
// }

// Get recently unlocked badges (last 7 days)
final recentBadges = badgeService.getRecentlyUnlockedBadges(days: 7);
```

### Check Specific Badge

```dart
// Check if a badge is unlocked
bool isUnlocked = badgeService.isBadgeUnlocked(BadgeId.firstVideo);

// Get unlock date
DateTime? unlockDate = badgeService.getBadgeUnlockDate(BadgeId.speed100Kmph);
```

## Data Structure

### Badge JSON Format
```json
{
  "id": "firstVideo",
  "name": "First Ride",
  "description": "Record your first video",
  "icon": 57415,
  "imageUrl": null,
  "color": 4283215696,
  "tier": 1,
  "level": 1,
  "attainabilityScore": 1
}
```

### Badge Achievement JSON (Stored in Hive)
```json
{
  "firstVideo": "2024-02-17T10:30:00.000Z",
  "record20Videos": null,
  "speed100Kmph": "2024-02-15T14:20:00.000Z"
}
```

### KPI Data JSON (Stored in Hive)
```json
{
  "videosRecorded": 25,
  "videosExported": 18,
  "videosShared": 10,
  "currentStreak": 5,
  "longestStreak": 12,
  "lastRecordingDate": "2024-02-17T00:00:00.000Z",
  "maxSpeedAchieved": 145.5,
  "isPremiumUser": true,
  "dailyLeaderboardAppearances": 3,
  "dailyLeaderboardFirstPlaces": 1,
  "recordingDates": ["2024-02-13", "2024-02-14", "2024-02-15"]
}
```

## Awesome Notifications Integration

```dart
// Initialize notifications
await AwesomeNotifications().initialize(
  null,
  [
    NotificationChannel(
      channelKey: 'badge_channel',
      channelName: 'Badge Notifications',
      channelDescription: 'Notifications for unlocked badges',
      defaultColor: Colors.amber,
      importance: NotificationImportance.High,
    ),
  ],
);

// Show notification when badge unlocked
void showBadgeNotification(BadgeId badgeId) {
  final badge = BadgeDefinitions.getBadgeById(badgeId);
  
  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: badgeId.index,
      channelKey: 'badge_channel',
      title: '🏆 Badge Unlocked!',
      body: '${badge.name}: ${badge.description}',
      color: badge.color,
    ),
  );
}
```

## Advanced Features

### Custom Badge Images

You can use custom images instead of icons:

```dart
Badge(
  id: BadgeId.customBadge,
  name: 'Custom Badge',
  description: 'A badge with custom image',
  imageUrl: 'https://example.com/badge.png', // Will use CachedNetworkImage
  icon: null,
  color: Colors.blue,
  tier: 1,
  level: 1,
  attainabilityScore: 10,
)
```

### Progress Calculation

The service automatically calculates progress for each badge:
- Recording badges: videos recorded / target
- Speed badges: current max speed / target speed
- Streak badges: longest streak / target streak
- Boolean badges (premium): 0.0 or 1.0

### Recheck All Badges

Useful for debugging or data migration:

```dart
await badgeService.recheckAllBadges();
```

### Reset All Data

For testing or user request:

```dart
await badgeService.resetAllData();
```

## Architecture

The badge system follows clean architecture principles:

1. **badge_id.dart** - Enums for type safety
2. **badge_model.dart** - Data models
3. **badge_definitions.dart** - Static badge definitions (easy to modify)
4. **badge_kpi_data.dart** - User statistics model
5. **badge_service.dart** - Business logic and data persistence

All data is stored in Hive as JSON strings, no custom adapters needed. The service uses ChangeNotifier for reactive UI updates.

## Adding New Badges

1. Add new enum to `BadgeId` in `badge_id.dart`
2. Add badge definition to `BadgeDefinitions.allBadges` in `badge_definitions.dart`
3. Add unlock logic to `_checkAndUnlockBadges()` in `badge_service.dart`
4. Add progress calculation to `_calculateProgress()` in `badge_service.dart`
5. Add KPI field if needed to `BadgeKpiData` in `badge_kpi_data.dart`

## Notes

- Badges are attainable only once
- Streak is calculated based on consecutive days with recordings
- All dates are stored in UTC
- Badge attainabilityScore determines display order (lower = easier)
- Service must be initialized before use
- Use `notifyListeners()` to trigger UI updates

## Example Integration in Your App

See `example_usage.dart` for complete integration examples including:
- Main app setup
- Notification handling
- UI widgets
- State management integration
