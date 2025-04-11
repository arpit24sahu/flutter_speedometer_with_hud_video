import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/overlay_gauge_configuration_bloc.dart';

class GaugeSettingsScreen extends StatelessWidget {
  const GaugeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OverlayGaugeConfigurationBloc, OverlayGaugeConfigurationState>(
      builder: (context, state) {
        return Scaffold(
          // appBar: AppBar(
          //   title: const Text('Gauge Settings'),
          //   actions: [
          //     IconButton(
          //       icon: const Icon(Icons.refresh),
          //       onPressed: () {
          //         context.read<OverlayGaugeConfigurationBloc>().add(ResetToDefaults());
          //       },
          //     ),
          //   ],
          // ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle('Visibility'),
              _buildSettingTile(
                title: 'Show Gauge',
                subtitle: 'Toggle gauge visibility',
                icon: Icons.speed,
                onTap: () {
                  context.read<OverlayGaugeConfigurationBloc>().add(ToggleGaugeVisibility());
                },
                trailing: Switch(
                  value: state.showGauge,
                  onChanged: (_) {
                    context.read<OverlayGaugeConfigurationBloc>().add(ToggleGaugeVisibility());
                  },
                  activeColor: state.gaugeColor,
                ),
              ),
              _buildSettingTile(
                title: 'Show Text',
                subtitle: 'Toggle text visibility',
                icon: Icons.text_fields,
                onTap: () {
                  context.read<OverlayGaugeConfigurationBloc>().add(ToggleTextVisibility());
                },
                trailing: Switch(
                  value: state.showText,
                  onChanged: (_) {
                    context.read<OverlayGaugeConfigurationBloc>().add(ToggleTextVisibility());
                  },
                  activeColor: state.gaugeColor,
                ),
              ),
              _buildSettingTile(
                title: 'Hide Label',
                subtitle: 'Hide TurboGauge Label',
                icon: Icons.text_fields,
                onTap: () {
                  context.read<OverlayGaugeConfigurationBloc>().add(ToggleLabelVisibility());
                },
                trailing: Switch(
                  value: !state.showLabel,
                  onChanged: (_) {
                    context.read<OverlayGaugeConfigurationBloc>().add(ToggleLabelVisibility());
                  },
                  activeColor: state.gaugeColor,
                ),
              ),

              const Divider(),
              _buildSectionTitle('Placement & Size'),
              _buildSettingTile(
                title: 'Gauge Placement',
                subtitle: state.gaugePlacement.displayName,
                icon: Icons.place,
                onTap: () {
                  _showPlacementPicker(context, state.gaugePlacement);
                },
              ),
              _buildSliderTile(
                title: 'Gauge Size',
                value: state.gaugeRelativeSize,
                min: 0.3,
                max: 0.6,
                onChanged: (value) {
                  context.read<OverlayGaugeConfigurationBloc>().add(ChangeGaugeSize(value));
                },
              ),

              const Divider(),
              _buildSectionTitle('Colors'),
              _buildColorTile(
                context,
                title: 'Gauge Color',
                color: state.gaugeColor,
                onTap: () {
                  final bloc = context.read<OverlayGaugeConfigurationBloc>();
                  bloc.showColorPicker(
                    context,
                    state.gaugeColor,
                        (color) => bloc.add(ChangeGaugeColor(color)),
                  );
                },
              ),
              _buildColorTile(
                context,
                title: 'Needle Color',
                color: state.needleColor,
                onTap: () {
                  final bloc = context.read<OverlayGaugeConfigurationBloc>();
                  bloc.showColorPicker(
                    context,
                    state.needleColor,
                        (color) => bloc.add(ChangeNeedleColor(color)),
                  );
                },
              ),
              _buildColorTile(
                context,
                title: 'Text Color',
                color: state.textColor,
                onTap: () {
                  final bloc = context.read<OverlayGaugeConfigurationBloc>();
                  bloc.showColorPicker(
                    context,
                    state.textColor,
                        (color) => bloc.add(ChangeTextColor(color)),
                  );
                },
              ),
              _buildColorTile(
                context,
                title: 'Border Color',
                color: state.borderColor,
                onTap: () {
                  final bloc = context.read<OverlayGaugeConfigurationBloc>();
                  bloc.showColorPicker(
                    context,
                    state.borderColor,
                        (color) => bloc.add(ChangeBorderColor(color)),
                  );
                },
              ),
              _buildColorTile(
                context,
                title: 'Tick Color',
                color: state.tickColor,
                onTap: () {
                  final bloc = context.read<OverlayGaugeConfigurationBloc>();
                  bloc.showColorPicker(
                    context,
                    state.tickColor,
                        (color) => bloc.add(ChangeTickColor(color)),
                  );
                },
              ),

              const Divider(),
              _buildSectionTitle('Line Widths'),
              _buildSliderTile(
                title: 'Gauge Width',
                value: state.gaugeWidth,
                min: 2,
                max: 15,
                onChanged: (value) {
                  context.read<OverlayGaugeConfigurationBloc>().add(ChangeGaugeWidth(value));
                },
              ),
              _buildSliderTile(
                title: 'Needle Width',
                value: state.needleWidth,
                min: 1,
                max: 5,
                onChanged: (value) {
                  context.read<OverlayGaugeConfigurationBloc>().add(ChangeNeedleWidth(value));
                },
              ),
              _buildSliderTile(
                title: 'Border Width',
                value: state.borderWidth,
                min: 0,
                max: 5,
                onChanged: (value) {
                  context.read<OverlayGaugeConfigurationBloc>().add(ChangeBorderWidth(value));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlacementPicker(BuildContext context, GaugePlacement currentPlacement) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Placement'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              children: GaugePlacement.values.map((placement) {
                return InkWell(
                  onTap: () {
                    context.read<OverlayGaugeConfigurationBloc>().add(ChangeGaugePlacement(placement));
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: placement == currentPlacement
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: placement == currentPlacement
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        placement.displayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: placement == currentPlacement
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: placement == currentPlacement
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

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

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(icon),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildColorTile(
      BuildContext context, {
        required String title,
        required Color color,
        required VoidCallback onTap,
      }) {
    return ListTile(
      title: Text(title),
      leading: const Icon(Icons.color_lens),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Text(title),
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
                // divisions: 5,
                // divisions: (max - min).toInt() * 2,
                label: value.toStringAsFixed(1),
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
}