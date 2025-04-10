import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Enum for gauge placement options
enum GaugePlacement {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

// Extension to get descriptive names for the enum values
extension GaugePlacementExtension on GaugePlacement {
  String get displayName {
    switch (this) {
      case GaugePlacement.topLeft: return 'Top Left';
      case GaugePlacement.topCenter: return 'Top Center';
      case GaugePlacement.topRight: return 'Top Right';
      case GaugePlacement.centerLeft: return 'Center Left';
      case GaugePlacement.center: return 'Center';
      case GaugePlacement.centerRight: return 'Center Right';
      case GaugePlacement.bottomLeft: return 'Bottom Left';
      case GaugePlacement.bottomCenter: return 'Bottom Center';
      case GaugePlacement.bottomRight: return 'Bottom Right';
    }
  }
}

// Events
abstract class OverlayGaugeConfigurationEvent extends Equatable {
  const OverlayGaugeConfigurationEvent();

  @override
  List<Object?> get props => [];
}

class ToggleGaugeVisibility extends OverlayGaugeConfigurationEvent {}

class ToggleTextVisibility extends OverlayGaugeConfigurationEvent {}

class ChangeGaugePlacement extends OverlayGaugeConfigurationEvent {
  final GaugePlacement placement;

  const ChangeGaugePlacement(this.placement);

  @override
  List<Object?> get props => [placement];
}

class ChangeGaugeSize extends OverlayGaugeConfigurationEvent {
  final double size;

  const ChangeGaugeSize(this.size);

  @override
  List<Object?> get props => [size];
}

class ChangeBorderColor extends OverlayGaugeConfigurationEvent {
  final Color color;

  const ChangeBorderColor(this.color);

  @override
  List<Object?> get props => [color];
}

class ChangeGaugeColor extends OverlayGaugeConfigurationEvent {
  final Color color;

  const ChangeGaugeColor(this.color);

  @override
  List<Object?> get props => [color];
}

class ChangeNeedleColor extends OverlayGaugeConfigurationEvent {
  final Color color;

  const ChangeNeedleColor(this.color);

  @override
  List<Object?> get props => [color];
}

class ChangeTextColor extends OverlayGaugeConfigurationEvent {
  final Color color;

  const ChangeTextColor(this.color);

  @override
  List<Object?> get props => [color];
}

class ChangeTickColor extends OverlayGaugeConfigurationEvent {
  final Color color;

  const ChangeTickColor(this.color);

  @override
  List<Object?> get props => [color];
}

class ChangeBorderWidth extends OverlayGaugeConfigurationEvent {
  final double width;

  const ChangeBorderWidth(this.width);

  @override
  List<Object?> get props => [width];
}

class ChangeGaugeWidth extends OverlayGaugeConfigurationEvent {
  final double width;

  const ChangeGaugeWidth(this.width);

  @override
  List<Object?> get props => [width];
}

class ChangeNeedleWidth extends OverlayGaugeConfigurationEvent {
  final double width;

  const ChangeNeedleWidth(this.width);

  @override
  List<Object?> get props => [width];
}

class ResetToDefaults extends OverlayGaugeConfigurationEvent {}

// State
class OverlayGaugeConfigurationState extends Equatable {
  final bool showGauge;
  final bool showText;
  final GaugePlacement gaugePlacement;
  final double gaugeRelativeSize;
  final Color borderColor;
  final Color gaugeColor;
  final Color needleColor;
  final Color textColor;
  final Color tickColor;
  final double borderWidth;
  final double gaugeWidth;
  final double needleWidth;

  const OverlayGaugeConfigurationState({
    required this.showGauge,
    required this.showText,
    required this.gaugePlacement,
    required this.gaugeRelativeSize,
    required this.borderColor,
    required this.gaugeColor,
    required this.needleColor,
    required this.textColor,
    required this.tickColor,
    required this.borderWidth,
    required this.gaugeWidth,
    required this.needleWidth,
  });

  // Default state
  factory OverlayGaugeConfigurationState.initial() {
    return OverlayGaugeConfigurationState(
      showGauge: true,
      showText: true,
      gaugePlacement: GaugePlacement.topRight,
      gaugeRelativeSize: 0.4,
      borderColor: Colors.pink,
      gaugeColor: Colors.blue,
      needleColor: Colors.red,
      textColor: Colors.blue,
      tickColor: Colors.yellow,
      borderWidth: 1.0,
      gaugeWidth: 8.0,
      needleWidth: 2.5,
    );
  }

