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
├── badge_id.dart                          # Enum for all badge IDs
├── badge_model.dart                       # Badge data model
├── badge_definitions.dart                 # All badge definitions & categories
├── badge_kpi_data.dart                    # User KPI/stats data model
├── badge_service.dart                     # Core service with all logic
├── badge_manager.dart                     # High-level manager (navigation, notifications, UI)
├── main_example.dart                      # Complete app integration example
└── widgets/
    ├── badges_page.dart                   # Full-screen badges page
    ├── stats_page.dart                    # Full-screen stats page
    ├── badge_card.dart                    # Individual badge card widget
    ├── badge_unlock_dialog.dart           # Animated unlock celebration dialog
    ├── badge_bottom_sheet.dart            # Bottom sheet for badges
    └── badge_category_section.dart        # Category section widget
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

### Initialize BadgeManager (Recommended)

The `BadgeManager` is a high-level wrapper that provides easy navigation, notification handling, and UI presentation.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  BadgeManager? badgeManager;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    badgeManager = await BadgeManager.initialize(
      navigatorKey: navigatorKey,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: HomePage(badgeManager: badgeManager),
    );
  }
}
```

### Alternative: Direct BadgeService Usage

If you prefer direct control without the manager:

```dart
final badgeService = BadgeService();
await badgeService.initialize();
```

### Navigation Methods

```dart
// Navigate to full-screen badges page
await badgeManager.navigateToBadgesPage();

// Navigate to stats page
await badgeManager.navigateToStatsPage();

// Show badges in bottom sheet
await badgeManager.showBadgesBottomSheet();

// Show specific category in bottom sheet
await badgeManager.showBadgesBottomSheet(
  category: BadgeCategory.speed,
);

// Show stats in bottom sheet
await badgeManager.showStatsBottomSheet();

// Show specific badge details
await badgeManager.showBadgeDetailsBottomSheet(BadgeId.speed100Kmph);
```

### Update KPIs (Using BadgeManager)

```dart
// When user records a video
await badgeManager.recordVideo(maxSpeed: 120.5);

// When user exports a video
await badgeManager.exportVideo();

// When user shares a video
await badgeManager.shareVideo();

// When user hits a new speed
await badgeManager.updateSpeed(150.0);

// When user purchases premium
await badgeManager.purchasePremium();

// When user appears on leaderboard
await badgeManager.leaderboardAppearance(isFirstPlace: true);
```

### Update KPIs (Direct BadgeService)

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

### UI Widgets

The system includes comprehensive, production-ready widgets:

#### BadgesPage
Full-screen page with tabs for different badge categories:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => BadgesPage(badgeService: badgeService),
  ),
);
```

Features:
- Tab navigation by category
- Progress card showing overall completion
- Badge cards with unlock status and progress
- Click to view badge details

#### StatsPage
Full-screen page showing statistics and achievements:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => StatsPage(badgeService: badgeService),
  ),
);
```

Features:
- Overall progress visualization
- Activity stats grid (videos, exports, shares, speed)
- Recent achievements list
- Streak tracking with motivational messages

#### BadgeCard
Individual badge display component:
```dart
BadgeCard(
  badgeData: badgeData, // JSON from service
  onTap: () => showDetails(),
  compact: false, // or true for grid view
)
```

Displays:
- Badge icon (unlocked/locked state)
- Name and description
- Progress bar (for locked badges)
- Unlock date (for unlocked badges)
- Tier indicator

#### BadgeUnlockDialog
Animated celebration dialog when badge unlocks:
```dart
showDialog(
  context: context,
  builder: (context) => BadgeUnlockDialog(badge: badge),
);
```

Features:
- Confetti animation
- Icon scale and rotation animation
- Fade-in effects
- Tier and level display

#### BadgeBottomSheet
Bottom sheet for displaying badges:
```dart
showModalBottomSheet(
  context: context,
  builder: (context) => BadgeBottomSheet(
    badgeService: badgeService,
    category: BadgeCategory.speed, // optional filter
  ),
);
```

#### BadgeCategorySection
Section component for grouping badges:
```dart
BadgeCategorySection(
  title: 'Speed Badges',
  icon: Icons.speed,
  color: Colors.red,
  badges: speedBadges,
  onBadgeTap: (badge) => showDetails(badge),
  useGrid: true, // or false for list view
)
```

### Automatic Notifications

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

See `main_example.dart` for a complete working example.

### Quick Integration Steps

1. **Initialize in main.dart:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const MyApp());
}
```

