import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/labs/presentation/bloc/gauge_customization_bloc.dart';
import '../../features/labs/models/gauge_customization.dart';
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
              // ─── Size Factor ───
              _buildSectionTitle('Gauge Size'),
              _buildSliderTile(
                title: 'Size Factor',
                value: sizeFactor.toDouble(),
                min: 1.0,
                max: 3,
                divisions: 10,
                label: sizeFactor.toStringAsFixed(1),
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
              _buildOptionTile(
                icon: Icons.branding_watermark,
                title: 'Hide Watermark',
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
              ),

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

  // ─── Text Color Picker ───

  void _showTextColorPicker(BuildContext context, Color currentColor) {
    // Preset color palette
    const presetColors = <Color>[
      Colors.white,
      Color(0xFFE0E0E0), // Light grey
      Color(0xFF9E9E9E), // Grey
      Colors.black,
      Color(0xFFFF1744), // Red
      Color(0xFFFF9100), // Orange
      Color(0xFFFFEA00), // Yellow
      Color(0xFF00E676), // Green
      Color(0xFF00B0FF), // Blue
      Color(0xFFD500F9), // Purple
      Color(0xFFFF4081), // Pink
      Color(0xFF00BFA5), // Teal
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return _TextColorPickerSheet(
          currentColor: currentColor,
          presetColors: presetColors,
          onColorSelected: (color) {
            context.read<GaugeCustomizationBloc>().add(ChangeTextColor(color));
            Navigator.pop(sheetContext);
          },
        );
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

// ─── Text Color Picker Sheet (Stateful for RGB input) ───

class _TextColorPickerSheet extends StatefulWidget {
  final Color currentColor;
  final List<Color> presetColors;
  final ValueChanged<Color> onColorSelected;

  const _TextColorPickerSheet({
    required this.currentColor,
    required this.presetColors,
    required this.onColorSelected,
  });

  @override
  State<_TextColorPickerSheet> createState() => _TextColorPickerSheetState();
}

class _TextColorPickerSheetState extends State<_TextColorPickerSheet> {
  late TextEditingController _hexController;
  late Color _previewColor;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _previewColor = widget.currentColor;
    _hexController = TextEditingController(
      text: _colorToHex(widget.currentColor),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color c) {
    return '${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}';
  }

  Color? _hexToColor(String hex) {
    hex = hex.replaceAll('#', '').trim();
    if (hex.length == 6) {
      final intVal = int.tryParse(hex, radix: 16);
      if (intVal != null) {
        return Color(0xFF000000 | intVal);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Text Color',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Preset colors grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: widget.presetColors.length,
            itemBuilder: (context, index) {
              final color = widget.presetColors[index];
              final isSelected = color.value == _previewColor.value;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _previewColor = color;
                    _hexController.text = _colorToHex(color);
                    _errorText = null;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blueAccent : Colors.grey[600]!,
                      width: isSelected ? 3 : 1.5,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: Colors.blueAccent.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                            : null,
                  ),
                  child:
                      isSelected
                          ? Icon(
                            Icons.check,
                            color:
                                color.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                            size: 20,
                          )
                          : null,
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),

          // Hex input
          const Text(
            'Custom Hex Color',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Preview swatch
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _previewColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[600]!, width: 1.5),
                ),
              ),
              const SizedBox(width: 12),
              // Text field
              Expanded(
                child: TextField(
                  controller: _hexController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    prefixText: '#',
                    prefixStyle: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'monospace',
                      fontSize: 16,
                    ),
                    hintText: 'FFFFFF',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    errorText: _errorText,
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blueAccent,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  maxLength: 6,
                  onChanged: (text) {
                    final color = _hexToColor(text);
                    if (color != null) {
                      setState(() {
                        _previewColor = color;
                        _errorText = null;
                      });
                    } else if (text.length == 6) {
                      setState(() {
                        _errorText = 'Invalid hex color';
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onColorSelected(_previewColor),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Color',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}