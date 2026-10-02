import 'dart:async';

import 'package:nocterm/nocterm.dart';

/// Animated spinner with optional status text.
class LoadingState extends StatefulComponent {
  /// Creates a loading indicator.
  const LoadingState({
    this.spinnerFrames = defaultSpinnerFrames,
    this.message,
    this.duration = defaultDuration,
    this.style = const TextStyle(fontWeight: FontWeight.dim),
  });

  /// Braille frames cycled by the spinner animation.
  final List<String> spinnerFrames;

  /// Optional message shown beside the spinner.
  final String? message;

  /// Delay between spinner frame updates.
  final Duration duration;

  /// Text style for the spinner line.
  final TextStyle style;

  /// Default frame interval for [LoadingState].
  static const defaultDuration = Duration(milliseconds: 150);

  /// Default braille spinner frames.
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
