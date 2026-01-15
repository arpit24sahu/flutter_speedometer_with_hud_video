import 'package:speedometer/features/analytics/services/analytics_service.dart';

/// Initializes the analytics feature dependencies.
///
/// This should be called during app initialization, typically from
/// [initializeDependencies] in the main injection container.
Future<void> initAnalyticsFeature() async {
  // Initialize the analytics service (which initializes underlying services)
  await AnalyticsService().initialize();
}
