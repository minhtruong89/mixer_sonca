import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.body,
    required this.title,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title.isEmpty ? null : AppBar(
        title: Text(title),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
