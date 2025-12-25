import 'package:get_it/get_it.dart';
import 'package:mixer_sonca/features/counter/counter_logic.dart';


final getIt = GetIt.instance;

void setupInjection() {
  // Repositories
  getIt.registerLazySingleton<CounterRepository>(
    () => CounterRepositoryImpl(),
  );

  // ViewModels - Factory because they are disposable and tied to UI lifecycle
  getIt.registerFactory<CounterViewModel>(
    () => CounterViewModel(repository: getIt()),
  );
}
