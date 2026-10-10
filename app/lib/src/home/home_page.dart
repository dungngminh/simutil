import 'package:flutter/material.dart';

import 'device_sidebar.dart';
import 'stream_grid.dart';

/// Main window: device list on the left, streams on the right.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Row(
        children: [
          SizedBox(width: 300, child: DeviceSidebar()),
          VerticalDivider(width: 1),
          Expanded(child: StreamGrid()),
        ],
      ),
    );
  }
}
