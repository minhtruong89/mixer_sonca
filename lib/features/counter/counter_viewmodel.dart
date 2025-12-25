import 'package:flutter/foundation.dart';
import 'package:mixer_sonca/features/counter/counter_model.dart';
import 'package:mixer_sonca/features/counter/counter_repository.dart';

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
