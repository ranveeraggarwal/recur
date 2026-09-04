import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';

class RecurApp extends StatelessWidget {
  const RecurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recur',
      debugShowCheckedModeBanner: false,
      theme: buildRecurTheme(),
      home: const HomeScreen(),
    );
  }
}
