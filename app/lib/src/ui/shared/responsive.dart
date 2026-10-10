import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/recording/grid_recorder.dart';

/// Below this width the device sidebar starts hidden.
const kCompactWidth = 840.0;

/// The area grid recording captures; wraps the whole grid, empty or not.
class RecordableArea extends StatelessWidget {
  const RecordableArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: context.read<GridRecorderCubit>().boundaryKey,
    child: child,
  );
}
