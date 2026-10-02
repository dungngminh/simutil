import 'package:simutil/simutil.dart';

Future<void> main(List<String> arguments) =>
    arguments.isEmpty ? runSimutilTui() : runSimutilCli(arguments);