  OverlayGaugeConfigurationState copyWith({
    bool? showGauge,
    bool? showText,
    GaugePlacement? gaugePlacement,
    double? gaugeRelativeSize,
    Color? borderColor,
    Color? gaugeColor,
    Color? needleColor,
    Color? textColor,
    Color? tickColor,
    double? borderWidth,
    double? gaugeWidth,
    double? needleWidth,
  }) {
    return OverlayGaugeConfigurationState(
      showGauge: showGauge ?? this.showGauge,
      showText: showText ?? this.showText,
      gaugePlacement: gaugePlacement ?? this.gaugePlacement,
      gaugeRelativeSize: gaugeRelativeSize ?? this.gaugeRelativeSize,
      borderColor: borderColor ?? this.borderColor,
      gaugeColor: gaugeColor ?? this.gaugeColor,
      needleColor: needleColor ?? this.needleColor,
      textColor: textColor ?? this.textColor,
      tickColor: tickColor ?? this.tickColor,
      borderWidth: borderWidth ?? this.borderWidth,
      gaugeWidth: gaugeWidth ?? this.gaugeWidth,
      needleWidth: needleWidth ?? this.needleWidth,
    );
  }

  @override
  List<Object?> get props => [
    showGauge,
    showText,
    gaugePlacement,
    gaugeRelativeSize,
    borderColor,
    gaugeColor,
    needleColor,
    textColor,
    tickColor,
    borderWidth,
    gaugeWidth,
    needleWidth,
  ];
}

// BLoC
class OverlayGaugeConfigurationBloc extends Bloc<OverlayGaugeConfigurationEvent, OverlayGaugeConfigurationState> {
  OverlayGaugeConfigurationBloc() : super(OverlayGaugeConfigurationState.initial()) {
    on<ToggleGaugeVisibility>(_onToggleGaugeVisibility);
    on<ToggleTextVisibility>(_onToggleTextVisibility);
    on<ChangeGaugePlacement>(_onChangeGaugePlacement);
    on<ChangeGaugeSize>(_onChangeGaugeSize);
    on<ChangeBorderColor>(_onChangeBorderColor);
    on<ChangeGaugeColor>(_onChangeGaugeColor);
    on<ChangeNeedleColor>(_onChangeNeedleColor);
    on<ChangeTextColor>(_onChangeTextColor);
    on<ChangeTickColor>(_onChangeTickColor);
    on<ChangeBorderWidth>(_onChangeBorderWidth);
    on<ChangeGaugeWidth>(_onChangeGaugeWidth);
    on<ChangeNeedleWidth>(_onChangeNeedleWidth);
    on<ResetToDefaults>(_onResetToDefaults);
  }

  void _onToggleGaugeVisibility(ToggleGaugeVisibility event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(showGauge: !state.showGauge));
  }

  void _onToggleTextVisibility(ToggleTextVisibility event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(showText: !state.showText));
  }

  void _onChangeGaugePlacement(ChangeGaugePlacement event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(gaugePlacement: event.placement));
  }

  void _onChangeGaugeSize(ChangeGaugeSize event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(gaugeRelativeSize: event.size));
  }

  void _onChangeBorderColor(ChangeBorderColor event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(borderColor: event.color));
  }

  void _onChangeGaugeColor(ChangeGaugeColor event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(gaugeColor: event.color));
  }

  void _onChangeNeedleColor(ChangeNeedleColor event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(needleColor: event.color));
  }

  void _onChangeTextColor(ChangeTextColor event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(textColor: event.color));
  }

  void _onChangeTickColor(ChangeTickColor event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(tickColor: event.color));
  }

  void _onChangeBorderWidth(ChangeBorderWidth event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(borderWidth: event.width));
  }

  void _onChangeGaugeWidth(ChangeGaugeWidth event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(gaugeWidth: event.width));
  }

  void _onChangeNeedleWidth(ChangeNeedleWidth event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(state.copyWith(needleWidth: event.width));
  }

  void _onResetToDefaults(ResetToDefaults event, Emitter<OverlayGaugeConfigurationState> emit) {
    emit(OverlayGaugeConfigurationState.initial());
  }

  // Helper method to show color picker
  void showColorPicker(BuildContext context, Color initialColor, Function(Color) onColorSelected) {
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
          content: SizedBox(
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
                        ? Icon(
                      Icons.check,
                      color: colors[index].computeLuminance() > 0.5 ? Colors.black : Colors.white,
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