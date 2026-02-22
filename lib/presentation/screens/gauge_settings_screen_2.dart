import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/labs/presentation/bloc/gauge_customization_bloc.dart';
import 'package:speedometer/features/premium/widgets/premium_feature_gate.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog_2.dart';
import '../../features/labs/models/gauge_customization.dart';
import '../../presentation/widgets/color_picker_bottom_sheet.dart';
import '../../presentation/widgets/gauge_needle_selector_widget.dart';
import '../bloc/settings/settings_bloc.dart';
import '../bloc/settings/settings_event.dart';
import '../bloc/settings/settings_state.dart';

class GaugeSettingsScreen2 extends StatelessWidget {
  const GaugeSettingsScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GaugeCustomizationBloc, GaugeCustomizationState>(
      builder: (context, gaugeState) {
        final config = gaugeState.customization;
        final sizeFactor = config.sizeFactor ?? 1;
        final placement = config.placement ?? GaugePlacement.topRight;
        final textColor = config.textColor ?? Colors.white;

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Gauge & Needle Selector ───
              _buildSectionTitle('Gauge Style'),
              const GaugeNeedleSelectorWidget(),

              const Divider(height: 32),

              // ─── Size Factor ───
              _buildSectionTitle('Gauge Size'),
              _buildSliderTile(
                title: 'Size Factor',
                value: sizeFactor.toDouble(),
                min: 0.15,
                max: 0.50,
                divisions: 7,
                label: '${((sizeFactor) * 100).toStringAsFixed(0)}%',
                onChanged: (value) {
                  context.read<GaugeCustomizationBloc>().add(
                    ChangeGaugeSizeFactor(value),
                  );
                },
              ),

              const Divider(height: 32),

              // ─── Placement ───
              _buildSectionTitle('Placement'),
              _buildOptionTile(
                icon: placement.icon,
                title: placement.displayName,
                subtitle: 'Tap to change position',
                trailing: const Icon(Icons.grid_3x3, color: Colors.white54),
                onTap: () => _showPlacementPicker(context, config),
              ),

              const Divider(height: 32),

              // ─── Text Color ───
              _buildSectionTitle('Text Color'),
              _buildColorTile(
                context,
                title: 'Text Color',
                color: textColor,
                onTap: () => _showTextColorPicker(context, textColor),
              ),

              const Divider(height: 32),

              // ─── Visibility ───
              _buildSectionTitle('Visibility'),
              _buildOptionTile(
                icon: Icons.speed,
                title: 'Show Speed',
                subtitle:
                    (config.showSpeed ?? true)
                        ? 'Speed text visible'
                        : 'Speed text hidden',
                trailing: Switch(
                  value: config.showSpeed ?? true,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) {
                    context.read<GaugeCustomizationBloc>().add(
                      ToggleShowSpeed(val),
                    );
                  },
                ),
                onTap: () {
                  context.read<GaugeCustomizationBloc>().add(
                    ToggleShowSpeed(!(config.showSpeed ?? true)),
                  );
                },
              ),
              const SizedBox(height: 8),
              PremiumFeatureGate(
                freeContent: _buildOptionTile(
                  icon: Icons.branding_watermark,
                  title: 'Hide Watermark 👑',
                  subtitle:
                  (config.showBranding ?? true)
                      ? 'TurboGauge watermark visible'
                      : 'No watermark',
                  trailing: Switch(
                    value: !(config.showBranding ?? true),
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                      PremiumUpgradeDialog2.show(context, source: "GaugeSettings");
                    },
                  ),
                  onTap: () {
                    PremiumUpgradeDialog2.show(context, source: "GaugeSettings");
                  },
                ),
              premiumContent: _buildOptionTile(
                icon: Icons.branding_watermark,
                title: 'Hide Watermark 👑',
                subtitle:
                    (config.showBranding ?? true)
                        ? 'TurboGauge watermark visible'
                        : 'No watermark',
                trailing: Switch(
                  value: !(config.showBranding ?? true),
                  activeColor: Colors.blueAccent,
                  onChanged: (val) {
                    context.read<GaugeCustomizationBloc>().add(
                      ToggleShowBranding(),
                    );
                  },
                ),
                onTap: () {
                  context.read<GaugeCustomizationBloc>().add(
                    ToggleShowBranding(),
                  );
                },
              ),),

              const Divider(height: 32),

              _buildSectionTitle('Units'),
              _buildOptionTile(
                icon: Icons.straighten,
                title: 'Unit System',
                subtitle:
                gaugeState.customization.isMetric == true
                    ? 'Metric (km/h)'
                    : 'Imperial (mph)',
                trailing: Switch(
                  value: gaugeState.customization.isMetric ?? true,
                  activeColor: Colors.blueAccent,
                  onChanged: (_) {
                    context.read<GaugeCustomizationBloc>().add(ToggleGaugeUnits());
                  },
                ),
                onTap: () {
                  context.read<GaugeCustomizationBloc>().add(ToggleGaugeUnits());
                },
              ),

              const Divider(height: 32),

              // ─── Unit System ───
              if(false) _buildSectionTitle('Units'),
              if(false) BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, settingsState) {
                  return _buildOptionTile(
                    icon: Icons.straighten,
                    title: 'Unit System',
                    subtitle:
                        settingsState.isMetric
                            ? 'Metric (km/h)'
                            : 'Imperial (mph)',
                    trailing: Switch(
                      value: settingsState.isMetric,
                      activeColor: Colors.blueAccent,
                      onChanged: (_) {
                        context.read<SettingsBloc>().add(ToggleUnitSystem());
                      },
                    ),
                    onTap: () {
                      context.read<SettingsBloc>().add(ToggleUnitSystem());
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Placement Picker Dialog ───

  void _showPlacementPicker(BuildContext context, GaugeCustomization config) {
    final currentPlacement = config.placement ?? GaugePlacement.topRight;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Gauge Placement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: GaugePlacement.values.length,
                  itemBuilder: (ctx, index) {
                    final placement = GaugePlacement.values[index];
                    final isSelected = placement == currentPlacement;
                    return GestureDetector(
                      onTap: () {
                        context.read<GaugeCustomizationBloc>().add(
                          ChangeGaugePlacement(placement),
                        );
                        Navigator.pop(sheetContext);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Colors.blueAccent
                                    : Colors.grey[700]!,
                            width: isSelected ? 2 : 1,
                          ),
                          color:
                              isSelected
                                  ? Colors.blueAccent.withValues(alpha: 0.15)
                                  : Colors.grey[850],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              placement.icon,
                              color:
                                  isSelected
                                      ? Colors.blueAccent
                                      : Colors.white54,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              placement.displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.blueAccent
                                        : Colors.white70,
                                fontSize: 10,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showTextColorPicker(BuildContext context, Color currentColor) {
    showColorPickerBottomSheet(
      context: context,
      currentColor: currentColor,
      title: 'Select Text Color',
      onColorSelected: (color) {
        context.read<GaugeCustomizationBloc>().add(ChangeTextColor(color));
      },
    );
  }

  // ─── Helpers ───

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
    int? divisions,
    String? label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Row(
            children: [
              Text(title),
              const Spacer(),
              Text(
                label ?? value.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 16),
            Text(min.toStringAsFixed(0)),
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: label ?? value.toStringAsFixed(1),
                activeColor: Colors.blueAccent,
                onChanged: onChanged,
              ),
            ),
            Text(max.toStringAsFixed(0)),
            const SizedBox(width: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.blueAccent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorTile(
    BuildContext context, {
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.color_lens,
                  color: Colors.blueAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
