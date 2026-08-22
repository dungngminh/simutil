/// Preset extra args for launching an Android emulator.
enum AndroidQuickLaunchOption {
  /// Default emulator launch.
  normal(label: 'Normal', args: []),

  /// Skip snapshot load (`-no-snapshot-load`).
  coldBoot(label: 'Cold Boot', args: ['-no-snapshot-load']),

  /// Disable emulator audio (`-no-audio`).
  noAudio(label: 'No Audio', args: ['-no-audio']),

  /// Cold boot without audio.
  coldBootNoAudio(
    label: 'Cold Boot + No Audio',
    args: ['-no-snapshot-load', '-no-audio'],
  );

  /// Creates an option with a UI [label] and emulator [args].
  const AndroidQuickLaunchOption({required this.label, this.args = const []});

  /// Label shown in the TUI launch dialog.
  final String label;

  /// Extra arguments appended to `emulator @avd`.
  final List<String> args;
}
