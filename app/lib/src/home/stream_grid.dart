import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../stream/streams_cubit.dart';
import '../stream/streams_state.dart';
import 'stream_tile.dart';

/// Every open stream side by side; wraps to new rows as needed.
class StreamGrid extends StatelessWidget {
  const StreamGrid({super.key});

  static const _tileWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<StreamsCubit, StreamsState>(
      builder: (context, state) {
        if (state.entries.isEmpty) {
          return const Center(
            child: Text('Press ▶︎ Stream on a running device to show it here'),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final entry in state.entries)
                SizedBox(
                  width: _tileWidth,
                  child: StreamTile(
                    key: ValueKey(entry.device.id),
                    entry: entry,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
