// hive_service.dart
import 'package:hive_ce/hive.dart';

class HiveService {
  HiveService._internal();

  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;

  bool _initialized = false;
  bool _initializing = false;

  Future<void> init() async {
    if(_initialized || _initializing) return;
    _initializing = true;
    _initialized = true;
    _initializing = false;
  }
}