import 'package:flutter/material.dart';

/// Preset color palette used across the app for color selection.
const List<Color> kPresetColors = <Color>[
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

/// Shows a reusable color picker bottom sheet.
///
/// [context] — build context
/// [currentColor] — the currently selected color
/// [title] — the title shown at the top of the sheet (e.g. 'Select Text Color')
/// [onColorSelected] — callback when the user applies a color
void showColorPickerBottomSheet({
  required BuildContext context,
  required Color currentColor,
  String title = 'Select Color',
  required ValueChanged<Color> onColorSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (sheetContext) {
      return ColorPickerSheet(
        currentColor: currentColor,
        title: title,
        presetColors: kPresetColors,
        onColorSelected: (color) {
          onColorSelected(color);
          Navigator.pop(sheetContext);
        },
      );
    },
  );
}

/// A stateful color picker sheet with preset grid + hex input.
class ColorPickerSheet extends StatefulWidget {
  final Color currentColor;
  final String title;
  final List<Color> presetColors;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerSheet({
    super.key,
    required this.currentColor,
    this.title = 'Select Color',
    required this.presetColors,
    required this.onColorSelected,
  });

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
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
          Text(
            widget.title,
            style: const TextStyle(
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
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: color.computeLuminance() > 0.5
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
