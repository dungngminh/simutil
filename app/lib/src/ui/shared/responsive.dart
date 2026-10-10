import 'dart:math';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';

import '../../recording/grid_recorder.dart';

/// Below this width the device list leaves the side and becomes a drawer
/// (Material) or starts collapsed (macOS).
const kCompactWidth = 840.0;

/// Lays out stream tiles in as many columns as fit, each at least
/// [minTileWidth] wide; [builder] gets the tile width and the tallest the
/// video may be so a whole phone screen stays visible.
class ResponsiveTileWrap extends StatelessWidget {
  const ResponsiveTileWrap({
    super.key,
    required this.count,
    required this.builder,
    this.minTileWidth = 280,
    this.spacing = 16,
    this.chromeHeight = 56,
  });

  final int count;
  final Widget Function(
    BuildContext context,
    int index,
    double width,
    double maxVideoHeight,
  )
  builder;
  final double minTileWidth;
  final double spacing;

  /// Height of the tile header, subtracted from the video budget.
  final double chromeHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - spacing * 2;
        final columns = max(
          1,
          min(
            count,
            ((available + spacing) / (minTileWidth + spacing)).floor(),
          ),
        );
        final width = (available - spacing * (columns - 1)) / columns;
        final maxVideoHeight = max(
          200.0,
          constraints.maxHeight - spacing * 2 - chromeHeight,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                  width: width,
                  child: builder(context, i, width, maxVideoHeight),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Sizes a video of [aspectRatio] to fit [maxWidth] x [maxHeight].
Size fitVideo(double aspectRatio, double maxWidth, double maxHeight) {
  final width = min(maxWidth, maxHeight * aspectRatio);
  return Size(width, width / aspectRatio);
}

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
