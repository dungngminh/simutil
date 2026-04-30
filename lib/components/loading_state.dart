import 'dart:async';

import 'package:nocterm/nocterm.dart';

class LoadingState extends StatefulComponent {
  const LoadingState({
    this.spinnerFrames = defaultSpinnerFrames,
    this.message,
    this.duration = defaultDuration,
    this.style = const TextStyle(fontWeight: FontWeight.dim),
  });

  final List<String> spinnerFrames;
  final String? message;
  final Duration duration;
  final TextStyle style;

  static const defaultDuration = Duration(milliseconds: 150);

  static const defaultSpinnerFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  @override
  State<LoadingState> createState() => _LoadingState();
}

class _LoadingState extends State<LoadingState> {
  Timer? _spinnerTimer;
  int _spinnerIndex = 0;

  @override
  void initState() {
    super.initState();
    _spinnerTimer = Timer.periodic(component.duration, (_) {
      setState(() {
        _spinnerIndex = (_spinnerIndex + 1) % component.spinnerFrames.length;
      });
    });
  }

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final message = component.message;
    final spinner = component.spinnerFrames[_spinnerIndex];
    final text = message != null ? '$spinner $message' : spinner;
    return Text(text, style: component.style);
  }
}
