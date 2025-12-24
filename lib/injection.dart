import 'package:get_it/get_it.dart';
import 'package:mixer_sonca/features/counter/data/repositories/counter_repository_impl.dart';
import 'package:mixer_sonca/features/counter/data/sources/counter_local_source.dart';
import 'package:mixer_sonca/features/counter/domain/repositories/counter_repository.dart';
import 'package:mixer_sonca/features/counter/domain/usecases/increment_counter.dart';
import 'package:mixer_sonca/features/counter/presentation/viewmodels/counter_viewmodel.dart';


final getIt = GetIt.instance;

void setupInjection() {
  // Sources
  getIt.registerLazySingleton<CounterLocalSource>(
    () => CounterLocalSourceImpl(),
  );

  // Repositories
  getIt.registerLazySingleton<CounterRepository>(
    () => CounterRepositoryImpl(getIt()),
  );

  // UseCases
  getIt.registerLazySingleton<IncrementCounter>(
    () => IncrementCounter(getIt()),
  );

  // ViewModels - Factory because they are disposable and tied to UI lifecycle
  getIt.registerFactory<CounterViewModel>(
    () => CounterViewModel(incrementCounterUseCase: getIt()),
  );
}
