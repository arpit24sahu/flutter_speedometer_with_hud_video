import 'package:flutter/material.dart';
import 'package:speedometer/features/labs/presentation/recorded_tab.dart';
import 'package:speedometer/features/labs/presentation/exported_tab.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_banner.dart';

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          tabs: const [
            Tab(text: 'Recorded', icon: Icon(Icons.videocam, size: 20)),
            Tab(text: 'Exported', icon: Icon(Icons.movie_creation, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Premium upgrade banner
          PremiumUpgradeBanner(source: 'labs_screen'),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [RecordedTab(), ExportedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
