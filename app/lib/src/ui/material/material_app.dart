import 'package:flutter/material.dart';

import 'material_home_page.dart';

/// Windows and Linux: Material 3.
class MaterialSimutilApp extends StatelessWidget {
  const MaterialSimutilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimUtil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const MaterialHomePage(),
    );
  }
}
