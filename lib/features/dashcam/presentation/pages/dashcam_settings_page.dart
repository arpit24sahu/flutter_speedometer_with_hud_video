import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../bloc/dashcam_bloc.dart';
import '../../../../core/analytics/analytics_tracker.dart';
import '../../../../core/analytics/analytics_events.dart';

class DashcamSettingsPage extends StatefulWidget {
  const DashcamSettingsPage({super.key});

  @override
  State<DashcamSettingsPage> createState() => _DashcamSettingsPageState();
}

class _DashcamSettingsPageState extends State<DashcamSettingsPage> {
  late final DashcamBloc _bloc;
  double? _tempStorageLimitGb;
  double? _tempLoopIntervalSecs;
  double? _tempSpeedLimit;

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.instance<DashcamBloc>();
    // Fetch initial settings and storage space when opened directly
    _bloc.add(LoadDashcamSettings());
    AnalyticsTracker().trackScreen(screenName: 'DashcamSettings', screenClass: 'DashcamSettingsPage');
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: false,
        titleSpacing: 8,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
             if (Navigator.canPop(context))
               Padding(
                 padding: const EdgeInsets.only(right: 8),
                 child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    shape: const CircleBorder(), 
                  ),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded, 
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                 ),
               ),
             Text(
              'Dashcam Settings',
              style: TextStyle(fontFamily: 'Outfit',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      body: BlocBuilder<DashcamBloc, DashcamState>(
        bloc: _bloc,
        builder: (context, state) {
          final sliderValue = _tempStorageLimitGb ?? state.maxStorageGb.toDouble();
          debugPrint('[DashcamSettingsPage] UI Build -> state.maxStorageGb: ${state.maxStorageGb}, sliderValue: $sliderValue, tempStorage: $_tempStorageLimitGb');
          debugPrint('[DashcamSettingsPage] UI Build -> state.segmentDurationSeconds: ${state.segmentDurationSeconds}, tempLoop: $_tempLoopIntervalSecs');
          debugPrint('[DashcamSettingsPage] UI Build -> state.remainingStorageGb: ${state.remainingStorageGb}');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Storage Limit
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                color: isDark ? const Color(0xFF343a40) : const Color(0xFFe9ecef),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Storage Limit', style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
'Maximum storage for dashcam recordings',
style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
),
                      const SizedBox(height: 16),
                      
                      // Free Space Indicator
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.sd_storage_rounded, 
                                 color: theme.colorScheme.primary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Global Device Free Space',
                                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${(state.remainingStorageGb).toDouble().toStringAsFixed(1)} GB Available',
                                    style: TextStyle(fontFamily: 'Outfit',
                                      fontSize: 16,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        children: [
                          const Text('1 GB', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14)),
                          Expanded(
                            child: Slider(
                              value: (sliderValue).toDouble().clamp(1.0, 30.0),
                              min: 1.0,
                              max: 30.0,
                              divisions: 29,
                              label: '${(sliderValue).toDouble().clamp(1.0, 30.0).round()} GB',
                              onChanged: (val) {
                                setState(() {
                                  _tempStorageLimitGb = val;
                                });
                              },
                              onChangeEnd: (val) {
                                _bloc.add(UpdateStorageLimit(val.round()));
                                AnalyticsTracker().log(AnalyticsEvents.dashcam_settings_updated, params: {
                                  'setting_name': 'max_storage_gb',
                                  'setting_value': val.round().toString(),
                                });
                                setState(() {
                                  _tempStorageLimitGb = null; // Let the state take over
                                });
                              },
                            ),
                          ),
                          const Text('30 GB', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14)),
                        ],
                      ),
                      Center(
                        child: Text(
                          'Limit: ${(sliderValue).toDouble().round()} GB',
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 24, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Video Quality
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                color: isDark ? const Color(0xFF343a40) : const Color(0xFFe9ecef),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Video Quality', style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
'Resolution for dashcam recordings',
style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: '720p',
                            label: Text('720p', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14)),
                          ),
                          ButtonSegment<String>(
                            value: '1080p',
                            label: Text('1080p', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14)),
                          ),
                          ButtonSegment<String>(
                            value: '4K',
                            label: Text('4K', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14)),
                          ),
                        ],
                        selected: <String>{state.videoQuality},
                        onSelectionChanged: (Set<String> newSelection) {
                          _bloc.add(UpdateVideoQuality(newSelection.first));
                          AnalyticsTracker().log(AnalyticsEvents.dashcam_settings_updated, params: {
                            'setting_name': 'video_quality',
                            'setting_value': newSelection.first,
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Frame Rate
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                color: isDark ? const Color(0xFF343a40) : const Color(0xFFe9ecef),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Frame Rate', style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'FPS for dashcam recordings',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: state.frameRate,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: const [
                              DropdownMenuItem(
                                value: 60,
                                child: Text('60 fps', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16)),
                              ),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 fps', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16)),
                              ),
                            ],
                            onChanged: (int? newValue) {
                              if (newValue != null) {
                                _bloc.add(UpdateFrameRate(newValue));
                                AnalyticsTracker().log(AnalyticsEvents.dashcam_settings_updated, params: {
                                  'setting_name': 'frame_rate',
                                  'setting_value': newValue.toString(),
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Loop Interval
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                color: isDark ? const Color(0xFF343a40) : const Color(0xFFe9ecef),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loop Interval', style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
'Length of each video segment before a new one starts',
style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('1m', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14)),
                          Expanded(
                            child: Slider(
                              value: ((_tempLoopIntervalSecs ?? state.segmentDurationSeconds.toDouble()) / 60.0).clamp(1.0, 3.0),
                              min: 1.0,
                              max: 3.0,
                              divisions: 2,
                              label: '${(((_tempLoopIntervalSecs ?? state.segmentDurationSeconds.toDouble()) / 60.0).clamp(1.0, 3.0)).round()} min',
                              onChanged: (val) {
                                setState(() {
                                  _tempLoopIntervalSecs = val * 60.0;
                                });
                              },
                              onChangeEnd: (val) {
                                _bloc.add(UpdateSegmentDuration((val * 60.0).round()));
                                AnalyticsTracker().log(AnalyticsEvents.dashcam_settings_updated, params: {
                                  'setting_name': 'segment_duration_seconds',
                                  'setting_value': (val * 60.0).round().toString(),
                                });
                                setState(() {
                                  _tempLoopIntervalSecs = null;
                                });
                              },
                            ),
                          ),
                          const Text('3m', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14)),
                        ],
                      ),
                      Center(
                        child: Text(
                          'Interval: ${((_tempLoopIntervalSecs ?? state.segmentDurationSeconds.toDouble()) / 60.0).round()} min',
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 24, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // G-Sensor Seting
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                color: isDark ? const Color(0xFF343a40) : const Color(0xFFe9ecef),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('G-Sensor Collision Detection', style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(
'Auto-lock video and alert upon heavy impact',
style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
),
                          ],
                        ),
                      ),
                      Switch(
                        value: state.enableGShock,
                        onChanged: (val) {
                          _bloc.add(ToggleGShockSetting(val));
                          AnalyticsTracker().log(AnalyticsEvents.dashcam_settings_updated, params: {
                            'setting_name': 'g_shock_setting',
                            'setting_value': val.toString(),
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Speed Limit
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                color: isDark ? const Color(0xFF343a40) : const Color(0xFFe9ecef),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Speed Limit Alert', style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
'Alert when speed exceeds the limit (0 to disable)',
style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Off', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14)),
                          Expanded(
                            child: Slider(
                              value: (_tempSpeedLimit ?? state.speedLimit.toDouble()).clamp(0.0, 160.0),
                              min: 0.0,
                              max: 160.0,
                              divisions: 32, // Step by 5
                              label: (_tempSpeedLimit ?? state.speedLimit.toDouble()) == 0 
                                  ? 'Off' 
                                  : '${(_tempSpeedLimit ?? state.speedLimit.toDouble()).round()} ${state.speedUnit}',
                              onChanged: (val) {
                                setState(() {
                                  _tempSpeedLimit = val;
                                });
                              },
                              onChangeEnd: (val) {
                                _bloc.add(UpdateSpeedLimit(val.round()));
                                AnalyticsTracker().log(AnalyticsEvents.dashcam_settings_updated, params: {
                                  'setting_name': 'speed_limit',
                                  'setting_value': val.round().toString(),
                                });
                                setState(() {
                                  _tempSpeedLimit = null;
                                });
                              },
                            ),
                          ),
                          Text('160 ${state.speedUnit}', style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14)),
                        ],
                      ),
                      Center(
                        child: Text(
                          (_tempSpeedLimit ?? state.speedLimit.toDouble()) == 0 
                              ? 'Alert: Off' 
                              : 'Limit: ${(_tempSpeedLimit ?? state.speedLimit.toDouble()).round()} ${state.speedUnit}',
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 24, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            ],
          );
        },
      ),
    );
  }
}
