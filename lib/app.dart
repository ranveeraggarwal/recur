import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class RecurApp extends StatelessWidget {
  const RecurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recur',
      debugShowCheckedModeBanner: false,
      theme: buildRecurTheme(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Recur')),
        body: const Center(child: Text('No events yet.')),
      ),
    );
  }
}
