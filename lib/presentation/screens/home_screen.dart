import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/files/bloc/files_bloc.dart';
import 'package:speedometer/features/files/files_screen.dart';
import 'package:speedometer/features/processing/bloc/jobs_bloc.dart';
import 'package:speedometer/features/processing/bloc/processor_bloc.dart';
import 'package:speedometer/features/processing/models/processing_queue.dart';
import 'package:speedometer/features/processing/presentation/jobs_screen.dart';
import 'package:speedometer/presentation/screens/camera_screen.dart';
import 'package:speedometer/presentation/screens/speedometer_screen.dart';
import 'package:speedometer/services/hive_service.dart';
import 'package:speedometer/services/permission_service.dart';

import '../widgets/global_processing_indicator.dart';

abstract class TabVisibilityAware {
  void onTabVisible();
  void onTabInvisible();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<GlobalKey> _screenKeys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];

  List<Widget> _screens() => [
    PermissionsGate(child: CameraScreen(key: _screenKeys[0])),
    SpeedometerScreen(key: _screenKeys[1],),
    FilesScreen(key: _screenKeys[2],),
    // const SettingsScreen(),
    JobsScreen(key: _screenKeys[3]),
  ];

  String screenName(int index){
    switch(index) {
      case 0: return 'Camera';
      case 1: return 'Speedometer';
      case 2: return 'Files';
      // case 3: return 'Settings';
      case 3: return 'Jobs';
      default: return 'Camera';
    }
  }

  void _onItemTapped(int index) {
    if(_selectedIndex == index) return;

    AnalyticsService().trackEvent(
        AnalyticsEvents.tabPress,
        properties: {
          "tab": screenName(index),
          "tabIndex": index,
          "previousTab": screenName(_selectedIndex),
          "previousTabIndex": screenName(_selectedIndex)
        }
    );
    _notifyInvisible(_selectedIndex);
    _notifyVisible(index);

    setState(() {
      _selectedIndex = index;
    });

    if(_selectedIndex == 2) {
      context.read<FilesBloc>().add(RefreshFiles());
    }
  }

  void _startProcessQueue(){
    Future.delayed(Duration(milliseconds: 2000), (){
      if(mounted) {
        ProcessingQueue.init(context.read<ProcessorBloc>(), HiveService().pendingBox).start();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startProcessQueue();
    // Create screen keys to access their state
  }

  void _notifyVisible(int index) {
    if (index < 0 || index >= _screenKeys.length) return;

    final state = _screenKeys[index].currentState;
    if (state is TabVisibilityAware) {
      (state as TabVisibilityAware).onTabVisible();
    }
  }

  void _notifyInvisible(int index) {
    if (index < 0 || index >= _screenKeys.length) return;

    final state = _screenKeys[index].currentState;
    if (state is TabVisibilityAware) {
      (state as TabVisibilityAware).onTabInvisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProcessorBloc, ProcessorState>(
      listener: (BuildContext context, ProcessorState state){
        if(state.status == ProcessorStatus.idle){
          print("Processor found idle: Starting Job");
          context.read<ProcessorBloc>().add(StartProcessing());
          Future.delayed(Duration(milliseconds: 1000), (){
            if(context.mounted) context.read<FilesBloc>().add(RefreshFiles());
            if(context.mounted) context.read<JobsBloc>().add(LoadJobs());
          });
        }
      },
      listenWhen: (ProcessorState stateBefore, ProcessorState stateAfter){
        if(stateBefore.status != ProcessorStatus.idle && stateAfter.status == ProcessorStatus.idle){
          return true;
        }
         return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: IndexedStack(index: _selectedIndex, children: _screens())),
            Positioned(
                top: 100,
                left: 20,
                // width: 100,
                // height: 50,
                child: GlobalProcessingIndicator()
            )
          ],
        ),
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
            // BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            BottomNavigationBarItem(icon: Icon(Icons.work_history), label: 'Jobs'),
          ],
        ),
      ),
    );
  }
}
