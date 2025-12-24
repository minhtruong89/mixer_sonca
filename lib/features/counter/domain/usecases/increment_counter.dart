import 'package:mixer_sonca/features/counter/domain/entities/counter.dart';
import 'package:mixer_sonca/features/counter/domain/repositories/counter_repository.dart';

class IncrementCounter {
  final CounterRepository _repository;

  const IncrementCounter(this._repository);

  Future<Counter> call() {
    return _repository.incrementCounter();
  }
}
