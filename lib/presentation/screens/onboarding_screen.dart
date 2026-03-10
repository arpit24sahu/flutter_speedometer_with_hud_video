import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/presentation/screens/home_screen.dart';
import 'package:speedometer/services/permission_service.dart';
import 'package:speedometer/services/remote_config_service.dart';

import 'home_screen_2.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late DateTime _startTime;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Capture the Action',
      'tagline': 'Record thrilling videos with a real-time speedometer overlay directly on your camera.',
      'color': Colors.blueAccent,
      'image': 'assets/images/0.png', // Placeholder for your portrait GIF
      // 'image': 'assets/gifs/0.gif', // Placeholder for your portrait GIF
    },
    {
      'title': 'Precision Speedometer',
      'tagline': 'As accurate as your phone can get! Glide smoothly with precise GPS speed readings.',
      'color': Colors.green,
      'image': 'assets/images/1.png', // Placeholder for your portrait GIF
      // 'image': 'assets/gifs/1.gif', // Placeholder for your portrait GIF
    },
    {
      'title': 'Background Dashcam',
      'tagline': 'Secure your journey. Record road events and speed data seamlessly, even while using other apps.',
      'color': Colors.indigoAccent,
      'image': 'assets/images/2.png', // Placeholder for your portrait GIF
      // 'image': 'assets/gifs/2.gif', // Placeholder for your portrait GIF
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to home screen or complete onboarding
      completeOnboarding(false); // Replace with your route
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // void _skipOnboarding()async{
  //   // Navigate to home screen or complete onboarding
  //   SharedPreferences preferences = await SharedPreferences.getInstance();
  //   await preferences.setBool('skipOnboarding', true);
  //   Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen())); // Replace with your route
  // }

  Future<void> completeOnboarding(bool skipped)async{
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool('skipOnboarding', true);

    AnalyticsService().trackEvent(AnalyticsEvents.onboardingCompleted, properties: {
      "skipped": skipped,
      "time_spent": DateTime.now().difference(_startTime).inSeconds,
      "current_page": _currentPage,
    });

    setState(() {

    });
  }
  
  Future<bool> shouldSkipOnboarding()async{
    SharedPreferences preferences = await SharedPreferences.getInstance();
    print("Would have skipped onboarding: ${(preferences.getBool('skipOnboarding'))}");
    // if(kDebugMode) return false;
    return (preferences.getBool('skipOnboarding')==true);
    if((preferences.getBool('skipOnboarding'))==true){
      // _skipOnboarding();
    }
  }
  
  @override
  void initState() {
    super.initState();
    shouldSkipOnboarding();
    _startTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<bool>(
      future: shouldSkipOnboarding(),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot){
        if (!snapshot.hasData) return const CircularProgressIndicator();
        if (snapshot.data == true) {
          final layout = RemoteConfigService().getString(
            RemoteConfigService.keyHomepageLayout,
          );
          return PermissionsGate(
            child: layout == 'tabs' ? const HomeScreen() : HomeScreen2(),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(
                    title: _pages[index]['title'],
                    tagline: _pages[index]['tagline'],
                    color: _pages[index]['color'],
                    image: _pages[index]['image'],
                  );
                },
              ),
              Positioned(
                top: 40,
                right: 20,
                child: TextButton(
                  onPressed: () async => await completeOnboarding(true),
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                        (index) => _buildDot(index == _currentPage),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: _currentPage > 0
                    ? TextButton(
                  onPressed: _previousPage,
                  child: const Text(
                    'Previous',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                )
                    : const SizedBox.shrink(),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: TextButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Continue',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );


  }

  Widget _buildPage({
    required String title,
    required String tagline,
    required Color color,
    required String image,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.8), color],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Portrait GIF/Image placeholder (assume 16:9 or adjust ratio as needed)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                image,
                height: MediaQuery.of(context).size.height * 0.5,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              tagline,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white54,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}