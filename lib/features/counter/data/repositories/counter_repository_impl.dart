import 'package:mixer_sonca/features/counter/data/sources/counter_local_source.dart';
import 'package:mixer_sonca/features/counter/domain/entities/counter.dart';
import 'package:mixer_sonca/features/counter/domain/repositories/counter_repository.dart';

class CounterRepositoryImpl implements CounterRepository {
  final CounterLocalSource _localSource;

  const CounterRepositoryImpl(this._localSource);

  @override
  Future<Counter> getCounter() async {
    return _localSource.getCounter();
  }

  @override
  Future<Counter> incrementCounter() async {
    final current = await _localSource.getCounter();
    final newCounter = Counter(value: current.value + 1);
    await _localSource.saveCounter(newCounter);
    return newCounter;
  }
}
