import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../../stream/streams_cubit.dart';
import '../../stream/streams_state.dart';
import '../shared/responsive.dart';
import 'material_stream_tile.dart';

/// Every open stream in a responsive grid.
class MaterialStreamGrid extends StatelessWidget {
  const MaterialStreamGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return RecordableArea(
      child: BlocSignalBuilder<StreamsCubit, StreamsState>(
        builder: (context, state) {
          if (state.entries.isEmpty) {
            return const Center(
              child: Text('Stream a running device to show it here'),
            );
          }
          return ResponsiveTileWrap(
            count: state.entries.length,
            builder: (context, i, width, maxVideoHeight) {
              final entry = state.entries[i];
              return MaterialStreamTile(
                key: ValueKey(entry.device.id),
                entry: entry,
                maxVideoHeight: maxVideoHeight,
              );
            },
          );
        },
      ),
    );
  }
}
