import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'badge_manager.dart';

/// Example main.dart showing complete integration of BadgeManager
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Run app
  runApp(const TurboGaugeApp());
}

class TurboGaugeApp extends StatefulWidget {
  const TurboGaugeApp({Key? key}) : super(key: key);

  @override
  State<TurboGaugeApp> createState() => _TurboGaugeAppState();
}

class _TurboGaugeAppState extends State<TurboGaugeApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  BadgeManager? badgeManager;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeBadgeManager();
  }

  Future<void> _initializeBadgeManager() async {
    badgeManager = await BadgeManager.initialize(
      navigatorKey: navigatorKey,
    );
    setState(() => isInitialized = true);
  }

  @override
  void dispose() {
    badgeManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'TurboGauge',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: HomePage(badgeManager: badgeManager!),
    );
  }
}

/// Example HomePage showing how to use BadgeManager
class HomePage extends StatelessWidget {
  final BadgeManager badgeManager;

  const HomePage({Key? key, required this.badgeManager}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TurboGauge'),
        actions: [
          // Badge button in app bar
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Badges',
            onPressed: () => badgeManager.navigateToBadgesPage(),
          ),
          // Stats button
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Stats',
            onPressed: () => badgeManager.navigateToStatsPage(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats card
          _buildStatsCard(context),
          const SizedBox(height: 24),
          
          const Text(
            'Test Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Example action buttons
          _buildActionCard(
            context,
            icon: Icons.videocam,
            title: 'Record Video',
            subtitle: 'Simulate recording a video',
            color: Colors.blue,
            onTap: () => _onRecordVideo(context),
          ),
          _buildActionCard(
            context,
            icon: Icons.file_download,
            title: 'Export Video',
            subtitle: 'Simulate exporting a video',
            color: Colors.green,
            onTap: () => _onExportVideo(context),
          ),
          _buildActionCard(
            context,
            icon: Icons.share,
            title: 'Share Video',
            subtitle: 'Simulate sharing a video',
            color: Colors.orange,
            onTap: () => _onShareVideo(context),
          ),
          _buildActionCard(
            context,
            icon: Icons.speed,
            title: 'Hit Speed',
            subtitle: 'Simulate hitting a speed milestone',
            color: Colors.red,
            onTap: () => _onHitSpeed(context),
          ),
          _buildActionCard(
            context,
            icon: Icons.workspace_premium,
            title: 'Purchase Premium',
            subtitle: 'Simulate premium purchase',
            color: Colors.amber,
            onTap: () => _onPurchasePremium(context),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'View Options',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // View options
          _buildActionCard(
            context,
            icon: Icons.grid_view,
            title: 'View All Badges',
            subtitle: 'Open badges page',
            color: Colors.purple,
            onTap: () => badgeManager.navigateToBadgesPage(),
          ),
          _buildActionCard(
            context,
            icon: Icons.view_module,
            title: 'View Badges (Bottom Sheet)',
            subtitle: 'Open badges in bottom sheet',
            color: Colors.indigo,
            onTap: () => badgeManager.showBadgesBottomSheet(),
          ),
          _buildActionCard(
            context,
            icon: Icons.bar_chart,
            title: 'View Stats',
            subtitle: 'Open stats page',
            color: Colors.teal,
            onTap: () => badgeManager.navigateToStatsPage(),
          ),
          _buildActionCard(
            context,
            icon: Icons.insights,
            title: 'View Stats (Bottom Sheet)',
            subtitle: 'Open stats in bottom sheet',
            color: Colors.cyan,
            onTap: () => badgeManager.showStatsBottomSheet(),
          ),
          _buildActionCard(
            context,
            icon: Icons.category,
            title: 'View Speed Badges',
            subtitle: 'Show only speed badges',
            color: Colors.deepOrange,
            onTap: () => badgeManager.showBadgesBottomSheet(
              category: BadgeCategory.speed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final stats = badgeManager.getStats();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade400,
              Colors.deepOrange.shade400,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  'Your Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '${stats['unlockedBadges']}/${stats['totalBadges']}',
                  'Badges',
                ),
                _buildStatItem(
                  '${stats['videosRecorded']}',
                  'Videos',
                ),
                _buildStatItem(
                  '${stats['currentStreak']}',
                  'Streak',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  // ========== ACTION HANDLERS ==========

  Future<void> _onRecordVideo(BuildContext context) async {
    // Simulate random speed between 0 and 150 km/h
    final speed = 50 + (100 * (DateTime.now().millisecond / 1000));
    
    await badgeManager.recordVideo(maxSpeed: speed);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video recorded! Max speed: ${speed.toStringAsFixed(1)} km/h'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onExportVideo(BuildContext context) async {
    await badgeManager.exportVideo();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video exported!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onShareVideo(BuildContext context) async {
    await badgeManager.shareVideo();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video shared!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onHitSpeed(BuildContext context) async {
    // Show dialog to select speed
    final speeds = [50, 80, 100, 120, 150, 200, 250, 500, 800, 1000];
    
    final speed = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Speed'),
        children: speeds.map((s) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, s.toDouble()),
            child: Text('$s km/h'),
          );
        }).toList(),
      ),
    );
    
    if (speed != null) {
      await badgeManager.updateSpeed(speed);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hit $speed km/h!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _onPurchasePremium(BuildContext context) async {
    await badgeManager.purchasePremium();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium purchased!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
