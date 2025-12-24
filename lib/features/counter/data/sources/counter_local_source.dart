import 'package:mixer_sonca/features/counter/domain/entities/counter.dart';

abstract class CounterLocalSource {
  Future<Counter> getCounter();
  Future<void> saveCounter(Counter counter);
}

class CounterLocalSourceImpl implements CounterLocalSource {
  // Simulating local storage with an in-memory variable for this demo
  int _count = 0;

  @override
  Future<Counter> getCounter() async {
    return Counter(value: _count);
  }

  @override
  Future<void> saveCounter(Counter counter) async {
    _count = counter.value;
  }
}
