

import '../../../di/injection_container.dart';
import '../bloc/premium_bloc.dart';
import '../repository/purchase_repository.dart';
import '../service/purchase_service.dart';

Future<void> initPremiumFeature() async {
  // Services
  getIt.registerSingleton<PurchaseService>(PurchaseService());

  // Repositories
  getIt.registerSingleton<PurchaseRepository>(PurchaseRepository(getIt()));

  // BLoCs
  getIt.registerFactory<PremiumBloc>(() => PremiumBloc(getIt()));
}