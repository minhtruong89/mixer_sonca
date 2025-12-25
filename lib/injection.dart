import 'package:get_it/get_it.dart';
import 'package:mixer_sonca/features/counter/counter_logic.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/core/services/config_service.dart';


final getIt = GetIt.instance;

void setupInjection() {
  // Services
  getIt.registerLazySingleton<ConfigService>(
    () => ConfigService(),
  );

  // Repositories
  getIt.registerLazySingleton<CounterRepository>(
    () => CounterRepositoryImpl(),
  );
  getIt.registerLazySingleton<BleRepository>(
    () => BleRepositoryImpl(),
  );

  // ViewModels - Factory because they are disposable and tied to UI lifecycle
  getIt.registerFactory<CounterViewModel>(
    () => CounterViewModel(repository: getIt()),
  );
  getIt.registerFactory<BleViewModel>(
    () => BleViewModel(repository: getIt()),
  );
}
