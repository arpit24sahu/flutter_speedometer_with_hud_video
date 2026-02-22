import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/labs/presentation/bloc/labs_service_bloc.dart';
import 'package:speedometer/features/labs/presentation/recorded_tab.dart';
import 'package:speedometer/features/labs/presentation/exported_tab.dart';

import 'package:speedometer/features/premium/widgets/premium_feature_gate.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_banner.dart';
import 'package:speedometer/features/badges/badge_manager.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/presentation/screens/home_screen.dart';


class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen>
    with SingleTickerProviderStateMixin
    implements TabVisibilityAware {
  late final TabController _tabController;
  final GlobalKey _recordedTabKey = GlobalKey();
  final GlobalKey _exportedTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void onTabVisible() {
    // Reload tasks whenever the Labs tab becomes visible
    if (mounted) {
      context.read<LabsServiceBloc>().add(const LoadTasks());
      // _checkTutorial(); // legacy tutorial disabled
    }
  }



  @override
  void onTabInvisible() {
    // Nothing to clean up
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Labs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        actions: [
          if(kDebugMode) PopupMenuButton<String>(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            tooltip: 'Badge Tests',
            onSelected: (value) {
              switch (value) {
                case 'record':
                  _testRecordVideo();
                  break;
                case 'export':
                  _testExportVideo();
                  break;
                case 'share':
                  _testShareVideo();
                  break;
                case 'speed_100':
                  _testSpeed(100);
                  break;
                case 'speed_200':
                  _testSpeed(200);
                  break;
                case 'badges_page':
                  getIt<BadgeManager>().navigateToBadgesPage();
                  break;
                case 'stats_page':
                  getIt<BadgeManager>().navigateToStatsPage();
                  break;
                case 'status_page':
                  getIt<BadgeManager>().showBadgeStatusPage();
                  break;
                case 'reset':
                  getIt<BadgeManager>().badgeService.resetAllData();
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'record',
                  child: Text('Test: Record Video'),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Text('Test: Export Video'),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Text('Test: Share Video'),
                ),
                const PopupMenuItem(
                  value: 'speed_100',
                  child: Text('Test: Hit 100 km/h'),
                ),
                const PopupMenuItem(
                  value: 'speed_200',
                  child: Text('Test: Hit 200 km/h'),
                ),
                const PopupMenuItem(
                  value: 'badges_page',
                  child: Text('Open Badges Page'),
                ),
                const PopupMenuItem(
                  value: 'stats_page',
                  child: Text('Open Stats Page'),
                ),
                const PopupMenuItem(
                  value: 'status_page',
                  child: Text('Open Status Page (New)'),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Text('Reset All Data'),
                ),
              ];
            },
          ),
          
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.white),
            tooltip: 'My Badges',
            onPressed: () {
              getIt<BadgeManager>().showBadgeStatusPage();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          tabs: [
            Tab(
              text: 'Recorded',
              icon: KeyedSubtree(
                key: _recordedTabKey,
                child: const Icon(Icons.videocam, size: 20),
              ),
            ),
            Tab(
              text: 'Exported',
              icon: KeyedSubtree(
                key: _exportedTabKey,
                child: const Icon(Icons.movie_creation, size: 20),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Premium upgrade banner
          PremiumFeatureGate(
            premiumContent: SizedBox.shrink(),
            freeContent: PremiumUpgradeBanner(source: 'labs_screen'),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [RecordedTab(), ExportedTab()],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testRecordVideo() async {
    final badgeManager = getIt<BadgeManager>();
    // Simulate recording a video with random speed
    await badgeManager.recordVideo(maxSpeed: 85.0);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test: Video Recorded (Max Speed: 85.0)')),
      );
    }
  }

  Future<void> _testExportVideo() async {
    final badgeManager = getIt<BadgeManager>();
    await badgeManager.exportVideo();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test: Video Exported')));
    }
  }

  Future<void> _testShareVideo() async {
    final badgeManager = getIt<BadgeManager>();
    await badgeManager.shareVideo();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test: Video Shared')));
    }
  }

  Future<void> _testSpeed(double speed) async {
    final badgeManager = getIt<BadgeManager>();
    await badgeManager.updateSpeed(speed);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Test: Speed Hit ($speed km/h)')));
    }
  }
}
