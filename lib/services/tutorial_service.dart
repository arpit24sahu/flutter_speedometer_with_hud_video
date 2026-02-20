import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  // Private constructor
  TutorialService._internal();

  // Singleton instance
  static final TutorialService _instance = TutorialService._internal();

  // Factory constructor
  factory TutorialService() => _instance;

  static const String _keyWelcomeShown = 'tutorial_welcome_shown';

  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  bool get isWelcomeTutorialShown => _prefs?.getBool(_keyWelcomeShown) ?? false;
  
  bool get shouldShowWelcomeTutorial => !isWelcomeTutorialShown;

  Future<void> setWelcomeShown() async {
    await _prefs?.setBool(_keyWelcomeShown, true);
  }
  
  // Debug/Reset for testing
  Future<void> resetAll() async {
    await _prefs?.remove(_keyWelcomeShown);
  }
}
