import 'package:flutter/foundation.dart';
import 'package:mixer_sonca/features/counter/domain/entities/counter.dart';
import 'package:mixer_sonca/features/counter/domain/usecases/increment_counter.dart';

class CounterViewModel extends ChangeNotifier {
  final IncrementCounter _incrementCounterUseCase;

  CounterViewModel({required IncrementCounter incrementCounterUseCase})
      : _incrementCounterUseCase = incrementCounterUseCase;

  Counter _counter = const Counter(value: 0);
  Counter get counter => _counter;

  Future<void> increment() async {
    _counter = await _incrementCounterUseCase();
    notifyListeners();
  }
}