2. **Create BadgeManager:**
```dart
final navigatorKey = GlobalKey<NavigatorState>();
final badgeManager = await BadgeManager.initialize(
  navigatorKey: navigatorKey,
);
```

3. **Add to your app:**
```dart
MaterialApp(
  navigatorKey: navigatorKey,
  home: HomePage(badgeManager: badgeManager),
)
```

4. **Update KPIs from your code:**
```dart
// In your video recording flow
await badgeManager.recordVideo(maxSpeed: currentSpeed);

// In your export flow
await badgeManager.exportVideo();

// In your share flow
await badgeManager.shareVideo();
```

5. **Add navigation buttons:**
```dart
AppBar(
  actions: [
    IconButton(
      icon: Icon(Icons.emoji_events),
      onPressed: () => badgeManager.navigateToBadgesPage(),
    ),
    IconButton(
      icon: Icon(Icons.bar_chart),
      onPressed: () => badgeManager.navigateToStatsPage(),
    ),
  ],
)
```

### Integration Patterns

#### Pattern 1: Full-Screen Pages
```dart
// Add buttons in app bar or drawer
IconButton(
  icon: Icon(Icons.emoji_events),
  onPressed: () => badgeManager.navigateToBadgesPage(),
)
```

#### Pattern 2: Bottom Sheets
```dart
// Show as modal bottom sheet
FloatingActionButton(
  onPressed: () => badgeManager.showBadgesBottomSheet(),
  child: Icon(Icons.emoji_events),
)
```

#### Pattern 3: Category-Specific Views
```dart
// Show only specific category
ElevatedButton(
  onPressed: () => badgeManager.showBadgesBottomSheet(
    category: BadgeCategory.speed,
  ),
  child: Text('View Speed Badges'),
)
```

#### Pattern 4: Dashboard Widget
```dart
// Display stats in your dashboard
Widget buildStatsSummary() {
  final stats = badgeManager.getStats();
  return Card(
    child: Column(
      children: [
        Text('Badges: ${stats['unlockedBadges']}/${stats['totalBadges']}'),
        LinearProgressIndicator(value: stats['progress']),
        Text('Current Streak: ${stats['currentStreak']} days'),
      ],
    ),
  );
}
```

### Real-World Integration Examples

#### In Video Recording Screen:
```dart
class VideoRecordingScreen extends StatelessWidget {
  final BadgeManager badgeManager;
  
  Future<void> onRecordingComplete(double maxSpeed) async {
    // Your existing logic...
    
    // Update badge system
    await badgeManager.recordVideo(maxSpeed: maxSpeed);
    
    // BadgeManager automatically shows notification if badge unlocked
  }
}
```

#### In Export Screen:
```dart
class ExportScreen extends StatelessWidget {
  final BadgeManager badgeManager;
  
  Future<void> onExportComplete() async {
    // Your existing export logic...
    
    // Update badge system
    await badgeManager.exportVideo();
  }
}
```

#### In Settings/Profile Screen:
```dart
ListTile(
  leading: Icon(Icons.emoji_events),
  title: Text('View Badges'),
  subtitle: Text('${stats['unlockedBadges']} of ${stats['totalBadges']} unlocked'),
  onTap: () => badgeManager.navigateToBadgesPage(),
)
```

## Example Integration in Your App (Legacy)

See `example_usage.dart` for complete integration examples including:
- Main app setup
- Notification handling
- UI widgets
- State management integration
