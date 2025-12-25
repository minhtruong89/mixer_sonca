import 'counter_model.dart';

abstract class CounterRepository {
  Future<Counter> getCounter();
  Future<Counter> incrementCounter();
}

class CounterRepositoryImpl implements CounterRepository {
  // Simulating local storage with an in-memory variable
  int _count = 0;

  @override
  Future<Counter> getCounter() async {
    return Counter(value: _count);
  }

  @override
  Future<Counter> incrementCounter() async {
    _count++;
    return Counter(value: _count);
  }
}
