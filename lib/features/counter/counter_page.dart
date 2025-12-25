import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/core/widgets/app_scaffold.dart';
import 'package:mixer_sonca/features/counter/counter_logic.dart';
import 'package:mixer_sonca/features/counter/widgets/counter_button.dart';

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CounterViewModel>();
    
    return AppScaffold(
      title: 'Simplified Architecture Counter',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '${viewModel.counter.value}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: CounterButton(
        onPressed: () => context.read<CounterViewModel>().increment(),
      ),
    );
  }
}
