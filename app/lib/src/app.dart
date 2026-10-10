import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import 'devices/devices_cubit.dart';
import 'di.dart';
import 'home/home_page.dart';
import 'stream/streams_cubit.dart';

class SimutilApp extends StatelessWidget {
  const SimutilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocSignalProvider(
      providers: [
        BlocSignalProvider<DevicesCubit>.value(value: getIt<DevicesCubit>()),
        BlocSignalProvider<StreamsCubit>.value(value: getIt<StreamsCubit>()),
      ],
      child: MaterialApp(
        title: 'SimUtil',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
