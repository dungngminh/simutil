import 'dart:async';

import 'package:flutter/material.dart';

import '../../di.dart';
import '../../recording/saved_recordings.dart';
import 'material_home_page.dart';

/// Windows and Linux: Material 3.
class MaterialSimutilApp extends StatefulWidget {
  const MaterialSimutilApp({super.key});

  @override
  State<MaterialSimutilApp> createState() => _MaterialSimutilAppState();
}

class _MaterialSimutilAppState extends State<MaterialSimutilApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<String> _saved;

  @override
  void initState() {
    super.initState();
    _saved = getIt<SavedRecordings>().saved.listen(_showSaved);
  }

  void _showSaved(String path) {
    final recordings = getIt<SavedRecordings>();
    final name = path.split(RegExp(r'[/\\]')).last;
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
          content: InkWell(
            onTap: () => recordings.open(path),
            child: Text('Recording saved: $name'),
          ),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => recordings.open(path),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _saved.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimUtil',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const MaterialHomePage(),
    );
  }
}
