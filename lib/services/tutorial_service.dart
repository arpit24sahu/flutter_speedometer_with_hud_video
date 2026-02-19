import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  // Private constructor
  TutorialService._internal();

  // Singleton instance
  static final TutorialService _instance = TutorialService._internal();

  // Factory constructor
  factory TutorialService() => _instance;

  static const String _keyHomeShown = 'tutorial_home_shown';
  static const String _keyCameraShown = 'tutorial_camera_shown';
  static const String _keyLabsShown = 'tutorial_labs_shown';

  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // Checkers
  bool get isHomeTutorialShown => _prefs?.getBool(_keyHomeShown) ?? false;
  bool get isCameraTutorialShown => _prefs?.getBool(_keyCameraShown) ?? false;
  bool get isLabsTutorialShown => _prefs?.getBool(_keyLabsShown) ?? false;

  // Logic to determine if we should show specific tutorials
  // The rule is: Home must complete first.
  
  bool get shouldShowHomeTutorial => !isHomeTutorialShown;
  
  bool get shouldShowCameraTutorial {
    // Only show camera tutorial if home is done AND camera not done
    return isHomeTutorialShown && !isCameraTutorialShown;
  }

  bool get shouldShowLabsTutorial {
    // Only show labs tutorial if home is done AND labs not done
    return isHomeTutorialShown && !isLabsTutorialShown;
  }

  // Setters
  Future<void> setHomeShown() async {
    await _prefs?.setBool(_keyHomeShown, true);
  }

  Future<void> setCameraShown() async {
    await _prefs?.setBool(_keyCameraShown, true);
  }

  Future<void> setLabsShown() async {
    await _prefs?.setBool(_keyLabsShown, true);
  }
  
  // Debug/Reset for testing
  Future<void> resetAll() async {
    await _prefs?.remove(_keyHomeShown);
    await _prefs?.remove(_keyCameraShown);
    await _prefs?.remove(_keyLabsShown);
  }
}
