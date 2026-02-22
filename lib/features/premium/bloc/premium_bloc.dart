import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/purchase_repository.dart';

abstract class PremiumEvent extends Equatable {
  const PremiumEvent();

  @override
  List<Object?> get props => [];
}

class InitializePremium extends PremiumEvent {}

class CheckPremiumStatus extends PremiumEvent {}

class PurchasePremium extends PremiumEvent {}

class RestorePurchases extends PremiumEvent {}


abstract class PremiumState extends Equatable {
  const PremiumState();

  @override
  List<Object?> get props => [];
}

class PremiumInitial extends PremiumState {}

class PremiumLoading extends PremiumState {}

class PremiumActive extends PremiumState {}

class PremiumInactive extends PremiumState {}

class PremiumPurchaseSuccess extends PremiumState {}

class PremiumPurchaseFailure extends PremiumState {
  final String message;

  const PremiumPurchaseFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class PremiumRestoreSuccess extends PremiumState {
  final bool wasRestored;

  const PremiumRestoreSuccess(this.wasRestored);

  @override
  List<Object?> get props => [wasRestored];
}

class PremiumRestoreError extends PremiumState {
  final String? message;

  const PremiumRestoreError(this.message);

  @override
  List<Object?> get props => [message];
}


class PremiumBloc extends Bloc<PremiumEvent, PremiumState> {
  final PurchaseRepository _purchaseRepository;
  late StreamSubscription _premiumStatusSubscription;

  PremiumBloc(this._purchaseRepository) : super(PremiumInitial()) {
    on<InitializePremium>(_onInitialize);
    on<CheckPremiumStatus>(_onCheckPremiumStatus);
    on<PurchasePremium>(_onPurchasePremium);
    on<RestorePurchases>(_onRestorePurchases);

    // Listen to premium status changes
    _premiumStatusSubscription = _purchaseRepository.premiumStatusStream.listen((isPremium) {
      if (isPremium) {
        emit(PremiumActive());
      } else {
        emit(PremiumInactive());
      }
    });
  }

  Future<void> _onInitialize(
      InitializePremium event,
      Emitter<PremiumState> emit,
      ) async {
    emit(PremiumLoading());

    await _purchaseRepository.initialize();
    // The subscription will handle the state update
  }

  Future<void> _onCheckPremiumStatus(
      CheckPremiumStatus event,
      Emitter<PremiumState> emit,
      ) async {
    emit(PremiumLoading());

    final isPremium = _purchaseRepository.isPremium;
    if (isPremium) {
      emit(PremiumActive());
    } else {
      emit(PremiumInactive());
    }
  }

  Future<void> _onPurchasePremium(
      PurchasePremium event,
      Emitter<PremiumState> emit,
      ) async {
    emit(PremiumLoading());

    final success = await _purchaseRepository.purchasePremium();
    if (success) {
      emit(PremiumPurchaseSuccess());
      emit(PremiumActive());
    } else {
      emit(const PremiumPurchaseFailure('Purchase failed'));
      emit(PremiumInactive());
    }
  }

  Future<void> _onRestorePurchases(
      RestorePurchases event,
      Emitter<PremiumState> emit,
      ) async {
    emit(PremiumLoading());

    final restored = await _purchaseRepository.restorePurchases();
    emit(PremiumRestoreSuccess(restored));

    if (restored) {
      emit(PremiumActive());
    } else {
      emit(PremiumInactive());
    }
  }

  @override
  Future<void> close() {
    _premiumStatusSubscription.cancel();
    return super.close();
  }
}


