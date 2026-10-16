import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/recording/saved_recordings.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';
import 'package:simutil_app/src/update/app_installer.dart';
import 'package:simutil_app/src/update/app_update_cubit.dart';
import 'package:zentoast/zentoast.dart';

/// Tells the user [update] is out. Update installs it the way the app was
/// installed (Homebrew, DMG, Windows installer, AppImage) and relaunches;
/// other installs get Download, which opens the release page.
void showUpdateToast(BuildContext context, AppUpdate update) {
  const height = 100.0;
  final t = SimuTokens.of(context);
  final channel = getIt<AppInstaller>().channel;
  final inPlace = channel != UpdateChannel.manual;
  final current = getIt<AppUpdateCubit>().currentVersion;
  showSimuToast(
    context,
    height,
    (close) => SimuToast(
      height: height,
      icon: LucideIcons.circleArrowUp,
      tone: t.accent,
      title: 'SimUtil ${update.version} is available',
      subtitle: switch (channel) {
        UpdateChannel.homebrew => 'You have $current · via Homebrew',
        _ => 'You have $current',
      },
      onClose: close,
      actions: [
        SimuButton(
          label: inPlace ? 'Update & restart' : 'Download',
          icon: inPlace ? LucideIcons.refreshCw : LucideIcons.download,
          primary: true,
          onPressed: () {
            close();
            inPlace
                ? _install(context, update)
                : getIt<SavedRecordings>().open(update.url);
          },
        ),
        SimuButton(label: 'Later', onPressed: close),
      ],
    ),
  );
}

Future<void> _install(BuildContext context, AppUpdate update) async {
  final progress = ValueNotifier(const UpdateProgress('Starting…'));
  const height = 72.0;
  final toasts = ToastProvider.of(context);
  final toast = showSimuToast(
    context,
    height,
    (close) => ValueListenableBuilder(
      valueListenable: progress,
      builder: (context, p, _) => SimuToast(
        height: height,
        icon: LucideIcons.circleArrowUp,
        tone: SimuTokens.of(context).accent,
        title: p.fraction == null
            ? 'Updating to ${update.version}'
            : 'Updating to ${update.version} · ${(p.fraction! * 100).round()}%',
        subtitle: p.step,
        progressBar: true,
        progress: p.fraction,
      ),
    ),
  );
  try {
    // Quits the app on success.
    await getIt<AppInstaller>().install(
      update,
      onProgress: (p) => progress.value = p,
    );
  } catch (e) {
    toasts.hide(toast);
    if (!context.mounted) return;
    showNotice(
      context,
      'Update failed',
      subtitle: '$e',
      tone: NoticeTone.error,
    );
    getIt<SavedRecordings>().open(update.url);
  }
}
