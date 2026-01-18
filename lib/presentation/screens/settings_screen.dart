import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_event.dart';
import 'package:speedometer/presentation/bloc/settings/settings_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: state.backgroundColor,
          appBar: AppBar(
            title: const Text('Settings'),
            centerTitle: false,
            backgroundColor: state.backgroundColor.withOpacity(0.8),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle('Units', state.speedometerColor),
              _buildSettingTile(
                title: 'Unit System',
                subtitle: state.isMetric ? 'Metric (km/h)' : 'Imperial (mph)',
                icon: Icons.speed,
                onTap: () {
                  context.read<SettingsBloc>().add(ToggleUnitSystem());
                },
                trailing: Switch(
                  value: state.isMetric,
                  onChanged: (_) {
                    context.read<SettingsBloc>().add(ToggleUnitSystem());
                  },
                  activeColor: state.speedometerColor,
                ),
              ),
              const Divider(),
              _buildSectionTitle('Appearance', state.speedometerColor),
              _buildSettingTile(
                title: 'Speedometer Color',
                subtitle: 'Change the color of the speedometer',
                icon: Icons.color_lens,
                onTap: () {
                  _showColorPicker(
                    context,
                    state.speedometerColor,
                    (color) {
                      context.read<SettingsBloc>().add(ChangeSpeedometerColor(color));
                    },
                  );
                },
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: state.speedometerColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              _buildSettingTile(
                title: 'Background Color',
                subtitle: 'Change the background color',
                icon: Icons.format_color_fill,
                onTap: () {
                  _showColorPicker(
                    context,
                    state.backgroundColor,
                    (color) {
                      context.read<SettingsBloc>().add(ChangeBackgroundColor(color));
                    },
                  );
                },
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: state.backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              _buildSettingTile(
                title: 'Dark Mode',
                subtitle: 'Toggle dark mode',
                icon: Icons.dark_mode,
                onTap: () {
                  context.read<SettingsBloc>().add(ToggleDarkMode());
                },
                trailing: Switch(
                  value: state.isDarkMode,
                  onChanged: (_) {
                    context.read<SettingsBloc>().add(ToggleDarkMode());
                  },
                  activeColor: state.speedometerColor,
                ),
              ),
              const Divider(),
              _buildSectionTitle('About', state.speedometerColor),
              _buildSettingTile(
                title: 'Version',
                subtitle: '1.0.0',
                icon: Icons.info_outline,
                onTap: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _showColorPicker(
    BuildContext context,
    Color initialColor,
    Function(Color) onColorSelected,
  ) {
    final List<Color> colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
      Colors.black,
      Colors.white,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Color'),
          content: Container(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    onColorSelected(colors[index]);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: colors[index] == initialColor
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}