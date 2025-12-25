import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

// --- Model ---
class Counter extends Equatable {
  final int value;

  const Counter({required this.value});

  @override
  List<Object?> get props => [value];
}

// --- Repository ---
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

// --- ViewModel ---
class CounterViewModel extends ChangeNotifier {
  final CounterRepository _repository;

  CounterViewModel({required CounterRepository repository})
      : _repository = repository;

  Counter _counter = const Counter(value: 0);
  Counter get counter => _counter;

  Future<void> increment() async {
    _counter = await _repository.incrementCounter();
    notifyListeners();
  }
}
