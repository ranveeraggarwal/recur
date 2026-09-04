import 'package:flutter/material.dart';

class RecurApp extends StatelessWidget {
  const RecurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recur',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Recur'),
        ),
        body: const Center(
          child: Text('No events yet.'),
        ),
      ),
    );
  }

  // TODO(#14): replace with the real design tokens.
  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4EFE6),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2C4A3B),
        surface: const Color(0xFFFAF7F2),
        onSurface: const Color(0xFF1C1C19),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAF7F2),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
