import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/gauge_customization.dart';

/// ─────────────────────────────────────────────
/// EVENTS
/// ─────────────────────────────────────────────

abstract class GaugeCustomizationEvent extends Equatable {
  const GaugeCustomizationEvent();

  @override
  List<Object?> get props => [];
}

/// Replace entire customization
class ChangeGaugeCustomization extends GaugeCustomizationEvent {
  final GaugeCustomization customization;

  const ChangeGaugeCustomization(this.customization);

  @override
  List<Object?> get props => [customization];
}

/// Toggle unit system
class ChangeGaugeUnits extends GaugeCustomizationEvent {
  final bool imperial;

  const ChangeGaugeUnits(this.imperial);

  @override
  List<Object?> get props => [imperial];
}

/// Change placement
class ChangeGaugePlacement extends GaugeCustomizationEvent {
  final GaugePlacement placement;

  const ChangeGaugePlacement(this.placement);

  @override
  List<Object?> get props => [placement];
}

/// Toggle speed visibility
class ToggleShowSpeed extends GaugeCustomizationEvent {
  final bool showSpeed;

  const ToggleShowSpeed(this.showSpeed);

  @override
  List<Object?> get props => [showSpeed];
}

/// Toggle branding visibility
class ToggleShowBranding extends GaugeCustomizationEvent {
  final bool showBranding;

  const ToggleShowBranding(this.showBranding);

  @override
  List<Object?> get props => [showBranding];
}

/// Change dial
class ChangeDial extends GaugeCustomizationEvent {
  final Dial? dial;

  const ChangeDial(this.dial);

  @override
  List<Object?> get props => [dial];
}

/// Change needle
class ChangeNeedle extends GaugeCustomizationEvent {
  final Needle? needle;

  const ChangeNeedle(this.needle);

  @override
  List<Object?> get props => [needle];
}

/// Change size factor
class ChangeGaugeSizeFactor extends GaugeCustomizationEvent {
  final double sizeFactor;

  const ChangeGaugeSizeFactor(this.sizeFactor);

  @override
  List<Object?> get props => [sizeFactor];
}

/// Change aspect ratio
class ChangeGaugeAspectRatio extends GaugeCustomizationEvent {
  final double aspectRatio;

  const ChangeGaugeAspectRatio(this.aspectRatio);

  @override
  List<Object?> get props => [aspectRatio];
}



/// ─────────────────────────────────────────────
/// STATE
/// ─────────────────────────────────────────────

class GaugeCustomizationState extends Equatable {
  final GaugeCustomization customization;

  const GaugeCustomizationState({
    required this.customization,
  });

  GaugeCustomizationState copyWith({
    GaugeCustomization? customization,
  }) {
    return GaugeCustomizationState(
      customization: customization ?? this.customization,
    );
  }

  @override
  List<Object?> get props => [customization];
}



/// ─────────────────────────────────────────────
/// BLOC
/// ─────────────────────────────────────────────

class GaugeCustomizationBloc
    extends Bloc<GaugeCustomizationEvent, GaugeCustomizationState> {

  GaugeCustomizationBloc()
      : super(
    const GaugeCustomizationState(
      customization: GaugeCustomization(),
    ),
  ) {

    on<ChangeGaugeCustomization>((event, emit) {
      emit(state.copyWith(customization: event.customization));
    });

    on<ChangeGaugeUnits>((event, emit) {
      emit(
        state.copyWith(
          customization: state.customization.copyWith(
            imperial: event.imperial,
          ),
        ),
      );
    });

    on<ChangeGaugePlacement>((event, emit) {
      emit(
        state.copyWith(
          customization: state.customization.copyWith(
            placement: event.placement,
          ),
        ),
      );
    });

    on<ToggleShowSpeed>((event, emit) {
      emit(
        state.copyWith(
          customization: state.customization.copyWith(
            showSpeed: event.showSpeed,
          ),
        ),
      );
    });

    on<ToggleShowBranding>((event, emit) {
      emit(
        state.copyWith(
          customization: state.customization.copyWith(
            showBranding: event.showBranding,
          ),
        ),
      );
    });

    on<ChangeDial>((event, emit) {
      emit(
        state.copyWith(
          customization: state.customization.copyWith(
            dial: event.dial,
          ),
        ),
      );
    });

    on<ChangeNeedle>((event, emit) {
      emit(
        state.copyWith(
          customization: state.customization.copyWith(
            needle: event.needle,
          ),
        ),
      );
    });

    on<ChangeGaugeSizeFactor>((event, emit) {
      emit(
        state.copyWith(
          customization: state.customization.copyWith(
            sizeFactor: event.sizeFactor,
          ),
        ),
      );
    });

    on<ChangeGaugeAspectRatio>((event, emit) {
      emit(
        state.copyWith(
          customization: state.customization.copyWith(
            gaugeAspectRatio: event.aspectRatio,
          ),
        ),
      );
    });
  }
}