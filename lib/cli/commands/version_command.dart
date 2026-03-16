import 'package:simutil/cli/commands/simutil_command.dart';
import 'package:simutil/utils/version.dart';

class VersionCommand extends SimutilCommand {
  VersionCommand({super.logger});

  @override
  String get name => 'version';

  @override
  String get description => 'Print the current version';

  @override
  Future<int> run() async {
    logger.success('Simutil v$packageVersion');
    return 0;
  }
}
