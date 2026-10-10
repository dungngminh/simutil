import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../stream/streams_cubit.dart';
import '../../stream/streams_state.dart';
import '../shared/responsive.dart';
import 'macos_stream_tile.dart';

/// Every open stream in a responsive grid.
class MacosStreamGrid extends StatelessWidget {
  const MacosStreamGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<StreamsCubit, StreamsState>(
      builder: (context, state) {
        if (state.entries.isEmpty) {
          return Center(
            child: Text(
              'Stream a running device to show it here',
              style: MacosTheme.of(context).typography.title3,
            ),
          );
        }
        return ResponsiveTileWrap(
          count: state.entries.length,
          chromeHeight: 40,
          builder: (context, i, width, maxVideoHeight) {
            final entry = state.entries[i];
            return MacosStreamTile(
              key: ValueKey(entry.device.id),
              entry: entry,
              maxVideoHeight: maxVideoHeight,
            );
          },
        );
      },
    );
  }
}
