import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/labs/data/gauge_options.dart';
import 'package:speedometer/features/labs/models/gauge_customization.dart';
import 'package:speedometer/features/labs/presentation/bloc/gauge_customization_bloc.dart';
import 'package:speedometer/presentation/widgets/color_picker_bottom_sheet.dart';
import 'package:speedometer/services/remote_asset_service.dart';

/// A reusable widget that shows the gauge (dial) and needle selection UI.
///
/// It reads and writes to the [GaugeCustomizationBloc] so it can be embedded
/// in any screen that has access to the bloc (camera settings, task processing,
/// etc.) — following DRY principles.
class GaugeNeedleSelectorWidget extends StatefulWidget {
  const GaugeNeedleSelectorWidget({super.key});

  @override
  State<GaugeNeedleSelectorWidget> createState() =>
      _GaugeNeedleSelectorWidgetState();
}

class _GaugeNeedleSelectorWidgetState extends State<GaugeNeedleSelectorWidget> {
  late GaugeCustomizationOption _selectedOption;
  Needle? _selectedNeedle;

  @override
  void initState() {
    super.initState();
    final state = context.read<GaugeCustomizationBloc>().state;
    final currentDial = state.customization.dial;
    _selectedOption = kGaugeOptions.firstWhere(
      (o) => o.dial?.id == currentDial?.id,
      orElse: () => kGaugeOptions.first,
    );
    _selectedNeedle = state.customization.needle;
  }

  void _openGaugeAndNeedleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bloc = context.read<GaugeCustomizationBloc>();
            final config = bloc.state.customization;
            final hasNeedles = _selectedOption.hasNeedles;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─ Section: Gauge ─
                  const Text(
                    'Select Gauge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: kGaugeOptions.length,
                    itemBuilder: (context, index) {
                      final option = kGaugeOptions[index];
                      final isSelected = option.id == _selectedOption.id;
                      return _GaugeTile(
                        option: option,
                        isSelected: isSelected,
                        onTap: () {
                          setSheetState(() {
                            _selectedOption = option;
                            _selectedNeedle = option.hasNeedles
                                ? option.needles!.first
                                : null;
                          });
                          setState(() {});
                          bloc.add(ChangeDial(option.dial));
                          if (_selectedNeedle != null) {
                            bloc.add(ChangeNeedle(_selectedNeedle));
                          }
                        },
                      );
                    },
                  ),

                  // ─ Dial Color (if colorEditable) ─
                  if (_selectedOption.dial?.colorEditable == true) ...[
                    const SizedBox(height: 12),
                    _ColorEditRow(
                      label: 'Dial Color',
                      color: config.dialColor ?? Colors.black,
                      onTap: () {
                        showColorPickerBottomSheet(
                          context: context,
                          currentColor: config.dialColor ?? Colors.black,
                          title: 'Select Dial Color',
                          onColorSelected: (color) {
                            bloc.add(ChangeDialColor(color));
                            setSheetState(() {});
                          },
                        );
                      },
                    ),
                  ],

                  // ─ Section: Needle (only if gauge has needles) ─
                  if (hasNeedles) ...[
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 12),
                    const Text(
                      'Select Needle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedOption.needles!.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final needle = _selectedOption.needles![index];
                          final isNeedleSelected =
                              needle.id == _selectedNeedle?.id;
                          return _NeedleTile(
                            needle: needle,
                            isSelected: isNeedleSelected,
                            onTap: () {
                              setSheetState(() {
                                _selectedNeedle = needle;
                              });
                              setState(() {});
                              bloc.add(ChangeNeedle(needle));
                            },
                          );
                        },
                      ),
                    ),

                    // ─ Needle Color (if colorEditable) ─
                    if (_selectedNeedle?.colorEditable == true) ...[
                      const SizedBox(height: 12),
                      _ColorEditRow(
                        label: 'Needle Color',
                        color: config.needleColor ?? Colors.black,
                        onTap: () {
                          showColorPickerBottomSheet(
                            context: context,
                            currentColor: config.needleColor ?? Colors.black,
                            title: 'Select Needle Color',
                            onColorSelected: (color) {
                              bloc.add(ChangeNeedleColor(color));
                              setSheetState(() {});
                            },
                          );
                        },
                      ),
                    ],
                  ],

                  const SizedBox(height: 20),

                  // ─ Done Button ─
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GaugeCustomizationBloc, GaugeCustomizationState>(
      builder: (context, state) {
        final config = state.customization;
        return Material(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openGaugeAndNeedleSheet,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.speed,
                        color: Colors.blueAccent, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedOption.name ?? 'Select Gauge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedNeedle != null
                              ? 'Needle: ${_selectedNeedle!.name ?? _selectedNeedle!.color ?? _selectedNeedle!.id ?? "default"}'
                              : 'No needle',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (config.dial?.assetType == AssetType.network)
                    _CachedNetworkImage(
                      url: config.dial?.path ?? "",
                      width: 30,
                      height: 30,
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: Colors.white54, size: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Color Edit Row ───

class _ColorEditRow extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ColorEditRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[600]!, width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.edit, size: 14, color: Colors.blueAccent),
            label: const Text(
              'Change',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gauge Tile Widget ───

class _GaugeTile extends StatelessWidget {
  final GaugeCustomizationOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _GaugeTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dialPath = option.dial?.path;
    final isNetwork = option.dial?.assetType == AssetType.network;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : Colors.grey[850],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (dialPath != null && isNetwork)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _CachedNetworkImage(
                  url: dialPath,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              )
            else
              const Icon(Icons.speed, color: Colors.white54, size: 40),
            const SizedBox(height: 6),
            Text(
              option.name ?? '',
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle,
                    color: Colors.blueAccent, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Needle Tile Widget ───

class _NeedleTile extends StatelessWidget {
  final Needle needle;
  final bool isSelected;
  final VoidCallback onTap;

  const _NeedleTile({
    required this.needle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNetwork = needle.assetType == AssetType.network;
    final path = needle.path;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : Colors.grey[850],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (path != null && isNetwork)
              _CachedNetworkImage(
                url: path,
                width: 35,
                height: 35,
                fit: BoxFit.contain,
              )
            else
              Icon(Icons.navigation,
                  color: isSelected ? Colors.blueAccent : Colors.white54,
                  size: 30),
            const SizedBox(height: 4),
            Text(
              needle.name ?? needle.color ?? needle.id ?? '',
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white70,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cached Network Image ───

class _CachedNetworkImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;

  const _CachedNetworkImage({
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: RemoteAssetService().getBytes(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
          );
        }
        return SizedBox(width: width, height: height);
      },
    );
  }
}
