import 'package:flutter/material.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/presentation/screens/camera_screen.dart';
import 'package:speedometer/presentation/screens/speedometer_screen.dart';
import 'package:speedometer/presentation/screens/files_screen.dart';
import 'package:speedometer/presentation/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const CameraScreen(),
    const SpeedometerScreen(),
    const FilesScreen(),
    const SettingsScreen(),
  ];

  String screenName(int index){
    switch(index) {
      case 0: return 'Camera';
      case 1: return 'Speedometer';
      case 2: return 'Files';
      case 4: return 'Settings';
      default: return 'Camera';
    }
  }

  void _onItemTapped(int index) {
    AnalyticsService().trackEvent(
        AnalyticsEvents.tabPress,
        properties: {
          "tab": screenName(index),
          "tabIndex": index,
          "previousTab": screenName(_selectedIndex),
          "previousTabIndex": screenName(_selectedIndex)
        }
    );
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Record'),
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Speed'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Files'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
