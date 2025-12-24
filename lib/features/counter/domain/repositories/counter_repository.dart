import 'package:mixer_sonca/features/counter/domain/entities/counter.dart';

abstract class CounterRepository {
  Future<Counter> getCounter();
  Future<Counter> incrementCounter();
}
